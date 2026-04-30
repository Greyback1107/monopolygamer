class_name GrandPrixSystem
extends Node

signal race_started(card_data: Dictionary)
signal race_completed(results: Array)
signal game_over_triggered()

# Estado del mazo
var deck: Array = []           # cartas en orden, cargadas desde JSON
var current_card: Dictionary = {}
var race_index: int = 0        # cuántas carreras se han jugado
var total_races: int = 8

# Estado de la carrera activa
var participants: Array = []   # player_ids que pagaron y participan
var race_rolls: Dictionary = {}  # player_id → resultado del dado

func _ready() -> void:
    _load_deck()
    GameEvents.trigger_grand_prix.connect(_on_grand_prix_triggered)

# ─────────────────────────────────────────
# CARGA DEL MAZO
# ─────────────────────────────────────────
func _load_deck() -> void:
    var file = FileAccess.open(
        "res://resources/grand_prix/grand_prix_cards.json",
        FileAccess.READ
    )
    if file == null:
        push_error("No se pudo abrir grand_prix_cards.json")
        return

    var json = JSON.new()
    json.parse(file.get_as_text())
    file.close()

    # Las cartas ya vienen en orden en el JSON (1→8)
    deck = json.data["cards"]
    total_races = deck.size()
    print("Mazo Grand Prix cargado: ", total_races, " carreras")

# ─────────────────────────────────────────
# ACTIVACIÓN — llamado cuando alguien pasa GO
# ─────────────────────────────────────────
func _on_grand_prix_triggered(triggering_player_id: int) -> void:
    if race_index >= total_races:
        return  # no debería pasar, pero por seguridad

    current_card = deck[race_index]
    participants = []
    race_rolls = {}

    race_started.emit(current_card)
    GameEvents.show_race_ui.emit(triggering_player_id, current_card)

# ─────────────────────────────────────────
# FASE 1 — Jugadores deciden si participan
# ─────────────────────────────────────────
func player_joins(player_id: int, player_coins: int) -> bool:
    var cost = current_card.get("roll_cost", 0)
    var is_final = current_card.get("is_final", false)

    # En la carrera final todos participan gratis
    if is_final:
        participants.append(player_id)
        return true

    if player_coins < cost:
        return false   # no puede pagar

    # Cobrar el costo de entrada
    GameEvents.effect_collect_coins.emit(player_id, -cost)  # negativo = pagar
    participants.append(player_id)
    return true

func player_skips(player_id: int) -> void:
    # El jugador decide no participar, no hace nada
    pass

# ─────────────────────────────────────────
# FASE 2 — Lanzar dados y resolver posiciones
# ─────────────────────────────────────────
func roll_for_all_participants() -> void:
    race_rolls = {}
    for pid in participants:
        race_rolls[pid] = randi_range(1, 6)

    _resolve_race()

func _resolve_race() -> void:
    # Ordenar de mayor a menor, resolver empates
    var sorted_players = _sort_with_tiebreakers(race_rolls)

    # Asignar premios según posición
    var place_keys = ["1st", "2nd", "3rd", "4th"]
    var results = []

    for i in sorted_players.size():
        var player_id = sorted_players[i]
        var place = place_keys[min(i, place_keys.size() - 1)]
        var prize = current_card["prizes"].get(
            place, {"points": 0, "actions": []}
        )

        # Entregar puntos
        if prize["points"] > 0:
            GameEvents.award_race_points.emit(player_id, prize["points"])

        # Ejecutar acciones del premio
        for action in prize.get("actions", []):
            _execute_prize_action(player_id, action)

        results.append({
            "player_id": player_id,
            "place": i + 1,
            "roll": race_rolls.get(player_id, 0),
            "points_won": prize["points"]
        })

    # El ganador se queda con la carta
    if sorted_players.size() > 0:
        var winner_id = sorted_players[0]
        GameEvents.award_grand_prix_card.emit(winner_id, current_card)

    race_index += 1
    race_completed.emit(results)

    # ¿Era la última carrera?
    if race_index >= total_races:
        game_over_triggered.emit()
        GameEvents.trigger_game_over.emit()

    # En GrandPrixSystem.gd — reemplaza la parte de premios en _resolve_race()

