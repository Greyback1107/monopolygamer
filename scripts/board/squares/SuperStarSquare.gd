class_name SuperStarSquare
extends Square

func _execute_landing_effect(player) -> void:
    # Activa la habilidad especial del personaje
    GameEvents.activate_superstar.emit(player)
