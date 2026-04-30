# scripts/dice/DiceDisplay.gd
class_name DiceDisplay
extends Node2D

var numeric_visual: Node
var powerup_visual: Node
var order_panel: Node
var title_label: Label

# ← estas son las que faltan:
var _numeric_result: int = 0
var _powerup_face: Dictionary = {}
var _rolls_done: int = 0

func _ready() -> void:
    _place_on_screen()
    get_viewport().size_changed.connect(_place_on_screen)
    # Buscar y castear correctamente
    var num_node = _find_node_by_name(self, "NumericDieVisual")
    var pow_node = _find_node_by_name(self, "PowerUpDieVisual")
    
    if num_node and num_node.get_script():
        numeric_visual = num_node
    else:
        push_error("NumericDieVisual no tiene script asignado")
        return
        
    if pow_node and pow_node.get_script():
        powerup_visual = pow_node
    else:
        push_error("PowerUpDieVisual no tiene script asignado")
        return

    # Asignar die_type usando set() para evitar el error de tipo
    numeric_visual.set("die_type", 0)   # 0 = NUMERIC
    powerup_visual.set("die_type", 1)   # 1 = POWERUP

    # Conectar señales
    GameEvents.dice_roll_started.connect(_on_roll_animation_start)
    
    if numeric_visual.has_signal("roll_visual_completed"):
        numeric_visual.roll_visual_completed.connect(
            _on_numeric_visual_done
        )
    if powerup_visual.has_signal("roll_visual_completed"):
        powerup_visual.roll_visual_completed.connect(
            _on_powerup_visual_done
        )

    order_panel = _find_node_by_name(self, "OrderPanel")
    title_label = _find_node_by_name(self, "TitleLabel")

    if order_panel:
        var move_btn = _find_node_by_name(order_panel, "MoveFirstButton")
        var power_btn = _find_node_by_name(order_panel, "PowerFirstButton")
        if move_btn:
            move_btn.pressed.connect(func():
                _on_order_chosen(0)
            )
        if power_btn:
            power_btn.pressed.connect(func():
                _on_order_chosen(1)
            )
        order_panel.visible = false

    _style_panel()
    visible = false

func _find_node_by_name(node: Node, target: String) -> Node:
    for child in node.get_children():
        if child.name == target:
            return child
        var found = _find_node_by_name(child, target)
        if found:
            return found
    return null

func _on_roll_animation_start(_player_id: int) -> void:
    visible = true
    if order_panel:
        order_panel.visible = false
    if title_label:
        title_label.text = "🎲 Lanzando dados..."
    
func start_roll_animation(
        numeric_result: int,
        powerup_face: Dictionary) -> void:

    _numeric_result = numeric_result
    _powerup_face = powerup_face
    _rolls_done = 0

    visible = true
    order_panel.visible = false
    title_label.text = "🎲 Lanzando dados..."

    # Slide-in del panel
    var anim = $AnimationPlayer
    if anim and anim.has_animation("slide_in"):
        anim.play("slide_in")

    # Lanzar ambas animaciones simultáneamente
    numeric_visual.play_roll_animation(numeric_result)
    powerup_visual.play_roll_animation(0, powerup_face)

func _on_numeric_visual_done() -> void:
    _rolls_done += 1
    _check_both_done()

func _on_powerup_visual_done() -> void:
    _rolls_done += 1
    _check_both_done()

func _check_both_done() -> void:
    if _rolls_done < 2:
        return
    # Ambos dados terminaron — mostrar selector de orden
    title_label.text = "¿Qué haces primero?"
    _show_order_selector()

func _show_order_selector() -> void:
    $Panel/OrderPanel/MoveFirstButton.text = \
        "🚗 Mover  (%d casillas)" % _numeric_result
    $Panel/OrderPanel/PowerFirstButton.text = \
        "✨ Power-Up  (%s)" % _powerup_face.get("label", "")

    order_panel.visible = true

func _on_order_chosen(order: int) -> void:
    order_panel.visible = false
    title_label.text = ""
    visible = false
    # Notificar al DiceSystem
    GameEvents.dice_order_chosen.emit(order)


func _place_on_screen() -> void:
    var vp = get_viewport_rect().size
    position = Vector2(vp.x - 340, 16)

func _style_panel() -> void:
    var panel = _find_node_by_name(self, "Panel")
    if panel == null or not (panel is Control):
        return

    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.position = Vector2.ZERO
    panel.size = Vector2(340, 260)
    panel.custom_minimum_size = Vector2(340, 260)

    var title = _find_node_by_name(panel, "TitleLabel")
    if title and title is Control:
        title.position = Vector2(12, 8)
        title.size = Vector2(316, 24)

    var num = _find_node_by_name(panel, "NumericDieVisual")
    var pow = _find_node_by_name(panel, "PowerUpDieVisual")
    if num:
        num.position = Vector2(88, 82)
    if pow:
        pow.position = Vector2(228, 82)

    var row = _find_node_by_name(panel, "DiceRow")
    if row and row is Control:
        row.position = Vector2(30, 42)
        row.size = Vector2(280, 120)
    var num_container = _find_node_by_name(panel, "NumericContainer")
    var pow_container = _find_node_by_name(panel, "PowerUpContainer")
    if num_container and num_container is Control:
        num_container.position = Vector2(24, 16)
        num_container.size = Vector2(120, 92)
    if pow_container and pow_container is Control:
        pow_container.position = Vector2(164, 16)
        pow_container.size = Vector2(120, 92)

    var order = _find_node_by_name(panel, "OrderPanel")
    if order and order is Control:
        order.position = Vector2(12, 168)
        order.size = Vector2(316, 88)

    var move_btn = _find_node_by_name(panel, "MoveFirstButton")
    var power_btn = _find_node_by_name(panel, "PowerFirstButton")
    if move_btn and move_btn is Control:
        move_btn.size = Vector2(316, 34)
    if power_btn and power_btn is Control:
        power_btn.size = Vector2(316, 34)
