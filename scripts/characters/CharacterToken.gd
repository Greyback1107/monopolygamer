class_name CharacterToken
extends Node2D

var player_id: int = -1
var player_color: Color = Color.WHITE
var character_id: String = ""

const RADIUS = 26.0

func setup(pid: int, char_id: String, color: Color) -> void:
    player_id = pid
    character_id = char_id
    player_color = color
    z_as_relative = false
    z_index = 500
    _build_visuals()
    _connect_signals()

func _build_visuals() -> void:
    var circle = Node2D.new()
    circle.name = "TokenCircle"
    var circle_script = GDScript.new()
    circle_script.source_code = """
extends Node2D
var color: Color = Color.WHITE
var radius: float = 18.0
func _draw():
    draw_circle(Vector2.ZERO, radius, color)
    draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color.WHITE, 4.0)
    draw_arc(Vector2.ZERO, radius - 2.0, 0, TAU, 48, Color.BLACK, 1.5)
"""
    circle_script.reload()
    circle.set_script(circle_script)
    circle.set("color", player_color)
    circle.set("radius", RADIUS)
    add_child(circle)

    var lbl = Label.new()
    lbl.name = "InitialsLabel"
    lbl.text = _get_initials(character_id)
    lbl.add_theme_font_size_override("font_size", 16)
    lbl.add_theme_color_override("font_color", Color.WHITE)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.size = Vector2(RADIUS * 2, RADIUS * 2)
    lbl.position = Vector2(-RADIUS, -RADIUS)
    add_child(lbl)

func _connect_signals() -> void:
    GameEvents.player_token_move.connect(_on_move)

func _on_move(pid: int, target_square: int) -> void:
    if pid != player_id:
        return
    var board = get_tree().current_scene.get_node_or_null("Board")
    if board and board.has_method("get_square_position"):
        _animate_to(board.get_square_position(target_square))

func _animate_to(target: Vector2) -> void:
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.set_trans(Tween.TRANS_CUBIC)
    var mid = (global_position + target) / 2 + Vector2(0, -30)
    tween.tween_property(self, "global_position", mid, 0.15)
    tween.tween_property(self, "global_position", target, 0.15)

func _get_initials(char_id: String) -> String:
    match char_id:
        "mario": return "MA"
        "peach": return "PE"
        "luigi": return "LU"
        "toad": return "TO"
        "bowser": return "BO"
        "yoshi": return "YO"
        "donkey_kong": return "DK"
        "rosalina": return "RO"
        "metal_mario": return "MM"
        "shy_guy": return "SG"
        _: return "??"
