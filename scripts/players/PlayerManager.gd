# scripts/players/PlayerManager.gd
extends Node

var players: Dictionary = {}
var active_player_ids: Array = []

func _ready() -> void:
    _connect_effect_signals()

# ─────────────────────────────────────────
# INICIALIZACIÓN
# ─────────────────────────────────────────
func initialize_players(config: Array) -> void:
    players.clear()
    active_player_ids.clear()

    var slot_colors = [
        Color("#e52521"),
        Color("#4a9f3f"),
        Color("#5b9bd5"),
        Color("#f5a623")
    ]

    for entry in config:
        var pid = entry["id"]
        var p = Player.new()
        p.player_id = pid
        p.player_name = entry.get("name", "Jugador %d" % (pid + 1))
        p.character_id = entry.get("character_id", "mario")
        p.color = slot_colors[pid % slot_colors.size()]
        p.coins = 10
        p.square_index = 0
        players[pid] = p
        active_player_ids.append(pid)

    print("PlayerManager: %d jugadores inicializados" % players.size())

# ─────────────────────────────────────────
# ACCESO A JUGADORES
# ─────────────────────────────────────────
func get_player(player_id: int) -> Player:
    return players.get(player_id, null)

func get_player_name(player_id: int) -> String:
    var p = get_player(player_id)
    return p.player_name if p else "???"

func get_active_player_ids() -> Array:
    return active_player_ids

func is_in_jail(player_id: int) -> bool:
    var p = get_player(player_id)
    return p.is_in_jail if p else false

func tick_jail_turn(player_id: int) -> void:
    var p = get_player(player_id)
    if p:
        p.tick_jail_turn()

func get_richest_player_id(exclude_id: int = -1) -> int:
    var richest_id = -1
    var max_coins = -1
    for pid in active_player_ids:
        if pid == exclude_id:
            continue
        var p = players[pid]
        if p.coins > max_coins:
            max_coins = p.coins
            richest_id = pid
    return richest_id

func get_player_at_square(square_index: int) -> Array:
    var result = []
    for pid in active_player_ids:
        if players[pid].square_index == square_index:
            result.append(pid)
    return result

func get_property_points(player_id: int) -> int:
    var total = 0
    var p = get_player(player_id)
    if not p:
        return 0
    var board = get_node_or_null("/root/GameScene/Board")
    if not board:
        return 0
    for sid in p.owned_properties:
        var square = board.get_square(sid)
        if square and square.get("data") and square.data:
            total += square.data.get("point_value", 0)
    return total

func player_owns_full_set(player_id: int, color_group: String) -> bool:
    var board = get_node_or_null("/root/GameScene/Board")
    if not board:
        return false
    var group_squares = board.get_squares_by_group(color_group)
    var p = get_player(player_id)
    if not p:
        return false
    for sid in group_squares:
        if not p.owns_property(sid):
            return false
    return true

# ─────────────────────────────────────────
# CONEXIÓN DE SEÑALES DE EFECTOS
# ─────────────────────────────────────────
func _connect_effect_signals() -> void:
    GameEvents.effect_collect_coins.connect(_on_collect_coins)
    GameEvents.effect_steal_from_all.connect(_on_steal_from_all)
    GameEvents.effect_steal_coins.connect(_on_steal_coins)
    GameEvents.effect_all_drop.connect(_on_all_drop)
    GameEvents.effect_others_drop.connect(_on_others_drop)
    GameEvents.effect_richest_drops.connect(_on_richest_drops)
    GameEvents.effect_target_next_drop.connect(_on_target_next_drop)
    GameEvents.coins_dropped.connect(_on_coins_dropped)
    GameEvents.coins_stolen.connect(_on_coins_stolen)
    GameEvents.player_sent_to_jail.connect(_on_sent_to_jail)
    GameEvents.player_sent_to_free_parking.connect(_on_sent_to_free_parking)
    GameEvents.positions_swapped.connect(_on_positions_swapped)
    GameEvents.award_grand_prix_card.connect(_on_award_card)
    GameEvents.player_coins_changed.connect(_on_coins_changed_notify_scoring)

# ─────────────────────────────────────────
# HANDLERS DE EFECTOS
# ─────────────────────────────────────────
func _on_collect_coins(player_id: int, amount: int) -> void:
    var p = get_player(player_id)
    if not p:
        return
    if amount >= 0:
        p.add_coins(amount)
    else:
        p.pay_coins(-amount)

