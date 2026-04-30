# scripts/board/BoardVisual.gd
extends Node2D

const BOARD_SIZE = 524.0
const SQUARES_PER_SIDE = 7
const CORNER_SIZE = Vector2(80, 80)
const NORMAL_SIZE = Vector2(52, 80)

const TYPE_COLORS = {
    "GO":           Color("#f0e68c"),
    "PROPERTY":     Color("#f5f5f5"),
    "BOOST_PAD":    Color("#90ee90"),
    "ITEM_BOX":     Color("#87ceeb"),
    "SUPER_STAR":   Color("#ffd700"),
    "JAIL_VISIT":   Color("#d3d3d3"),
    "GO_TO_JAIL":   Color("#ff6b6b"),
    "FREE_PARKING": Color("#98fb98"),
}

const GROUP_COLORS = {
    "brown":      Color("#8B4513"),
    "light_blue": Color("#ADD8E6"),
    "maroon":     Color("#800000"),
    "orange":     Color("#FFA500"),
    "red":        Color("#FF0000"),
    "yellow":     Color("#FFD700"),
    "green":      Color("#228B22"),
    "dark_blue":  Color("#00008B"),
}

var square_positions: Array = []
var square_sizes: Array = []

func _ready() -> void:
    _calculate_layout()
    _draw_board()

func _calculate_layout() -> void:
    square_positions.clear()
    square_sizes.clear()

    var half = BOARD_SIZE / 2.0
    var cs = CORNER_SIZE
    var ns = NORMAL_SIZE

    # LADO INFERIOR (idx 0-8)
    square_positions.append(Vector2(half - cs.x/2, half - cs.y/2))
    square_sizes.append(cs)
    for i in SQUARES_PER_SIDE:
        var x = half - cs.x - ns.x * (i + 0.5)
        square_positions.append(Vector2(x, half - ns.y/2))
        square_sizes.append(ns)
    square_positions.append(Vector2(-half + cs.x/2, half - cs.y/2))
    square_sizes.append(cs)

    # LADO IZQUIERDO (idx 9-16)
    for i in SQUARES_PER_SIDE:
        var y = half - cs.y - ns.x * (i + 0.5)
        square_positions.append(Vector2(-half + ns.y/2, y))
        square_sizes.append(Vector2(ns.y, ns.x))
    square_positions.append(Vector2(-half + cs.x/2, -half + cs.y/2))
    square_sizes.append(cs)

    # LADO SUPERIOR (idx 17-24)
    for i in SQUARES_PER_SIDE:
        var x = -half + cs.x + ns.x * (i + 0.5)
        square_positions.append(Vector2(x, -half + ns.y/2))
        square_sizes.append(ns)
    square_positions.append(Vector2(half - cs.x/2, -half + cs.y/2))
    square_sizes.append(cs)

    # LADO DERECHO (idx 25-31)
    for i in SQUARES_PER_SIDE:
        var y = -half + cs.y + ns.x * (i + 0.5)
        square_positions.append(Vector2(half - ns.y/2, y))
        square_sizes.append(Vector2(ns.y, ns.x))

func _draw_board() -> void:
    var border = ColorRect.new()
    border.color = Color("#1a3a2a")
    border.size = Vector2(BOARD_SIZE + 8, BOARD_SIZE + 8)
    border.position = Vector2(-BOARD_SIZE/2 - 4, -BOARD_SIZE/2 - 4)
    border.z_index = -1
    add_child(border)

    var bg = ColorRect.new()
    bg.color = Color("#35654d")
    bg.size = Vector2(BOARD_SIZE, BOARD_SIZE)
    bg.position = Vector2(-BOARD_SIZE/2, -BOARD_SIZE/2)
    add_child(bg)

    var inner_size = BOARD_SIZE - CORNER_SIZE.x * 2 - NORMAL_SIZE.y * 2
    var interior = ColorRect.new()
    interior.color = Color("#2d5a3d")
    interior.size = Vector2(inner_size, inner_size)
    interior.position = Vector2(-inner_size/2, -inner_size/2)
    add_child(interior)

    var logo = Label.new()
    logo.text = "MONOPOLY\nGAMER\nMARIO KART"
    logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    logo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    logo.add_theme_font_size_override("font_size", 26)
    logo.add_theme_color_override("font_color", Color.WHITE)
    logo.size = Vector2(200, 150)
    logo.position = Vector2(-100, -75)
    add_child(logo)

    _load_board_data_and_draw()

func _load_board_data_and_draw() -> void:
    var file = FileAccess.open(
        "res://resources/board_data/board_layout.json",
        FileAccess.READ
    )
    if file == null:
        push_error("BoardVisual: No se pudo abrir board_layout.json")
        return
    var json = JSON.new()
    json.parse(file.get_as_text())
    file.close()
    for sq_data in json.data["squares"]:
        var idx = sq_data["id"]
        if idx < square_positions.size():
            _draw_square(idx, sq_data)

