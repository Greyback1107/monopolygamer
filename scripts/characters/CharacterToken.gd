# En CharacterToken.gd — agregar

func _ready() -> void:
    GameEvents.player_token_move.connect(_on_move_signal)

func _on_move_signal(player_id: int, target_square: int) -> void:
    if player_id != self.player_id:
        return
    var target_pos = Board.get_square_position(target_square)
    _animate_to(target_pos)

func _animate_to(target: Vector2) -> void:
    $AnimationPlayer.stop()
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(self, "position", target, 0.35)
    await tween.finished
    $AnimationPlayer.play("idle")
    
    # scripts/characters/CharacterToken.gd
class_name CharacterToken
extends Node2D

var player_id: int = -1
var player_color: Color = Color.WHITE
var character_id: String = ""

const RADIUS = 18.0

func setup(pid: int, char_id: String, color: Color) -> void:
    player_id = pid
    character_id = char_id
    player_color = color
    _build_visuals()
    _connect_signals()

func _build_visuals() -> void:
    # Círculo del token
    var circle = Node2D.new()
    circle.name = "TokenCircle"
    # El dibujo se hace en _draw del círculo
    var circle_script = GDScript.new()
    circle_script.source_code = """
extends Node2D
var color: Color = Color.WHITE
var radius: float = 18.0
func _draw():
    draw_circle(Vector2.ZERO, radius, color)
    draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color.BLACK, 2.0)
"""
    circle_script.reload()
    circle.set_script(circle_script)
    circle.set("color", player_color)
    circle.set("radius", RADIUS)
    add_child(circle)

    # Iniciales del personaje
    var initials = _get_initials(character_id)
    var lbl = Label.new()
    lbl.name = "InitialsLabel"
    lbl.text = initials
    lbl.add_theme_font_size_override("font_size", 11)
    lbl.add_theme_color_override("font_color", Color.WHITE)
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.size = Vector2(RADIUS * 2, RADIUS * 2)
    lbl.position = Vector2(-RADIUS, -RADIUS)
    add_child(lbl)

    # Burbuja de monedas
    var bubble_bg = ColorRect.new()
    bubble_bg.name = "BubbleBG"
    bubble_bg.color = Color("#333333cc")
    bubble_bg.size = Vector2(32, 16)
    bubble_bg.position = Vector2(-16, -RADIUS - 20)
    add_child(bubble_bg)

    var coin_lbl = Label.new()
    coin_lbl.name = "CoinLabel"
    coin_lbl.text = "10🪙"
    coin_lbl.add_theme_font_size_override("font_size", 9)
    coin_lbl.add_theme_color_override("font_color", Color("#ffd700"))
    coin_lbl.position = Vector2(-16, -RADIUS - 20)
    coin_lbl.size = Vector2(32, 16)
    coin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    add_child(coin_lbl)

func _connect_signals() -> void:
    GameEvents.player_token_move.connect(_on_move)
    GameEvents.player_coins_changed.connect(_on_coins_changed)

func _on_move(pid: int, target_square: int) -> void:
    if pid != player_id:
        return
    var target_pos = get_parent().get_parent() \
        .get_node("Board").get_square_position(target_square)
    _animate_to(target_pos)

func _animate_to(target: Vector2) -> void:
    var tween = create_tween()
    tween.set_ease(Tween.EASE_IN_OUT)
    tween.set_trans(Tween.TRANS_CUBIC)
    # Pequeño arco para que parezca que salta
    var mid = (global_position + target) / 2 + Vector2(0, -30)
    tween.tween_property(self, "global_position", mid, 0.15)
    tween.tween_property(self, "global_position", target, 0.15)

func _on_coins_changed(pid: int, new_amount: int) -> void:
    if pid != player_id:
        return
    $CoinLabel.text = "%d🪙" % new_amount

func _get_initials(char_id: String) -> String:
    match char_id:
        "mario":       return "MA"
        "peach":       return "PE"
        "luigi":       return "LU"
        "toad":        return "TO"
        "bowser":      return "BO"
        "yoshi":       return "YO"
        "donkey_kong": return "DK"
        "rosalina":    return "RO"
        "metal_mario": return "MM"
        "shy_guy":     return "SG"
        _:             return "??"