func _on_steal_from_all(source_id: int, amount: int) -> void:
    for pid in active_player_ids:
        if pid == source_id:
            continue
        var victim = get_player(pid)
        var actual = victim.pay_coins(amount)
        get_player(source_id).add_coins(actual)

func _on_steal_coins(source_id: int, target_id: int, amount: int) -> void:
    var victim = get_player(target_id)
    if not victim:
        return
    var actual = victim.pay_coins(amount)
    var source = get_player(source_id)
    if source:
        source.add_coins(actual)

func _on_all_drop(source_id: int, amount: int) -> void:
    for pid in active_player_ids:
        if pid == source_id:
            continue
        var p = get_player(pid)
        var dropped = p.pay_coins(amount)
        GameEvents.coins_placed_on_square.emit(p.square_index, dropped)

func _on_others_drop(source_id: int, amount: int) -> void:
    _on_all_drop(source_id, amount)

func _on_richest_drops(source_id: int, amount: int) -> void:
    var richest = get_richest_player_id(source_id)
    if richest == -1:
        return
    var p = get_player(richest)
    var dropped = p.pay_coins(amount)
    GameEvents.coins_placed_on_square.emit(p.square_index, dropped)
    for pid in active_player_ids:
        if pid == source_id or pid == richest:
            continue
        var victim = get_player(pid)
        var d = victim.pay_coins(1)
        GameEvents.coins_placed_on_square.emit(victim.square_index, d)

func _on_target_next_drop(source_id: int, amount: int) -> void:
    var source_pos = get_player(source_id).square_index
    var nearest_id = _find_next_player_ahead(source_id, source_pos)
    if nearest_id == -1:
        return
    var p = get_player(nearest_id)
    var dropped = p.pay_coins(amount)
    GameEvents.coins_placed_on_square.emit(p.square_index, dropped)

func _find_next_player_ahead(source_id: int, from_pos: int) -> int:
    var best_id = -1
    var best_dist = 999
    for pid in active_player_ids:
        if pid == source_id:
            continue
        var p = get_player(pid)
        var dist = (p.square_index - from_pos) % 32
        if dist <= 0:
            dist += 32
        if dist < best_dist:
            best_dist = dist
            best_id = pid
    return best_id

func _on_coins_dropped(player_id: int, amount: int) -> void:
    var p = get_player(player_id)
    if not p:
        return
    var dropped = p.pay_coins(amount)
    GameEvents.coins_placed_on_square.emit(p.square_index, dropped)

func _on_coins_stolen(source_id: int, target_id: int, amount: int) -> void:
    _on_steal_coins(source_id, target_id, amount)

func _on_sent_to_jail(player_id: int) -> void:
    var p = get_player(player_id)
    if p:
        p.send_to_jail()
        GameEvents.player_move_forced.emit(player_id, Player.JAIL_SQUARE_INDEX)

func _on_sent_to_free_parking(
        player_id: int,
        skip_go: bool,
        skip_coins: bool) -> void:
    var p = get_player(player_id)
    if not p:
        return
    var board = get_node_or_null("/root/GameScene/Board")
    if not board:
        return
    var fp_index = board.get_free_parking_index()
    p.square_index = fp_index
    GameEvents.player_move_forced.emit(player_id, fp_index)

func _on_positions_swapped(player_a: int, player_b: int) -> void:
    var pa = get_player(player_a)
    var pb = get_player(player_b)
    if not pa or not pb:
        return
    var temp = pa.square_index
    pa.square_index = pb.square_index
    pb.square_index = temp
    GameEvents.player_move_forced.emit(player_a, pa.square_index)
    GameEvents.player_move_forced.emit(player_b, pb.square_index)

func _on_award_card(player_id: int, card_data: Dictionary) -> void:
    var p = get_player(player_id)
    if p:
        p.add_grand_prix_card(card_data)

func _on_coins_changed_notify_scoring(player_id: int, new_coins: int) -> void:
    var scoring = get_node_or_null("/root/GameScene/ScoringSystem")
    if scoring:
        scoring.update_coins(player_id, new_coins)
        scoring.update_property_points(
            player_id, get_property_points(player_id)
        )
