class_name CoinToken
extends Node2D

@export var amount: int = 1

func _ready() -> void:
    $AmountLabel.text = "x%d" % amount if amount > 1 else ""
    $AnimationPlayer.play("appear")

func collect() -> void:
    $AnimationPlayer.play("collect")
    await $AnimationPlayer.animation_finished
    queue_free()
