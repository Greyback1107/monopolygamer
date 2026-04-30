class_name EndGameScreen
extends CanvasLayer

func _ready() -> void:
    GameEvents.show_end_screen.connect(_on_show)
    visible = false

func _on_show(ranking: Array) -> void:
    visible = true
    $Background/AnimationPlayer.play("fade_in")

    for i in ranking.size():
        var entry = ranking[i]
        var place_node = $PodiumContainer.get_child(i)
        var s = entry["score"]
        var pid = entry["player_id"]

        place_node.get_node("PlayerNameLabel").text = \
            PlayerManager.get_player_name(pid)

        # Desglose de puntos
        var coin_bonus = int(s["coins"] / 5) * 10
        place_node.get_node("ScoreBreakdown/CoinsLabel").text = \
            "Monedas: %d (+%d pts)" % [s["coins"], coin_bonus]
        place_node.get_node("ScoreBreakdown/PropertiesLabel").text = \
            "Propiedades: +%d pts" % s["property_points"]
        place_node.get_node("ScoreBreakdown/RaceLabel").text = \
            "Carreras: +%d pts" % s["race_points"]
        place_node.get_node("ScoreBreakdown/CardsLabel").text = \
            "Cartas GP: +%d pts" % s["grand_prix_card_points"]
        place_node.get_node("ScoreBreakdown/TotalLabel").text = \
            "TOTAL: %d pts" % s["total"]

    # Banner del ganador
    var winner_name = PlayerManager.get_player_name(ranking[0]["player_id"])
    $WinnerBanner/WinnerLabel.text = "¡%s GANA!" % winner_name

    $PlayAgainButton.pressed.connect(func():
        get_tree().reload_current_scene()
    )
