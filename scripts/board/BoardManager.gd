class_name BoardManager
extends Node

# ─────────────────────────────────────────
# CONSTANTES
# ─────────────────────────────────────────
const TOTAL_SQUARES = 32
const GO_SQUARE_INDEX = 0
const JAIL_SQUARE_INDEX = 18
const FREE_PARKING_INDEX = 9     # ajusta según tu tablero

# ─────────────────────────────────────────
# ESTADO DEL TABLERO
# ─────────────────────────────────────────
# Todas las casillas instanciadas en orden
var squares: Array = []

var color_groups: Dictionary = {}

# Monedas físicas en el tablero: square_index → cantidad
var coins_on_board: Dictionary = {}

# Bananas activas: square_index → true
var bananas_on_board: Dictionary = {}
const MAX_BANANAS = 4

# Grupos de color: color_group → [square_id, square_id]
var color_groups: Dictionary = {}
var square_defs: Dictionary = {}  # square_id -> data json

# Colores visuales por grupo
const GROUP_COLORS = {
    "brown":      Color("#8B4513"),
    "light_blue": Color("#ADD8E6"),
    "maroon":     Color("#800000"),
    "orange":     Color("#FFA500"),
    "red":        Color("#FF0000"),
    "yellow":     Color("#FFD700"),
    "green":      Color("#008000"),
    "dark_blue":  Color("#00008B")
}

func _ready() -> void:
    _load_square_defs()
    _build_square_registry()
    _init_starting_coins()
    _connect_signals()

# ─────────────────────────────────────────
# CONSTRUCCIÓN DEL REGISTRO DE CASILLAS
# ─────────────────────────────────────────
func _build_square_registry() -> void:
    squares.clear()
    color_groups.clear()

    var board = get_node_or_null("../Board")
    if board == null:
        push_error("BoardManager: no se encontró ../Board")
        return

    var container = get_node_or_null("../Board/SquaresContainer")
    if container and container.get_child_count() > 0:
        for i in container.get_child_count():
            squares.append(container.get_child(i))
    else:
        for child in board.get_children():
            if child.name.begins_with("Square_"):
                squares.append(child)

    if squares.is_empty():
        push_error("BoardManager: no se encontraron casillas registrables")
        return

    print("BoardManager: %d casillas registradas" % squares.size())


# ─────────────────────────────────────────
# CONEXIÓN DE SEÑALES
# ─────────────────────────────────────────
func _connect_signals() -> void:
    GameEvents.coins_placed_on_square.connect(_on_coins_placed)
    GameEvents.effect_place_banana.connect(_on_place_banana_requested)
    GameEvents.effect_place_bananas_owned.connect(_on_place_banana_on_property)
    GameEvents.player_move_forced.connect(_on_move_forced)
    GameEvents.effect_collect_board_coins.connect(_on_collect_all_board_coins)
    GameEvents.effect_remove_bananas_coins.connect(_on_remove_bananas_for_coins)

# ─────────────────────────────────────────
# MOVIMIENTO PRINCIPAL
# ─────────────────────────────────────────
func move_player(player_id: int, steps: int) -> void:
    var player = PlayerManager.get_player(player_id)
    if not player:
        return

    var start = player.square_index
    _move_step_by_step(player_id, start, steps)

func _move_step_by_step(
        player_id: int,
        from_index: int,
        steps: int) -> void:

    var player = PlayerManager.get_player(player_id)
    var current = from_index

    for i in steps:
        var next = (current + 1) % TOTAL_SQUARES

        # ── Pasar por GO ──────────────────────────
        if next == GO_SQUARE_INDEX and current != GO_SQUARE_INDEX:
            _on_pass_go(player_id)

        # ── Recoger monedas en el camino ──────────
        if coins_on_board.has(next) and i < steps - 1:
            # Solo recoge al pasar — no al aterrizar
            # (al aterrizar lo maneja la casilla)
            var picked = coins_on_board[next]
            coins_on_board.erase(next)
            PlayerManager.get_player(player_id).add_coins(picked)
            GameEvents.coins_collected_on_path.emit(player_id, next, picked)

        # ── Banana en el camino — detener aquí ───
        if bananas_on_board.has(next):
            current = next
            player.square_index = current
            _remove_banana(current)
            GameEvents.banana_triggered.emit(player_id, current)
            # Aterrizar en esta casilla aunque no era el destino final
            _land_on_square(player_id, current)
            # Mover visualmente la ficha
            GameEvents.player_token_move.emit(player_id, current)
            # Notificar que el movimiento terminó (interrumpido por banana)
            GameEvents.player_move_completed.emit(
                player_id, squares[current]
            )
            return

        current = next

    # ── Llegó al destino sin interrupciones ──────
    player.square_index = current
    GameEvents.player_token_move.emit(player_id, current)
    _land_on_square(player_id, current)
    GameEvents.player_move_completed.emit(player_id, squares[current])

