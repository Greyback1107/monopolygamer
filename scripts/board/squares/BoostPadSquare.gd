class_name BoostPadSquare
extends Square

func _execute_landing_effect(player) -> void:
    # El jugador tira el dado numérico de nuevo y avanza
    GameEvents.request_bonus_roll.emit(player, "numeric")