func _draw_square(idx: int, data: Dictionary) -> void:
    var pos = square_positions[idx]
    var size = square_sizes[idx]
    var sq_type = data.get("type", "PROPERTY")

    var container = Node2D.new()
    container.position = pos
    container.name = "Square_%02d" % idx
    add_child(container)

    var bg = ColorRect.new()
    bg.color = TYPE_COLORS.get(sq_type, Color.WHITE)
    bg.size = size
    bg.position = -size / 2
    container.add_child(bg)

    container.add_child(_make_border(size))

    if sq_type == "PROPERTY" and data.has("color_group"):
        _draw_color_bar(container, size, data["color_group"], idx)

    if sq_type in ["BOOST_PAD", "ITEM_BOX", "SUPER_STAR", "GO_TO_JAIL", "GO"]:
        _draw_icon(container, size, sq_type)

    _draw_label(container, size, data.get("name", ""), sq_type, idx)

    if sq_type == "PROPERTY" and data.has("buy_cost"):
        var cl = Label.new()
        cl.text = str(int(data["buy_cost"]))
        cl.add_theme_font_size_override("font_size", 8)
        cl.add_theme_color_override("font_color", Color("#333333"))
        cl.position = Vector2(size.x/2 - 14, size.y/2 - 14)
        
        if idx >= 9 and idx <= 15:
            cl.position = Vector2(-20, -25)
            cl.rotation_degrees = 90
        elif idx >= 17 and idx <= 23:
            cl.position = Vector2(25, -22)
            cl.rotation_degrees = 180
        elif idx >= 25 and idx <= 31:
            cl.position = Vector2(25, -22)
            cl.rotation_degrees = 270
        else:
            var top_offset = 12.0 if sq_type == "PROPERTY" else 4.0
            cl.size = Vector2(size.x * 0.9, size.y * 0.75)
            cl.position = Vector2(-size.x * 0.9/2, -size.y/2 + top_offset)
            
        container.add_child(cl)

func _draw_label(
        parent: Node2D,
        size: Vector2,
        sq_name: String,
        sq_type: String,
        idx: int) -> void:

    if sq_type not in ["PROPERTY", "JAIL_VISIT", "FREE_PARKING",
                        "GO_TO_JAIL", "GO"]:
        return

    var label = Label.new()
    label.text = _short_name(sq_name)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 7)
    label.add_theme_color_override("font_color", Color("#1a1a1a"))
    label.autowrap_mode = TextServer.AutowrapMode.AUTOWRAP_WORD

    if idx >= 9 and idx <= 15:
        # Lado izquierdo: size=(80,52), texto mira izquierda
        # El label rotado 90° necesita estar centrado en (0,0)
        # y su tamaño debe caber en 52px de alto y 80px de ancho
        label.size = Vector2(50, 35)
        label.position = Vector2(25, -22)
        label.rotation_degrees = 90
    elif idx >= 17 and idx <= 23:
        # Lado superior: texto al revés
        var top_offset = 12.0 if sq_type == "PROPERTY" else 4.0
        label.size = Vector2(size.x * 0.9, size.y * 0.75)
        label.position = Vector2(23,30)
        label.rotation_degrees = 180
    elif idx >= 25 and idx <= 31:
        # Lado derecho: size=(80,52), texto mira derecha
        label.size = Vector2(50, 35)
        label.position = Vector2(-30, 27)
        label.rotation_degrees = -90
    else:
        # Inferior y esquinas
        var top_offset = 12.0 if sq_type == "PROPERTY" else 4.0
        label.size = Vector2(size.x * 0.9, size.y * 0.75)
        label.position = Vector2(-size.x * 0.9/2, -size.y/2 + top_offset)

    parent.add_child(label)

func _draw_color_bar(
        parent: Node2D,
        size: Vector2,
        color_group: String,
        idx: int) -> void:

    var bar = ColorRect.new()
    var t = 10.0
    bar.color = GROUP_COLORS.get(color_group, Color.GRAY)

    if idx >= 1 and idx <= 7:
        bar.size = Vector2(size.x, t)
        bar.position = Vector2(-size.x/2, -size.y/2)
    elif idx >= 9 and idx <= 15:
        bar.size = Vector2(t, size.y)
        bar.position = Vector2(size.x/2 - t, -size.y/2)
    elif idx >= 17 and idx <= 23:
        bar.size = Vector2(size.x, t)
        bar.position = Vector2(-size.x/2, size.y/2 - t)
    elif idx >= 25 and idx <= 31:
        bar.size = Vector2(t, size.y)
        bar.position = Vector2(-size.x/2, -size.y/2)

    parent.add_child(bar)

func _draw_icon(parent: Node2D, size: Vector2, sq_type: String) -> void:
    var icons = {
        "GO":         "▶",
        "BOOST_PAD":  "⚡",
        "ITEM_BOX":   "?",
        "SUPER_STAR": "★",
        "GO_TO_JAIL": "🚔",
    }
    var lbl = Label.new()
    lbl.text = icons.get(sq_type, "")
    lbl.add_theme_font_size_override("font_size", 20)
    lbl.add_theme_color_override("font_color", Color("#cc4400"))
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.size = size
    lbl.position = -size / 2
    parent.add_child(lbl)

func _make_border(size: Vector2) -> Node2D:
    var n = Node2D.new()
    n.set_script(load("res://scripts/board/SquareBorder.gd"))
    n.set_meta("size", size)
    return n

func _short_name(full_name: String) -> String:
    return full_name.replace(" ", "\n")

func get_square_position(square_index: int) -> Vector2:
    if square_index < 0 or square_index >= square_positions.size():
        return global_position
    return global_position + square_positions[square_index]
