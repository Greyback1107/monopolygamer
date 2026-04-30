class_name CharacterSystem
extends Node

# Cargado desde JSON
var all_characters: Dictionary = {}     # id → datos completos
var active_characters: Dictionary = {}  # player_id → character_id
var skip_powerup_flags: Dictionary = {} # player_id → bool

func _ready() -> void:
    _load_characters()
    # Escuchar eventos relevantes
    GameEvents.activate_superstar.connect(_on_superstar_activated)
    GameEvents.dice_roll_completed.connect(_on_dice_resolved)

# ─────────────────────────────────────────────
# CARGA DE DATOS
# ─────────────────────────────────────────────
func _load_characters() -> void:
    var file = FileAccess.open(
        "res://resources/characters/characters.json",
        FileAccess.READ
    )
    if file == null:
        push_error("No se pudo abrir characters.json")
        return

    var json = JSON.new()
    json.parse(file.get_as_text())
    file.close()

    for char_data in json.data["characters"]:
        all_characters[char_data["id"]] = char_data

    print("Personajes cargados: ", all_characters.keys())

# ─────────────────────────────────────────────
# ASIGNACIÓN DE PERSONAJE A JUGADOR
# ─────────────────────────────────────────────
func assign_character(player_id: int, character_id: String) -> void:
    if not all_characters.has(character_id):
        push_error("Personaje no encontrado: " + character_id)
        return
    active_characters[player_id] = character_id
    skip_powerup_flags[player_id] = false

func get_character(player_id: int) -> Dictionary:
    var char_id = active_characters.get(player_id, "")
    return all_characters.get(char_id, {})

# ─────────────────────────────────────────────
# POWER-UP BOOST — modifica resultado del dado
# ─────────────────────────────────────────────
func resolve_powerup(player_id: int, face: Dictionary) -> void:
    # Verificar si Metal Mario bloqueó este turno
    if skip_powerup_flags.get(player_id, false):
        skip_powerup_flags[player_id] = false
        GameEvents.powerup_skipped.emit(player_id)
        return

    var char_data = get_character(player_id)
    if char_data.is_empty():
        _apply_base_effect(player_id, face)
        return

    var boost = char_data["powerup_boost"]

    # ¿Este personaje modifica esta cara específica?
    if boost["triggers_on"] == face["id"]:
        _apply_boost_effect(player_id, boost["actions"])
    else:
        _apply_base_effect(player_id, face)

# ─────────────────────────────────────────────
# SUPER STAR ABILITY — activada por casilla ⭐
# ─────────────────────────────────────────────
func _on_superstar_activated(player_id: int) -> void:
    var char_data = get_character(player_id)
    if char_data.is_empty():
        return
    var ability = char_data["superstar_ability"]
    _apply_boost_effect(player_id, ability["actions"])
    GameEvents.superstar_animation.emit(player_id)

# ─────────────────────────────────────────────
# APLICADOR DE ACCIONES — lee el JSON y actúa
# ─────────────────────────────────────────────
func _apply_boost_effect(player_id: int, actions: Array) -> void:
    for action in actions:
        _execute_action(player_id, action)

func _apply_base_effect(player_id: int, face: Dictionary) -> void:
    match face["id"]:
        "coins":
            GameEvents.effect_collect_coins.emit(player_id, 3)
        "green_shell":
            GameEvents.effect_target_next_drop.emit(player_id, 3)
        "spiny_shell":
            GameEvents.effect_target_any_drop.emit(player_id, 3)
        "lightning":
            GameEvents.effect_all_drop.emit(player_id, 1)
        "banana":
            GameEvents.effect_place_banana.emit(player_id)

func _execute_action(player_id: int, action: Dictionary) -> void:
    match action["type"]:
        "collect_coins":
            GameEvents.effect_collect_coins.emit(player_id, action["value"])

        "bonus_roll":
            GameEvents.bonus_roll_requested.emit(player_id, action["die"])

        "steal_from_target":
            GameEvents.effect_steal_coins.emit(player_id, -1, action["value"])
            # -1 = el jugador debe elegir objetivo en UI

        "steal_from_all":
            GameEvents.effect_steal_from_all.emit(player_id, action["value"])

        "all_others_drop":
            GameEvents.effect_all_drop.emit(player_id, action["value"])

        "richest_drops":
            GameEvents.effect_richest_drops.emit(player_id, action["value"])

        "others_drop":
            GameEvents.effect_others_drop.emit(player_id, action["value"])

        "next_player_drops":
            GameEvents.effect_target_next_drop.emit(player_id, action["value"])

        "collect_dropped_coins":
            GameEvents.effect_collect_dropped.emit(player_id)

        "move_to_cheapest_property":
            GameEvents.effect_move_cheapest_property.emit(player_id)

        "move_to_next_superstar":
            GameEvents.effect_move_to_superstar.emit(player_id)

        "place_bananas_on_owned":
            GameEvents.effect_place_bananas_owned.emit(player_id, action["count"])

        "remove_bananas_for_coins":
            GameEvents.effect_remove_bananas_coins.emit(
                player_id, action["coins_per_banana"]
            )

        "spend_coins_to_move":
            GameEvents.effect_spend_coins_move.emit(player_id, action["max_coins"])

        "skip_others_powerup_roll":
            _apply_metal_mario_skip(player_id)

        "swap_position_with_target":
            GameEvents.effect_swap_position.emit(player_id)

        "target_choice_drop":
            GameEvents.effect_target_choice_drop.emit(
                player_id, action["value"], action["direction"]
            )

        "collect_all_board_coins":
            GameEvents.effect_collect_board_coins.emit(player_id)

# Metal Mario: marca a todos los demás para saltarse su próximo power-up
func _apply_metal_mario_skip(source_player_id: int) -> void:
    for pid in skip_powerup_flags.keys():
        if pid != source_player_id:
            skip_powerup_flags[pid] = true
    GameEvents.metal_mario_activated.emit(source_player_id)

# Llamado al terminar resolución de dados
func _on_dice_resolved(player_id, _numeric, powerup_face, resolve_order) -> void:
    if resolve_order == 1:  # 1 = POWER_FIRST
        resolve_powerup(player_id, powerup_face)
