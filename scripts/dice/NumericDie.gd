class_name NumericDie
extends Node2D

signal roll_completed(result: int)

const MIN_VALUE = 1
const MAX_VALUE = 6

var current_result: int = 0
var is_rolling: bool = false

# Texturas para cada cara (asignar en el Inspector)
@export var face_textures: Array[Texture2D] = []

func roll() -> void:
    if is_rolling:
        return
    is_rolling = true
    # Animación de rodando
    $DieSprite/AnimationPlayer.play("rolling")
    await $DieSprite/AnimationPlayer.animation_finished
    # Resultado real
    current_result = randi_range(MIN_VALUE, MAX_VALUE)
    _show_result()
    is_rolling = false
    roll_completed.emit(current_result)

func _show_result() -> void:
    $ResultLabel.text = str(current_result)
    if face_textures.size() >= MAX_VALUE:
        $DieSprite.texture = face_textures[current_result - 1]
