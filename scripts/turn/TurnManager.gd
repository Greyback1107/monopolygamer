class_name TurnManager
extends Node

# ─────────────────────────────────────────
# ESTADOS
# ─────────────────────────────────────────
enum TurnState {
    WAITING_FOR_TURN_START,
    ROLLING_DICE,
    CHOOSING_DICE_ORDER,
    RESOLVING_POWERUP,
    MOVING_PLAYER,
    RESOLVING_SQUARE,
    WAITING_FOR_INTERACTION,
    CHECKING_GRAND_PRIX,
    TURN_ENDED
}

# ─────────────────────────────────────────
# ESTADO INTERNO
# ─────────────────────────────────────────
var current_state: TurnState = TurnState.WAITING_FOR_TURN_START
var current_player_index: int = 0
var player_order: Array = []          # [player_id, player_id, ...]

# Datos del turno activo
var _numeric_result: int = 0
var _powerup_face: Dictionary = {}
var _resolve_order: int = 0           # 0 = move first, 1 = power first
var _grand_prix_pending: bool = false
var _skip_powerup: bool = false       # para Metal Mario

# Referencias a sistemas (asignadas en _ready via @onready o parámetro)
@onready var dice_system = $"../DiceSystem"
@onready var board_manager = $"../BoardManager"
@onready var character_system  = $"../CharacterSystem"
@onready var grand_prix_system  = $"../GrandPrixSystem"

func _ready() -> void:
    _connect_signals()

# ─────────────────────────────────────────
# CONEXIÓN DE SEÑALES
# ─────────────────────────────────────────
func _connect_signals() -> void:
    print("dice_system: ", dice_system)
    print("character_system: ", character_system)
    print("grand_prix_system: ", grand_prix_system)
    # Dados
    dice_system.turn_dice_completed.connect(_on_dice_completed)
    dice_system.waiting_for_order_choice.connect(
        func(): _set_state(TurnState.CHOOSING_DICE_ORDER)
    )

    # Tablero
    GameEvents.player_move_completed.connect(_on_move_completed)
    GameEvents.square_effect_completed.connect(_on_square_effect_completed)
    GameEvents.passed_go.connect(_on_passed_go)

    # Interacciones
    GameEvents.interaction_completed.connect(_on_interaction_completed)

    # Carreras
    grand_prix_system.race_completed.connect(_on_race_completed)
    GameEvents.race_ui_closed.connect(_on_race_ui_closed)

    # Power-up
    GameEvents.powerup_effect_completed.connect(_on_powerup_completed)

    # HUD — el jugador presiona el botón de tirar
    GameEvents.roll_button_pressed.connect(_on_roll_button_pressed)

    # Orden de dados elegido por el jugador
    GameEvents.dice_order_chosen.connect(_on_dice_order_chosen)

# ─────────────────────────────────────────
# INICIO DE PARTIDA
# ─────────────────────────────────────────
func start_game(players: Array) -> void:
    player_order = players
    current_player_index = 0
    _begin_turn()

func _begin_turn() -> void:
    var pid = _current_pid()
    _grand_prix_pending = false

    _set_state(TurnState.WAITING_FOR_TURN_START)
    GameEvents.turn_started.emit(pid)
    GameEvents.update_turn_hud.emit(pid)

# ─────────────────────────────────────────
# MÁQUINA DE ESTADOS — transiciones
# ─────────────────────────────────────────
func _set_state(new_state: TurnState) -> void:
    current_state = new_state
    GameEvents.turn_state_changed.emit(_current_pid(), new_state)
    print("[TurnManager] Estado: ", TurnState.keys()[new_state],
          " — Jugador: ", _current_pid())

# El jugador presionó "Tirar"
func _on_roll_button_pressed() -> void:
    if current_state != TurnState.WAITING_FOR_TURN_START:
        return
    _set_state(TurnState.ROLLING_DICE)
    dice_system.roll_for_player(_current_pid())

# Ambos dados cayeron — el jugador ahora elige orden
func _on_dice_completed(numeric: int, powerup: Dictionary, order: int) -> void:
    _numeric_result = numeric
    _powerup_face = powerup
    _resolve_order = order
    # El DiceSystem ya mostró el OrderSelector y emitió dice_order_chosen
    # cuando el jugador eligió — aquí solo guardamos los resultados

func _on_dice_order_chosen(order: int) -> void:
    _resolve_order = order
    _set_state(TurnState.RESOLVING_POWERUP if order == 1 else TurnState.MOVING_PLAYER)

    if order == 1:
        # Power-up primero
        _resolve_powerup_phase()
    else:
        # Mover primero
        _resolve_movement_phase()

