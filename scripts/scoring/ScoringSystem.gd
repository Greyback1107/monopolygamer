class_name ScoringSystem
extends Node

# Estructura por jugador:
# {
#   player_id: {
#     "coins": int,
#     "property_points": int,
#     "race_points": int,
#     "grand_prix_cards": Array,
#     "grand_prix_card_points": int,
#     "total": int
#   }
# }
var scores: Dictionary = {}

func _ready() -> void:
    GameEvents.award_race_points.connect(_on_race_points)
    GameEvents.award_grand_prix_card.connect(_on_grand_prix_card)
    GameEvents.trigger_game_over.connect(_on_game_over)

func register_player(player_id: int) -> void:
    scores[player_id] = {
        "coins": 0,
        "property_points": 0,
        "race_points": 0,
        "grand_prix_cards": [],
        "grand_prix_card_points": 0,
        "total": 0
    }

# ─────────────────────────────────────────
# ACTUALIZACIONES EN TIEMPO REAL
# ─────────────────────────────────────────
func update_coins(player_id: int, coins: int) -> void:
    # Llamado por PlayerManager cada vez que cambian las monedas
    scores[player_id]["coins"] = coins
    _recalculate(player_id)

func update_property_points(player_id: int, points: int) -> void:
    scores[player_id]["property_points"] = points
    _recalculate(player_id)

func _on_race_points(player_id: int, points: int) -> void:
    scores[player_id]["race_points"] += points
    _recalculate(player_id)

func _on_grand_prix_card(player_id: int, card_data: Dictionary) -> void:
    scores[player_id]["grand_prix_cards"].append(card_data)
    scores[player_id]["grand_prix_card_points"] += card_data["card_points"]
    _recalculate(player_id)

func _recalculate(player_id: int) -> void:
    var s = scores[player_id]
    # Cada 5 monedas = 10 puntos adicionales
    var coin_bonus = int(s["coins"] / 5) * 10
    s["total"] = (
        coin_bonus +
        s["property_points"] +
        s["race_points"] +
        s["grand_prix_card_points"]
    )
    GameEvents.score_updated.emit(player_id, s)

func get_final_ranking() -> Array:
    var ranking = []
    for pid in scores.keys():
        ranking.append({ "player_id": pid, "score": scores[pid] })

    # Ordenar por total descendente
    ranking.sort_custom(func(a, b):
        if a["score"]["total"] != b["score"]["total"]:
            return a["score"]["total"] > b["score"]["total"]
        # Desempate: más cartas + propiedades
        var a_cards = a["score"]["grand_prix_cards"].size()
        var b_cards = b["score"]["grand_prix_cards"].size()
        return a_cards > b_cards
    )
    return ranking

func _on_game_over() -> void:
    var ranking = get_final_ranking()
    GameEvents.show_end_screen.emit(ranking)
