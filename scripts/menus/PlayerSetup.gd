extends Control

var slots: Array = []
var character_assignments: Dictionary = {}

@onready var start_button: Button = $VBoxContainer/BottomBar/StartButton
@onready var back_button: Button = $VBoxContainer/BottomBar/BackButton

func _ready() -> void:
    print("=== PlayerSetup _ready() ===")
    
    # Recoger los slots ya instanciados en la escena
    # SlotsRow1: índices 0 y 1
    # SlotsRow2: índices 2 y 3
    var row1 = $VBoxContainer/SlotsRow1
    var row2 = $VBoxContainer/SlotsRow2
    
    # Recoger solo los nodos PlayerSlot (ignorar InfoCards)
    for child in row1.get_children():
        if child is PlayerSlot:
            slots.append(child)
    for child in row2.get_children():
        if child is PlayerSlot:
            slots.append(child)
    
    # Asignar slot_id y is_required
    for i in slots.size():
        slots[i].slot_id = i
        slots[i].is_required = (i < 2)
        slots[i].character_selected.connect(_on_character_selected)
        slots[i].slot_toggled.connect(_on_slot_toggled)
        # Forzar reinicio con el slot_id correcto
        slots[i]._setup_slot()
    
    print("Slots encontrados: ", slots.size())
    
    # Ocultar el CharacterInfoPanel flotante — ya no se usa
    $CharacterInfoPanel.visible = false
    
    start_button.pressed.connect(_on_start)
    back_button.pressed.connect(_on_back)
    start_button.disabled = true
    _validate()

func _on_character_selected(slot_id: int, character_id: String) -> void:
    var previous = character_assignments.get(slot_id, "")
    if previous != "" and previous != character_id:
        _release_character(previous, slot_id)
    character_assignments[slot_id] = character_id
    for i in slots.size():
        if i != slot_id:
            slots[i].mark_character_unavailable(character_id)
            if character_assignments.get(i, "") == character_id:
                character_assignments.erase(i)
    _validate()

func _release_character(character_id: String, except_slot: int) -> void:
    var still_used = false
    for i in slots.size():
        if i != except_slot and \
                character_assignments.get(i, "") == character_id:
            still_used = true
            break
    if not still_used:
        for i in slots.size():
            if i != except_slot and slots[i].is_active:
                slots[i].mark_character_available(character_id)

func _on_slot_toggled(slot_id: int, active: bool) -> void:
    if not active:
        var char_id = character_assignments.get(slot_id, "")
        if char_id != "":
            character_assignments.erase(slot_id)
            _release_character(char_id, -1)
    _validate()

func _validate() -> void:
    var active_slots = slots.filter(func(s): return s.is_active)
    var ready_slots = slots.filter(func(s): return s.is_ready_to_play())
    if active_slots.size() < 2 or ready_slots.size() < active_slots.size():
        start_button.disabled = true
        return
    start_button.disabled = false

func _on_start() -> void:
    var ready_slots = slots.filter(func(s): return s.is_ready_to_play())
    if ready_slots.size() < 2:
        return
    GameConfig.player_configs = []
    for slot in slots:
        if slot.is_ready_to_play():
            GameConfig.player_configs.append(slot.get_config())
    GameConfig.player_count = GameConfig.player_configs.size()
    print("Iniciando con: ", GameConfig.player_configs)
    
    # Usar SceneTree directamente en vez de get_tree()
    var scene_tree = Engine.get_main_loop() as SceneTree
    if scene_tree:
        scene_tree.change_scene_to_file("res://scenes/GameScene.tscn")
    else:
        push_error("No se pudo obtener SceneTree")

func _on_back() -> void:
    get_tree().change_scene_to_file(
        "res://scenes/menus/MainMenu.tscn"
    )