# ─────────────────────────────────────────
# FASE DE POWER-UP
# ─────────────────────────────────────────
func _resolve_powerup_phase() -> void:
    _set_state(TurnState.RESOLVING_POWERUP)
    var pid = _current_pid()

    # Verificar si Metal Mario bloqueó este turno
    if character_system.skip_powerup_flags.get(pid, false):
        character_system.skip_powerup_flags[pid] = false
        GameEvents.powerup_skipped.emit(pid)
        _after_powerup()
        return

    character_system.resolve_powerup(pid, _powerup_face)
    # Espera señal powerup_effect_completed

func _on_powerup_completed(_pid: int) -> void:
    if current_state != TurnState.RESOLVING_POWERUP:
        return
    _after_powerup()

func _after_powerup() -> void:
    if _resolve_order == 1:
        # Power-up fue primero → ahora mover
        _resolve_movement_phase()
    else:
        # Power-up fue segundo → turno terminado
        _check_grand_prix_or_end()

# ─────────────────────────────────────────
# FASE DE MOVIMIENTO
# ─────────────────────────────────────────
func _resolve_movement_phase() -> void:
    _set_state(TurnState.MOVING_PLAYER)
    var pid = _current_pid()
    board_manager.move_player(pid, _numeric_result)
    # Espera señal player_move_completed

func _on_move_completed(pid: int, landed_square) -> void:
    if pid != _current_pid():
        return
    _set_state(TurnState.RESOLVING_SQUARE)
    # La casilla ejecuta su efecto automáticamente al llegar
    # Espera señal square_effect_completed

func _on_square_effect_completed(pid: int) -> void:
    if pid != _current_pid():
        return

    if _resolve_order == 0:
        # Movimiento fue primero → ahora el power-up
        _resolve_powerup_phase()
    else:
        # Power-up fue primero → verificar Grand Prix y terminar
        _check_grand_prix_or_end()

# ─────────────────────────────────────────
# SEÑAL DE PASO POR GO
# ─────────────────────────────────────────
func _on_passed_go(pid: int) -> void:
    if pid != _current_pid():
        return
    _grand_prix_pending = true
    # No interrumpe el movimiento — se activa después de resolver la casilla

# ─────────────────────────────────────────
# VERIFICAR GRAND PRIX ANTES DE TERMINAR
# ─────────────────────────────────────────
func _check_grand_prix_or_end() -> void:
    if _grand_prix_pending:
        _set_state(TurnState.CHECKING_GRAND_PRIX)
        _grand_prix_pending = false
        GameEvents.trigger_grand_prix.emit(_current_pid())
        # Espera race_completed + race_ui_closed
    else:
        _end_turn()

func _on_race_completed(_results: Array) -> void:
    # La carrera terminó — esperamos que el jugador cierre la UI
    pass

func _on_race_ui_closed() -> void:
    if current_state != TurnState.CHECKING_GRAND_PRIX:
        return
    _end_turn()

# ─────────────────────────────────────────
# INTERACCIONES (pickers abiertos)
# ─────────────────────────────────────────
func _on_interaction_completed() -> void:
    if current_state != TurnState.WAITING_FOR_INTERACTION:
        return
    # Retomar donde estábamos antes de la interacción
    # El estado anterior se restaura desde _pending_state
    _set_state(_pending_resume_state)
    _resume_callbacks[_pending_resume_state].call()

# Llamado por InteractionUI cuando abre un picker
var _pending_resume_state: TurnState = TurnState.TURN_ENDED
var _resume_callbacks: Dictionary = {}

func pause_for_interaction(resume_state: TurnState, resume_fn: Callable) -> void:
    _pending_resume_state = resume_state
    _resume_callbacks[resume_state] = resume_fn
    _set_state(TurnState.WAITING_FOR_INTERACTION)

# ─────────────────────────────────────────
# FIN DE TURNO
# ─────────────────────────────────────────
func _end_turn() -> void:
    _set_state(TurnState.TURN_ENDED)
    GameEvents.turn_ended.emit(_current_pid())

    # Verificar si el juego terminó (lo maneja GrandPrixSystem)
    if grand_prix_system.race_index >= grand_prix_system.total_races:
        return  # game_over ya fue emitido por GrandPrixSystem

    # Siguiente jugador — saltear si está en cárcel
    _advance_to_next_player()

func _advance_to_next_player() -> void:
    var attempts = 0
    while attempts < player_order.size():
        current_player_index = (current_player_index + 1) % player_order.size()
        var pid = _current_pid()

        if PlayerManager.is_in_jail(pid):
            PlayerManager.tick_jail_turn(pid)
            GameEvents.jail_turn_skipped.emit(pid)
            attempts += 1
            continue

        break

    _begin_turn()

# ─────────────────────────────────────────
# UTILIDADES
# ─────────────────────────────────────────
func _current_pid() -> int:
    return player_order[current_player_index]

func get_current_state() -> TurnState:
    return current_state

func get_current_player() -> int:
    return _current_pid()
