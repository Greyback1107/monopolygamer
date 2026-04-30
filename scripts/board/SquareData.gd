# scripts/board/SquareData.gd
class_name SquareData
extends Resource

@export var square_id: int
@export var square_name: String
@export var type: Square.SquareType

# Solo para propiedades
@export var color_group: String = ""    # "brown", "light_blue", etc.
@export var buy_cost: int = 0
@export var rent_base: int = 0
@export var rent_double: int = 0        # cuando el dueño tiene el par
@export var point_value: int = 0        # puntos al final del juego
