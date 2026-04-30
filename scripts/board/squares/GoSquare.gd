class_name GoSquare
extends Square

const PASS_GO_COINS = 2

func _execute_landing_effect(player) -> void:
    # Dar monedas siempre que pase o caiga
    player.add_coins(PASS_GO_COINS)
    # Disparar carrera de Gran Premio
    GameEvents.trigger_grand_prix.emit(player)
