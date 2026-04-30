class_name PlayerSlot
extends PanelContainer

signal character_selected(slot_id: int, character_id: String)
signal slot_toggled(slot_id: int, active: bool)

@export var slot_id: int = 0
@export var is_required: bool = true

var selected_character: String = ""
var is_active: bool = true
var all_characters: Array = []

@onready var _portrait: TextureRect = $MainHBox/LeftSide/Portrait
@onready var _number_label: Label = $MainHBox/LeftSide/SlotHeader/PlayerNumberLabel
@onready var _toggle: CheckButton = $MainHBox/LeftSide/SlotHeader/ActiveToggle
@onready var _color_rect: ColorRect = $MainHBox/LeftSide/SlotHeader/ColorRect
@onready var _name_input: LineEdit = $MainHBox/LeftSide/NameInput
@onready var _char_grid: GridContainer = $MainHBox/LeftSide/CharacterGrid
@onready var _activate_btn: Button = $MainHBox/LeftSide/ActivateBtn

@onready var _info_card: PanelContainer = $MainHBox/InfoCard
@onready var _char_name_lbl: Label = $MainHBox/InfoCard/InfoVBox/CharNameLabel
@onready var _superstar_lbl: Label = $MainHBox/InfoCard/InfoVBox/SuperStarRow/SuperStarLabel
@onready var _powerup_lbl: Label = $MainHBox/InfoCard/InfoVBox/PowerUpRow/PowerUpLabel
@onready var _superstar_icon: TextureRect = $MainHBox/InfoCard/InfoVBox/SuperStarRow/SuperStarIcon
@onready var _powerup_icon: TextureRect = $MainHBox/InfoCard/InfoVBox/PowerUpRow/PowerUpIcon

const CHAR_COLORS = {
    "mario":       Color("#e52521"),
    "peach":       Color("#f8a8c8"),
    "luigi":       Color("#4a9f3f"),
    "toad":        Color("#5b9bd5"),
    "bowser":      Color("#8b4513"),
    "yoshi":       Color("#4cbb17"),
    "donkey_kong": Color("#8b6914"),
    "rosalina":    Color("#6b8fcf"),
    "metal_mario": Color("#a8a9ad"),
    "shy_guy":     Color("#e8001c"),
}

func _ready() -> void:
    custom_minimum_size = Vector2(500, 200)
    _load_characters()
    _build_character_grid()
    _setup_slot()
    _reset_info_card()

func _load_characters() -> void:
    var file = FileAccess.open(
        "res://resources/characters/characters.json",
        FileAccess.READ
    )
    if file == null:
        push_error("PlayerSlot: No se pudo abrir characters.json")
        return
    var json = JSON.new()
    json.parse(file.get_as_text())
    file.close()
    all_characters = json.data["characters"]

func _build_character_grid() -> void:
    for child in _char_grid.get_children():
        child.queue_free()
    for char_data in all_characters:
        var btn = Button.new()
        btn.name = char_data["id"]
        btn.custom_minimum_size = Vector2(44, 44)
        btn.text = _get_initials(char_data["id"])
        btn.tooltip_text = char_data["name"]
        if char_data["availability"] == "expansion":
            var style = StyleBoxFlat.new()
            style.bg_color = Color("#1a1a2e")
            style.border_color = Color("#f5a623")
            style.set_border_width_all(2)
            style.set_corner_radius_all(4)
            btn.add_theme_stylebox_override("normal", style)
            btn.add_theme_color_override("font_color", Color.WHITE)
        var cid = char_data["id"]
        btn.pressed.connect(func(): _on_character_picked(cid))
        _char_grid.add_child(btn)

func _setup_slot() -> void:
    _number_label.text = "Jugador %d" % (slot_id + 1)
    var slot_colors = [
        Color("#e52521"), Color("#4a9f3f"),
        Color("#5b9bd5"), Color("#f5a623")
    ]
    _color_rect.color = slot_colors[slot_id]

    if is_required:
        _toggle.visible = false
        _activate_btn.visible = false
        is_active = true
        _name_input.mouse_filter = Control.MOUSE_FILTER_STOP
    else:
        _toggle.visible = false
        _activate_btn.visible = true
        _activate_btn.pressed.connect(_on_activate_pressed)
        is_active = false
        _set_slot_active(false)

