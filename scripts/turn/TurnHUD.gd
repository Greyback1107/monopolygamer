class_name TurnHUD
extends CanvasLayer

var _turn_label: Label
var _state_label: Label
var _races_label: Label
var _roll_button: Button
var _score_list: Node
var _dice_result_row: Node
var _turn_indicator: ColorRect

func _ready() -> void:
    _turn_label      = _find("TurnLabel")
    _state_label     = _find("StateLabel")
    _races_label     = _find("RacesLeftLabel")
    _roll_button     = _find("RollButton")
    _score_list      = _find("ScoreList")
    _dice_result_row = _find("DiceResultRow")
    _turn_indicator  = _find("TurnIndicator")

    # Verificar que el HUDPanel esté posicionado correctamente
    var hud_panel = _find("HUDPanel")
    if hud_panel:
        hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
        hud_panel.position = Vector2(10, 10)
        hud_panel.custom_minimum_size = Vector2(320, 200)

    if _dice_result_row:
        _dice_result_row.visible = false

    if _roll_button:
        _roll_button.pressed.connect(func():
            GameEvents.roll_button_pressed.emit()
        )

    GameEvents.turn_started.connect(_on_turn_started)
    GameEvents.turn_state_changed.connect(_on_state_changed)
    GameEvents.score_updated.connect(_on_score_updated)
    GameEvents.dice_roll_completed.connect(_on_dice_result)

    # Esperar a que PlayerManager esté listo
    await get_tree().process_frame
    await get_tree().process_frame
    if PlayerManager.get_active_player_ids().size() > 0:
        _build_score_rows()

func _on_turn_started(player_id: int) -> void:
    var player = PlayerManager.get_player(player_id)
    if not player:
        return
    var char_name = _get_char_name(player_id)
    if _turn_label:
        _turn_label.text = "Turno de %s\n(%s)" % [
            char_name, player.player_name
        ]
    if _turn_indicator:
        _turn_indicator.color = player.color
    if _state_label:
        _state_label.text = "Presiona Tirar"
    if _dice_result_row:
        _dice_result_row.visible = false
    if _roll_button:
        _roll_button.disabled = false
    var gp = get_node_or_null("/root/GameScene/GrandPrixSystem")
    if gp and _races_label:
        _races_label.text = "🏁 %d" % gp.get_remaining_races()

func _on_state_changed(_pid: int, state: int) -> void:
    var msgs = {
        0: "Presiona Tirar", 1: "Lanzando...",
        2: "¿Qué primero?",  3: "Power-up...",
        4: "Moviendo...",    5: "Casilla...",
        6: "Elige...",       7: "¡Gran Premio!",
        8: "Fin de turno"
    }
    if _state_label:
        _state_label.text = msgs.get(state, "")
    if _roll_button:
        _roll_button.disabled = (state != 0)

func _on_dice_result(_pid, numeric: int, powerup: Dictionary, _order) -> void:
    if not _dice_result_row:
        return
    _dice_result_row.visible = true
    var num_lbl = _find("NumericLabel")
    var pow_lbl = _find("PowerUpLabel")
    if num_lbl:
        num_lbl.text = str(numeric)
    if pow_lbl:
        pow_lbl.text = powerup.get("label", "")

func _build_score_rows() -> void:
    if not _score_list:
        return
    for child in _score_list.get_children():
        child.queue_free()
    for pid in PlayerManager.get_active_player_ids():
        var player = PlayerManager.get_player(pid)
        var char_name = _get_char_name(pid)
        var row = HBoxContainer.new()
        row.name = "Row_%d" % pid
        var dot = ColorRect.new()
        dot.color = player.color
        dot.custom_minimum_size = Vector2(10, 10)
        var name_lbl = Label.new()
        name_lbl.text = "%s\n%s" % [player.player_name, char_name]
        name_lbl.add_theme_font_size_override("font_size", 10)
        name_lbl.custom_minimum_size = Vector2(120, 0)
        var score_lbl = Label.new()
        score_lbl.name = "ScoreLabel"
        score_lbl.text = "0pts|10🪙"
        score_lbl.add_theme_font_size_override("font_size", 10)
        score_lbl.add_theme_color_override("font_color", Color("#ffd700"))
        row.add_child(dot)
        row.add_child(name_lbl)
        row.add_child(score_lbl)
        _score_list.add_child(row)

func _on_score_updated(player_id: int, score_data: Dictionary) -> void:
    if not _score_list:
        return
    var row = _score_list.get_node_or_null("Row_%d" % player_id)
    if not row:
        return
    var lbl = row.get_node_or_null("ScoreLabel")
    if lbl:
        lbl.text = "%dpts|%d🪙" % [score_data["total"], score_data["coins"]]

func _get_char_name(player_id: int) -> String:
    var cs = get_node_or_null("/root/GameScene/CharacterSystem")
    if not cs:
        return "???"
    var cd = cs.get_character(player_id)
    return cd.get("name", "???") if cd else "???"

func _find(node_name: String) -> Node:
    return _find_recursive(self, node_name)

func _find_recursive(node: Node, target: String) -> Node:
    for child in node.get_children():
        if child.name == target:
            return child
        var found = _find_recursive(child, target)
        if found:
            return found
    return null
