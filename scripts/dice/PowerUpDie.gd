class_name PowerUpDie
extends Node2D

signal roll_completed(face_data: Dictionary)

var faces: Array = []               # cargado desde JSON
var current_face: Dictionary = {}
var is_rolling: bool = false

func _ready() -> void:
    _load_faces()
    if has_node("RollButton"):
        $RollButton.visible = false
    if has_node("FaceLabel"):
        $FaceLabel.visible = false
    if has_node("FaceIcon"):
        $FaceIcon.visible = false
    if has_node("DieSprite"):
        $DieSprite.visible = false

func _load_faces() -> void:
    var file = FileAccess.open(
        "res://resources/dice_data/powerup_faces.json",
        FileAccess.READ
    )
    if file == null:
        push_error("No se pudo abrir powerup_faces.json")
        return

    var json = JSON.new()
    json.parse(file.get_as_text())
    file.close()

    # Expandir según weight: monedas aparece 2 veces, el resto 1
    var raw_faces = json.data["faces"]
    for face in raw_faces:
        for i in face["weight"]:
            faces.append(face)

    # Verificamos que el dado tenga exactamente 6 caras
    assert(faces.size() == 6, "El dado de power-up debe tener 6 caras exactas")

func roll() -> void:
    if is_rolling:
        return
    is_rolling = true
    var anim = $DieSprite/AnimationPlayer
    if anim and anim.has_animation("rolling"):
        anim.play("rolling")
        await anim.animation_finished
    else:
        await get_tree().create_timer(0.35).timeout
    current_face = faces[randi() % faces.size()]
    _show_result()
    is_rolling = false
    roll_completed.emit(current_face)

func _show_result() -> void:
    $FaceLabel.text = current_face["label"]
    # Aquí después cargarás el ícono correspondiente
    $FaceIcon.texture = load("res://assets/dice/" + current_face["icon"] + ".png")
