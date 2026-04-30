# Board.gd
var square_data_list: Array = []

# En Board.gd — agregar

# Posiciones en pantalla de cada casilla (se calculan al iniciar)
var square_positions: Array = []

func _ready() -> void:
    _calculate_square_positions()

func _calculate_square_positions() -> void:
    square_positions.clear()
    var container = $SquaresContainer
    for i in container.get_child_count():
        var square = container.get_child(i)
        # La posición global del centro de cada casilla
        square_positions.append(square.global_position)
    print("Board: posiciones calculadas para %d casillas" % square_positions.size())

func get_square_position(square_index: int) -> Vector2:
    if square_index >= 0 and square_index < square_positions.size():
        return square_positions[square_index]
    return Vector2.ZERO

func _ready():
    _load_board_data()

func _load_board_data() -> void:
    var file = FileAccess.open(
        "res://resources/board_data/board_layout.json", 
        FileAccess.READ
    )
    if file == null:
        push_error("No se pudo abrir board_layout.json")
        return
        
    var json = JSON.new()
    var error = json.parse(file.get_as_text())
    file.close()
    
    if error != OK:
        push_error("Error al parsear JSON: " + json.get_error_message())
        return
    
    square_data_list = json.data["squares"]
    print("Tablero cargado: ", square_data_list.size(), " casillas")
