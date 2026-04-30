class_name DiceSystem
extends Node2D

signal turn_dice_completed(numeric_result: int, powerup_face: Dictionary, order: int)
signal waiting_for_order_choice()

enum ResolveOrder { MOVE_FIRST, POWER_FIRST }

var numeric_result: int = 0
var powerup_face: Dictionary = {}
var current_player = null
var resolve_order: ResolveOrder = ResolveOrder.MOVE_FIRST
var _rolls_pending: int = 0

@onready var numeric_die = $NumericDie
@onready var powerup_die = $PowerUpDie
# Buscar DiceDisplay en UI sin depender del path relativo
var dice_display: Node = null

func _ready() -> void:
    # Buscar DiceDisplay de forma segura
    dice_display = get_node_or_null("/root/GameScene/UI/DiceDisplay")
    if not dice_display:
        push_error("DiceSystem: No se encontró DiceDisplay en UI")
    
    if numeric_die:
        numeric_die.roll_completed.connect(_on_numeric_roll_done)
    if powerup_die:
        powerup_die.roll_completed.connect(_on_powerup_roll_done)
    
    $OrderSelector/MoveFirstButton.pressed.connect(
        func(): _choose_order(ResolveOrder.MOVE_FIRST)
    )
    $OrderSelector/PowerFirstButton.pressed.connect(
        func(): _choose_order(ResolveOrder.POWER_FIRST)
    )
    $OrderSelector.visible = false
    GameEvents.dice_order_chosen.connect(_on_order_from_display)

# --- ENTRADA PRINCIPAL: el TurnManager llama esto ---
func roll_for_player(player) -> void:
    current_player = player
    numeric_result = 0
    powerup_face = {}
    _rolls_pending = 2

    # Lanzar ambos dados simultáneamente
    $NumericDie.roll()
    $PowerUpDie.roll()

# --- Callbacks de cada dado ---
func _on_numeric_roll_done(result: int) -> void:
    numeric_result = result
    _rolls_pending -= 1
    _check_both_rolled()

func _on_powerup_roll_done(face: Dictionary) -> void:
    powerup_face = face
    _rolls_pending -= 1
    _check_both_rolled()

# En DiceSystem.gd — modificar _check_both_rolled()


func _check_both_rolled() -> void:
    if _rolls_pending > 0:
        return
    # En vez de mostrar el OrderSelector directo,
    # lanzar la animación visual primero
    dice_display.start_roll_animation(numeric_result, powerup_face)
    # El DiceDisplay emitirá dice_order_chosen cuando el jugador elija

func _choose_order(order: ResolveOrder) -> void:
    resolve_order = order
    $OrderSelector.visible = false
    turn_dice_completed.emit(numeric_result, powerup_face, int(order))


func _on_order_from_display(order: int) -> void:
    resolve_order = order
    turn_dice_completed.emit(numeric_result, powerup_face, order)
    GameEvents.dice_roll_completed.emit(current_player, numeric_result, powerup_face, order)