# ─────────────────────────────────────────
# ATERRIZAJE EN CASILLA
# ─────────────────────────────────────────
func _land_on_square(player_id: int, square_index: int) -> void:
    if square_index < 0 or square_index >= squares.size():
        GameEvents.square_effect_completed.emit(player_id)
        return
    var square = squares[square_index]

    # Recoger monedas que estaban en la casilla
    if coins_on_board.has(square_index):
        var picked = coins_on_board[square_index]
        coins_on_board.erase(square_index)
        PlayerManager.get_player(player_id).add_coins(picked)
        GameEvents.coins_collected_on_land.emit(player_id, square_index, picked)

    # Ejecutar el efecto de la casilla
    if square.has_method("on_player_land"):
        square.on_player_land(PlayerManager.get_player(player_id))
        return

    _resolve_visual_square_effect(player_id, square_index)

# ─────────────────────────────────────────
# PASO POR GO
# ─────────────────────────────────────────
func _on_pass_go(player_id: int) -> void:
    var player = PlayerManager.get_player(player_id)
    player.add_coins(2)   # cobrar monedas de GO
    GameEvents.passed_go.emit(player_id)
    GameEvents.coins_collected_on_path.emit(player_id, GO_SQUARE_INDEX, 2)

# ─────────────────────────────────────────
# SISTEMA DE BANANAS
# ─────────────────────────────────────────
func _on_place_banana_requested(player_id: int) -> void:
    # El jugador elige en qué casilla del recorrido colocarla
    if bananas_on_board.size() >= MAX_BANANAS:
        # Ya hay 4 bananas — no se puede colocar más
        GameEvents.banana_limit_reached.emit()
        return
    # Abrir selector de casilla del recorrido
    GameEvents.request_banana_placement.emit(player_id)

func place_banana(square_index: int) -> void:
    if bananas_on_board.size() >= MAX_BANANAS:
        return
    if bananas_on_board.has(square_index):
        return  # ya hay una banana aquí
    bananas_on_board[square_index] = true
    if square_index >= 0 and square_index < squares.size() and squares[square_index].has_method("place_banana"):
        squares[square_index].place_banana()
    GameEvents.banana_placed.emit(square_index)

func _remove_banana(square_index: int) -> void:
    bananas_on_board.erase(square_index)
    if square_index >= 0 and square_index < squares.size() and squares[square_index].has_method("remove_banana"):
        squares[square_index].remove_banana()
    GameEvents.banana_removed.emit(square_index)

func _on_place_banana_on_property(player_id: int, count: int) -> void:
    # Donkey Kong Super Star — coloca banana en sus propiedades
    var player = PlayerManager.get_player(player_id)
    var placed = 0
    for sid in player.owned_properties:
        if placed >= count:
            break
        if not bananas_on_board.has(sid) \
                and bananas_on_board.size() < MAX_BANANAS:
            place_banana(sid)
            placed += 1

func _on_remove_bananas_for_coins(player_id: int, coins_per_banana: int) -> void:
    # Donkey Kong Power-Up Boost
    if bananas_on_board.is_empty():
        return
    # El jugador elige cuántas retirar
    GameEvents.request_banana_removal.emit(
        player_id, bananas_on_board.keys(), coins_per_banana
    )

func remove_banana_for_coins(
        player_id: int,
        square_index: int,
        coins_per_banana: int) -> void:
    _remove_banana(square_index)
    PlayerManager.get_player(player_id).add_coins(coins_per_banana)

# ─────────────────────────────────────────
# MONEDAS EN EL TABLERO
# ─────────────────────────────────────────
func _on_coins_placed(square_index: int, amount: int) -> void:
    if amount <= 0:
        return
    if not coins_on_board.has(square_index):
        coins_on_board[square_index] = 0
    coins_on_board[square_index] += amount
    if square_index >= 0 and square_index < squares.size() and squares[square_index].has_method("show_coins"):
        squares[square_index].show_coins(amount)
    GameEvents.board_coins_updated.emit(square_index, coins_on_board[square_index])

