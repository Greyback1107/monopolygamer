class_name CardPicker
extends PanelContainer

signal card_chosen(card_data: Dictionary)

func show_picker(source_player: int, title: String) -> void:
    $TitleLabel.text = title

    for child in $CardsContainer.get_children():
        child.queue_free()

    # Obtener ScoringSystem como nodo
    var scoring = get_node_or_null("/root/GameScene/ScoringSystem")
    if not scoring:
        push_error("CardPicker: No se encontró ScoringSystem")
        return

    for pid in PlayerManager.get_active_player_ids():
        if pid == source_player:
            continue
        var cards = scoring.scores[pid]["grand_prix_cards"]
        for card in cards:
            var btn = Button.new()
            btn.text = "%s\n(%d pts)" % [
                card["name"], card["card_points"]
            ]
            btn.pressed.connect(func(): card_chosen.emit(card))
            $CardsContainer.add_child(btn)

    show()
