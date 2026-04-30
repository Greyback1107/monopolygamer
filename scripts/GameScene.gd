extends Node2D

var camera: Camera2D

func _ready() -> void:
    camera = get_node_or_null("Camera2D")
    if camera:
        camera.position = Vector2(640, 390)
        camera.zoom = Vector2(0.9, 0.9)

    if GameConfig.player_configs.size() < 2:
        get_tree().change_scene_to_file("res://scenes/menus/MainMenu.tscn")
        return

    PlayerManager.initialize_players(GameConfig.player_configs)

    var cs = get_node_or_null("CharacterSystem")
    if cs:
        for config in GameConfig.player_configs:
            cs.assign_character(config["id"], config["character_id"])

    var ss = get_node_or_null("ScoringSystem")
    if ss:
        for config in GameConfig.player_configs:
            ss.register_player(config["id"])

    var player_ids = GameConfig.player_configs.map(func(c): return c["id"])
    var tm = get_node_or_null("TurnManager")
    if tm:
        tm.start_game(player_ids)

func _input(event: InputEvent) -> void:
    if camera == null:
        return
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera.zoom = (camera.zoom * 1.1).clamp(
                Vector2(0.3, 0.3), Vector2(3.0, 3.0))
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera.zoom = (camera.zoom * 0.9).clamp(
                Vector2(0.3, 0.3), Vector2(3.0, 3.0))
    if event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            camera.position -= event.relative / camera.zoom