func _on_collect_all_board_coins(player_id: int) -> void:
    # Yoshi Super Star — recoge TODO lo que hay en el tablero
    var total = 0
    for idx in coins_on_board.keys():
        total += coins_on_board[idx]
        if idx >= 0 and idx < squares.size() and squares[idx].has_method("hide_coins"):
            squares[idx].hide_coins()
    coins_on_board.clear()
    if total > 0:
        PlayerManager.get_player(player_id).add_coins(total)
        GameEvents.coins_collected_all.emit(player_id, total)

# ─────────────────────────────────────────
# MOVIMIENTO FORZADO (sin pasar por GO)
# ─────────────────────────────────────────
func _on_move_forced(player_id: int, target_index: int) -> void:
    var player = PlayerManager.get_player(player_id)
    if not player:
        return
    player.square_index = target_index
    GameEvents.player_token_move.emit(player_id, target_index)
    # El movimiento forzado NO activa la casilla destino
    # (excepción: cárcel sí aplica su lógica, pero la maneja PlayerManager)
    GameEvents.player_move_completed.emit(player_id, squares[target_index])

# ─────────────────────────────────────────
# BOOST PAD — tirada extra de movimiento
# ─────────────────────────────────────────
func handle_boost_pad(player_id: int, extra_steps: int) -> void:
    move_player(player_id, extra_steps)

# ─────────────────────────────────────────
# CONSULTAS PÚBLICAS
# ─────────────────────────────────────────
func get_square(square_id: int) -> Square:
    if square_id >= 0 and square_id < squares.size():
        return squares[square_id]
    return null

func get_squares_by_group(color_group: String) -> Array:
    return color_groups.get(color_group, [])

func get_group_color(color_group: String) -> Color:
    return GROUP_COLORS.get(color_group, Color.WHITE)

func get_free_parking_index() -> int:
    return FREE_PARKING_INDEX

func get_all_property_squares() -> Array:
    var result = []
    for square in squares:
        if square is PropertySquare:
            result.append(square)
    return result

func get_banana_squares() -> Array:
    return bananas_on_board.keys()

func has_banana(square_index: int) -> bool:
    return bananas_on_board.has(square_index)

func get_coins_on_square(square_index: int) -> int:
    return coins_on_board.get(square_index, 0)

func _load_square_defs() -> void:
    square_defs.clear()
    var f = FileAccess.open("res://resources/board_data/board_layout.json", FileAccess.READ)
    if f == null:
        return
    var j = JSON.new()
    if j.parse(f.get_as_text()) != OK:
        f.close()
        return
    f.close()
    for sq in j.data.get("squares", []):
        square_defs[sq.get("id", -1)] = sq

func _init_starting_coins() -> void:
    coins_on_board.clear()
    for i in TOTAL_SQUARES:
        coins_on_board[i] = 1


func _resolve_visual_square_effect(player_id: int, square_index: int) -> void:
    var sq = square_defs.get(square_index, {})
    var sq_type = String(sq.get("type", ""))

    if sq_type == "BOOST_PAD":
        GameEvents.bonus_roll_requested.emit(player_id, "numeric")
        GameEvents.square_effect_completed.emit(player_id)
        return

    if sq_type == "PROPERTY":
        var prop_square = _build_property_proxy(square_index, sq)
        if prop_square.owner_player == null:
            GameEvents.property_available.emit(player_id, prop_square)
        elif prop_square.owner_player.player_id != player_id:
            var rent = prop_square.data.rent_base
            if PlayerManager.player_owns_full_set(prop_square.owner_player.player_id, prop_square.data.color_group):
                rent = prop_square.data.rent_double
            GameEvents.rent_due.emit(player_id, prop_square.owner_player.player_id, rent)
        GameEvents.square_effect_completed.emit(player_id)
        return

    GameEvents.square_effect_completed.emit(player_id)


func _build_property_proxy(square_index: int, sq: Dictionary):
    var proxy = Node2D.new()
    proxy.set_script(load("res://scripts/board/squares/PropertySquare.gd"))
    proxy.square_id = square_index
    var data = SquareData.new()
    data.square_name = String(sq.get("name", "Propiedad"))
    data.buy_cost = int(sq.get("buy_cost", 0))
    data.rent_base = int(sq.get("rent_base", 1))
    data.rent_double = int(sq.get("rent_double", data.rent_base * 2))
    data.point_value = int(sq.get("point_value", 1))
    data.color_group = String(sq.get("color_group", ""))
    proxy.data = data

    for pid in PlayerManager.get_active_player_ids():
        var p = PlayerManager.get_player(pid)
        if p and p.owns_property(square_index):
            proxy.owner_player = p
            break
    return proxy
