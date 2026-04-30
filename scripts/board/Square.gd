class_name Square
extends Node2D

# Tipos de casilla — enum central del juego
enum SquareType {
    GO,
    PROPERTY,
    BOOST_PAD,
    ITEM_BOX,
    SUPER_STAR,
    JAIL_VISIT,
    GO_TO_JAIL,
    FREE_PARKING,
    GRAND_PRIX    # casilla especial que activa carrera directamente
}

# Datos de esta casilla
@export var square_id: int = 0          # posición 0-39 en el tablero
@export var square_type: SquareType
@export var square_name: String = ""

# Estado en tiempo de juego
var has_banana: bool = false
var players_here: Array = []            # jugadores actualmente en esta casilla

# Señales — otros sistemas escuchan estas señales
signal player_landed(player, square)
signal player_left(player, square)
signal banana_placed(square)
signal banana_removed(square)

func _ready():
    $ClickArea.input_event.connect(_on_click)
    $BananaToken.visible = false

# Llamado por BoardManager cuando un jugador llega
func on_player_land(player) -> void:
    players_here.append(player)
    _update_token_positions()
    player_landed.emit(player, self)
    _execute_landing_effect(player)    # cada subclase sobreescribe esto

# Método virtual — las subclases lo implementan
func _execute_landing_effect(player) -> void:
    pass

func place_banana() -> void:
    has_banana = true
    $BananaToken.visible = true
    banana_placed.emit(self)

func remove_banana() -> void:
    has_banana = false
    $BananaToken.visible = false
    banana_removed.emit(self)

func _update_token_positions() -> void:
    # distribuye visualmente las fichas en los slots disponibles
    for i in players_here.size():
        if i < $TokenContainer.get_child_count():
            players_here[i].position = $TokenContainer.get_child(i).position

func _on_click(_viewport, event, _shape) -> void:
    if event is InputEventMouseButton and event.pressed:
        # emitir señal global para mostrar info de esta casilla en UI
        GameEvents.square_clicked.emit(self)
