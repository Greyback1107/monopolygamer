extends Node2D

func _draw() -> void:
    var size = get_meta("size") as Vector2
    draw_rect(
        Rect2(-size/2, size),
        Color("#333333"),
        false,
        1.0
    )
