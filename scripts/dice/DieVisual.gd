class_name DieVisual
extends Node2D

# ─────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────
enum DieType { NUMERIC, POWERUP }

@export var die_type: DieType = DieType.NUMERIC
@export var die_size: float = 70.0

# Colores
const COLOR_BG_NUMERIC  = Color("#f5f5f0")
const COLOR_BG_POWERUP  = Color("#1a1a3e")
const COLOR_DOT         = Color("#1a1a1a")
const COLOR_BORDER      = Color("#333333")
const COLOR_GLOW        = Color("#ffd70088")

const POWERUP_COLORS = {
    "coins":       Color("#ffd700"),
    "green_shell": Color("#4cbb17"),
    "spiny_shell": Color("#4444cc"),
    "lightning":   Color("#ffee00"),
    "banana":      Color("#ffe135"),
}

const POWERUP_SYMBOLS = {
    "coins":       "🪙",
    "green_shell": "🐢",
    "spiny_shell": "💙",
    "lightning":   "⚡",
    "banana":      "🍌",
}

# ─────────────────────────────────────────
# ESTADO
# ─────────────────────────────────────────
var current_value: int = 1           # para dado numérico
var current_face: Dictionary = {}    # para dado power-up
var is_rolling: bool = false
var _shake_offset: Vector2 = Vector2.ZERO
var _shake_angle: float = 0.0
var _roll_tween: Tween = null
var _frame_timer: float = 0.0
var _frame_interval: float = 0.06   # segundos entre frames de animación
var _roll_duration: float = 1.2     # duración total del roll
var _elapsed: float = 0.0
var _fake_value: int = 1            # valor aleatorio durante la animación

signal roll_visual_completed()

# ─────────────────────────────────────────
# READY
# ─────────────────────────────────────────
var _die_face: Node2D

func _ready() -> void:
    # Buscar DieFace o crearlo si no existe
    _die_face = get_node_or_null("DieFace")
    if not _die_face:
        _die_face = Node2D.new()
        _die_face.name = "DieFace"
        add_child(_die_face)
    
    # Buscar ResultContainer o crearlo
    var result_container = get_node_or_null("ResultContainer")
    if not result_container:
        result_container = Node2D.new()
        result_container.name = "ResultContainer"
        add_child(result_container)
        var glow = ColorRect.new()
        glow.name = "GlowRect"
        glow.color = Color("#ffd70088")
        glow.size = Vector2(die_size, die_size)
        glow.position = Vector2(-die_size/2, -die_size/2)
        glow.modulate = Color(1, 1, 1, 0)
        result_container.add_child(glow)
    
    _draw_face(1)

# ─────────────────────────────────────────
# ANIMACIÓN DE TIRADA
# ─────────────────────────────────────────
func play_roll_animation(final_value, final_face: Dictionary = {}) -> void:
    if is_rolling:
        return
    is_rolling = true
    _elapsed = 0.0

    # Fase 1 — agitar el dado
    _start_shake()

    # Fase 2 — mostrar frames aleatorios rápido
    _start_frame_loop()

    # Fase 3 — mostrar resultado final después de _roll_duration
    await get_tree().create_timer(_roll_duration).timeout
    _stop_shake()

    if die_type == DieType.NUMERIC:
        current_value = final_value
        _draw_face(final_value)
    else:
        current_face = final_face
        _draw_powerup_face(final_face)

    # Efecto de destello al aterrizar
    _flash_result()
    is_rolling = false
    roll_visual_completed.emit()

func _process(delta: float) -> void:
    if not is_rolling:
        return

    _elapsed += delta

    # Actualizar shake
    _shake_offset = Vector2(
        randf_range(-3.0, 3.0),
        randf_range(-3.0, 3.0)
    )
    _shake_angle = randf_range(-0.15, 0.15)
    position = _shake_offset
    rotation = _shake_angle

    # Cambiar cara aleatoriamente durante el roll
    _frame_timer -= delta
    if _frame_timer <= 0.0:
        # Acelerar frames al inicio, desacelerar al final
        var progress = _elapsed / _roll_duration
        _frame_interval = lerp(0.04, 0.15, progress)
        _frame_timer = _frame_interval

        if die_type == DieType.NUMERIC:
            _draw_face(randi_range(1, 6))
        else:
            _draw_random_powerup_face()

func _start_shake() -> void:
    # Escalar el dado ligeramente antes del roll
    var tween = create_tween()
    tween.tween_property(self, "scale",
        Vector2(1.1, 1.1), 0.1)

func _stop_shake() -> void:
    position = Vector2.ZERO
    rotation = 0.0
    var tween = create_tween()
    tween.set_ease(Tween.EASE_OUT)
    tween.set_trans(Tween.TRANS_BOUNCE)
    tween.tween_property(self, "scale",
        Vector2(1.0, 1.0), 0.3)

func _start_frame_loop() -> void:
    _frame_timer = _frame_interval

