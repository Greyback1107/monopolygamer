class_name ItemBoxSquare
extends Square

func _execute_landing_effect(player) -> void:
    # El jugador tira el dado numérico y recoge esas monedas
    GameEvents.request_bonus_roll.emit(player, "collect_coins")
