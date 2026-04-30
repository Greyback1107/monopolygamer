class_name PlayerPicker
extends PanelContainer

signal player_chosen(player_id: int)

var _source_player: int = -1

func show_picker(source_player: int, title: String) -> void:
    _source_player = source_player
    $TitleLabel.text = title

    # Limpiar botones anteriores
    for child in $PlayersGrid.get_children():
        child.queue_free()

    # Crear un botón por cada jugador activo (excepto la fuente)
    for pid in PlayerManager.get_active_player_ids():
        if pid == source_player:
            continue
        var btn = Button.new()
        btn.text = PlayerManager.get_player_name(pid)
        btn.pressed.connect(func(): player_chosen.emit(pid))
        $PlayersGrid.add_child(btn)

    show()
