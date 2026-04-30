class_name PropertySquare
extends Square

@export var data: SquareData    # el Resource con todos los datos

var owner_player = null         # null = sin dueño

func _execute_landing_effect(player) -> void:
    if owner_player == null:
        # ofrecerle comprar al jugador
        GameEvents.property_available.emit(player, self)
    elif owner_player != player:
        # cobrar renta
        var rent = data.rent_base
        if _owner_has_full_set():
            rent = data.rent_double
        GameEvents.rent_due.emit(player, owner_player, rent)

func _owner_has_full_set() -> bool:
    # consulta al BoardManager si el dueño tiene el par del mismo color
    return BoardManager.player_owns_full_set(owner_player, data.color_group)