func _reset_info_card() -> void:
    _char_name_lbl.text = "Sin personaje"
    _superstar_lbl.text = "—"
    _powerup_lbl.text = "—"
    # Cargar iconos placeholder
    var star_path = "res://assets/dice/star.png"
    if ResourceLoader.exists(star_path):
        _superstar_icon.texture = load(star_path)
    var dice_path = "res://assets/dice/powerup_default.png"
    if ResourceLoader.exists(dice_path):
        _powerup_icon.texture = load(dice_path)

func _on_activate_pressed() -> void:
    is_active = !is_active
    if not is_active:
        selected_character = ""
        for btn in _char_grid.get_children():
            if btn is Button:
                btn.button_pressed = false
        _reset_info_card()
    _set_slot_active(is_active)
    slot_toggled.emit(slot_id, is_active)

func _on_character_picked(character_id: String) -> void:
    selected_character = character_id

    for btn in _char_grid.get_children():
        if btn is Button:
            btn.button_pressed = (btn.name == character_id)

    var matches = all_characters.filter(
        func(c): return c["id"] == character_id
    )
    if matches.size() > 0:
        var cd = matches[0]

        # Portrait
        var img_path = "res://assets/portraits/%s.png" % character_id
        if ResourceLoader.exists(img_path):
            _portrait.texture = load(img_path)

        # Info card
        _char_name_lbl.text = cd["name"]

        var star_path = "res://assets/dice/star.png"
        if ResourceLoader.exists(star_path):
            _superstar_icon.texture = load(star_path)
            _superstar_icon.visible = true
        else:
            _superstar_icon.visible = false
        _superstar_lbl.text = cd["superstar_ability"]["description"]

        var trigger = cd["powerup_boost"]["triggers_on"]
        var icon_path = "res://assets/dice/%s.png" % trigger
        if ResourceLoader.exists(icon_path):
            _powerup_icon.texture = load(icon_path)
            _powerup_icon.visible = true
        else:
            _powerup_icon.visible = false
        _powerup_lbl.text = cd["powerup_boost"]["description"]

    character_selected.emit(slot_id, character_id)

func _set_slot_active(active: bool) -> void:
    # Name input
    _name_input.editable = active
    _name_input.mouse_filter = Control.MOUSE_FILTER_STOP if active \
        else Control.MOUSE_FILTER_IGNORE

    # Character grid — mostrar/ocultar y restaurar mouse filter
    _char_grid.visible = active
    _char_grid.mouse_filter = Control.MOUSE_FILTER_PASS if active \
        else Control.MOUSE_FILTER_IGNORE
    for btn in _char_grid.get_children():
        if btn is Button:
            btn.mouse_filter = Control.MOUSE_FILTER_STOP if active \
                else Control.MOUSE_FILTER_IGNORE

    # Portrait
    _portrait.visible = active
    _portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Info card
    _info_card.visible = active
    _info_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Botón activar — siempre clickeable
    _activate_btn.mouse_filter = Control.MOUSE_FILTER_STOP
    _activate_btn.text = "⏹ Desactivar" if active \
        else "▶ Activar Jugador"

    # Opacidad
    modulate = Color.WHITE if active else Color(1, 1, 1, 0.6)

func get_config() -> Dictionary:
    return {
        "id": slot_id,
        "name": _name_input.text if _name_input.text != "" \
            else "Jugador %d" % (slot_id + 1),
        "character_id": selected_character
    }

func is_ready_to_play() -> bool:
    return is_active and selected_character != ""

func mark_character_unavailable(character_id: String) -> void:
    var btn = _char_grid.get_node_or_null(character_id)
    if btn:
        btn.disabled = true

func mark_character_available(character_id: String) -> void:
    var btn = _char_grid.get_node_or_null(character_id)
    if btn:
        btn.disabled = false

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