func _award_prize(player_id: int, prize: Dictionary) -> void:
    # Puntos de carrera
    if prize["points"] > 0:
        GameEvents.award_race_points.emit(player_id, prize["points"])

    # Ejecutar cada acción del premio
    for action in prize["actions"]:
        _execute_prize_action(player_id, action)

func _execute_prize_action(player_id: int, action: Dictionary) -> void:
    match action["type"]:

        # ── Monedas simples ──────────────────────────────
        "collect_coins":
            GameEvents.effect_collect_coins.emit(player_id, action["value"])

        "steal_from_all":
            GameEvents.effect_steal_from_all.emit(player_id, action["value"])

        # ── Dados extra ──────────────────────────────────
        "bonus_roll":
            GameEvents.bonus_roll_requested.emit(player_id, action["die"])

        "roll_and_collect":
            # Tira el dado numérico y cobra esa cantidad al banco
            GameEvents.effect_roll_and_collect.emit(player_id)

        # ── Propiedades ──────────────────────────────────
        "take_cheapest_property":
            # Igual que la Super Star de Luigi
            GameEvents.effect_move_cheapest_property.emit(player_id)

        "buy_property_from_player":
            # El jugador elige una propiedad ajena y la compra al precio del tablero
            GameEvents.effect_buy_from_player.emit(player_id)

        "swap_properties_between_players":
            # Elige 2 jugadores (puede ser él mismo) e intercambian una propiedad
            GameEvents.effect_swap_properties.emit(
                player_id,
                action["can_include_self"]
            )

        "auction_any_property":
            # Elige cualquier propiedad (propia o ajena) y la subasta
            GameEvents.effect_auction_property.emit(
                player_id,
                action["payment_to"]   # "bank"
            )

        # ── Bananas ──────────────────────────────────────
        "place_banana_on_owned_property":
            GameEvents.effect_place_bananas_owned.emit(player_id, 1)

        # ── Shells ───────────────────────────────────────
        "fire_green_shell":
            # Ejecuta el efecto base de concha verde
            GameEvents.effect_target_next_drop.emit(player_id, 3)

        "fire_spiny_shell":
            # Ejecuta el efecto base de concha espinosa
            GameEvents.effect_target_any_drop.emit(player_id, 3)

        # ── Movimiento forzado ────────────────────────────
        "send_to_free_parking":
            GameEvents.effect_send_to_free_parking.emit(
                player_id,
                action["target"],           # "any" = elige jugador
                action["skip_go"],
                action["skip_coins_on_path"]
            )

        "send_to_jail":
            GameEvents.effect_send_to_jail.emit(
                player_id,
                action["target"]            # "any" = elige jugador
            )

        # ── Rainbow Road especial ─────────────────────────
        "steal_grand_prix_card_and_rematch":
            GameEvents.effect_steal_card_rematch.emit(
                player_id,
                action["all_can_participate"]
            )


# ─────────────────────────────────────────
# RESOLUCIÓN DE EMPATES
# ─────────────────────────────────────────
func _sort_with_tiebreakers(rolls: Dictionary) -> Array:
    var sorted_players = rolls.keys()

    # Ordenar por resultado descendente
    sorted_players.sort_custom(func(a, b):
        return rolls[a] > rolls[b]
    )

    # Detectar y resolver empates recursivamente
    var i = 0
    while i < sorted_players.size() - 1:
        var current_roll = rolls[sorted_players[i]]
        var tie_group = [sorted_players[i]]

        # Encontrar todos los que empataron
        var j = i + 1
        while j < sorted_players.size() and rolls[sorted_players[j]] == current_roll:
            tie_group.append(sorted_players[j])
            j += 1

        # Si hay empate, re-tirar para ese grupo
        if tie_group.size() > 1:
            var tie_rolls = {}
            for pid in tie_group:
                tie_rolls[pid] = randi_range(1, 6)
            var resolved = _sort_with_tiebreakers(tie_rolls)
            # Reemplazar en sorted_players
            for k in resolved.size():
                sorted_players[i + k] = resolved[k]

        i += tie_group.size()

    return sorted_players

# ─────────────────────────────────────────
# UTILIDADES
# ─────────────────────────────────────────
func get_remaining_races() -> int:
    return total_races - race_index

func is_final_race() -> bool:
    return race_index == total_races - 1

func get_current_card() -> Dictionary:
    return current_card