func _flash_result() -> void:
    var glow = get_node_or_null("ResultContainer/GlowRect")
    if not glow:
        return
    var tween = create_tween()
    tween.tween_property(glow, "modulate", Color(1, 1, 1, 0.8), 0.1)
    tween.tween_property(glow, "modulate", Color(1, 1, 1, 0.0), 0.4)

# ─────────────────────────────────────────
# DIBUJO DEL DADO NUMÉRICO
# ─────────────────────────────────────────
func _draw_face(value: int) -> void:
    for child in _die_face.get_children():
        child.queue_free()

    # Fondo
    var bg = ColorRect.new()
    bg.color = COLOR_BG_NUMERIC
    bg.size = Vector2(die_size, die_size)
    bg.position = Vector2(-die_size/2, -die_size/2)
    _die_face.add_child(bg)

    # Borde
    var border = ColorRect.new()
    border.color = COLOR_BORDER
    border.size = Vector2(die_size, die_size)
    border.position = Vector2(-die_size/2, -die_size/2)
    _die_face.add_child(border)

    var inner = ColorRect.new()
    inner.color = COLOR_BG_NUMERIC
    inner.size = Vector2(die_size - 4, die_size - 4)
    inner.position = Vector2(-die_size/2 + 2, -die_size/2 + 2)
    _die_face.add_child(inner)

    # Puntos según valor
    var dot_positions = _get_dot_positions(value)
    for dot_pos in dot_positions:
        var dot = ColorRect.new()
        var dot_size = die_size * 0.18
        dot.color = COLOR_DOT
        dot.size = Vector2(dot_size, dot_size)
        dot.position = dot_pos - Vector2(dot_size/2, dot_size/2)
        _die_face.add_child(dot)

func _get_dot_positions(value: int) -> Array:
    var pad = die_size * 0.28
    match value:
        1: return [Vector2(0, 0)]
        2: return [Vector2(-pad, -pad), Vector2(pad, pad)]
        3: return [Vector2(-pad, -pad), Vector2(0, 0),
                   Vector2(pad, pad)]
        4: return [Vector2(-pad, -pad), Vector2(pad, -pad),
                   Vector2(-pad, pad), Vector2(pad, pad)]
        5: return [Vector2(-pad, -pad), Vector2(pad, -pad),
                   Vector2(0, 0),
                   Vector2(-pad, pad), Vector2(pad, pad)]
        6: return [Vector2(-pad, -pad), Vector2(pad, -pad),
                   Vector2(-pad, 0), Vector2(pad, 0),
                   Vector2(-pad, pad), Vector2(pad, pad)]
    return []

# ─────────────────────────────────────────
# DIBUJO DEL DADO POWER-UP
# ─────────────────────────────────────────
func _draw_powerup_face(face: Dictionary) -> void:
    for child in _die_face.get_children():
        child.queue_free()

    var face_id = face.get("id", "coins")
    var bg_color = POWERUP_COLORS.get(face_id, Color("#333366"))

    # Fondo
    var bg = ColorRect.new()
    bg.color = bg_color
    bg.size = Vector2(die_size, die_size)
    bg.position = Vector2(-die_size/2, -die_size/2)
    _die_face.add_child(bg)

    # Sprite del item
    var sprite_path = "res://assets/dice/%s.png" % face_id
    if ResourceLoader.exists(sprite_path):
        var sprite = TextureRect.new()
        sprite.texture = load(sprite_path)
        sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        sprite.size = Vector2(die_size * 0.7, die_size * 0.7)
        sprite.position = Vector2(-die_size * 0.35, -die_size * 0.45)
        sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _die_face.add_child(sprite)
    else:
        # Fallback al símbolo emoji
        var sym_lbl = Label.new()
        sym_lbl.text = POWERUP_SYMBOLS.get(face_id, "?")
        sym_lbl.add_theme_font_size_override("font_size", 28)
        sym_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sym_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        sym_lbl.size = Vector2(die_size, die_size * 0.65)
        sym_lbl.position = Vector2(-die_size/2, -die_size/2)
        _die_face.add_child(sym_lbl)

    # Nombre debajo
    var name_lbl = Label.new()
    name_lbl.text = face.get("label", "")
    name_lbl.add_theme_font_size_override("font_size", 8)
    name_lbl.add_theme_color_override("font_color", Color.WHITE)
    name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name_lbl.autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_WORD
    name_lbl.size = Vector2(die_size, die_size * 0.35)
    name_lbl.position = Vector2(-die_size/2, die_size * 0.15)
    _die_face.add_child(name_lbl)

func _draw_random_powerup_face() -> void:
    var face_ids = ["coins", "coins", "green_shell",
                    "spiny_shell", "lightning", "banana"]
    var random_id = face_ids[randi() % face_ids.size()]
    _draw_powerup_face({"id": random_id, "label": random_id})
