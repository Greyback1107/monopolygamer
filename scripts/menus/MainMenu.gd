extends Control

func _ready() -> void:
    print("MainMenu cargado OK")
    
    # Buscar botones por tipo en todos los hijos
    # sin importar el nombre o path exacto
    var buttons = _find_all_buttons(self)
    print("Botones encontrados: ", buttons.size())
    
    # Asignar por orden: primero=NuevoJuego, segundo=Opciones, tercero=Salir
    if buttons.size() >= 1:
        buttons[0].pressed.connect(_on_new_game)
        print("Nuevo Juego conectado: ", buttons[0].name)
    if buttons.size() >= 2:
        buttons[1].pressed.connect(_on_options)
        print("Opciones conectado: ", buttons[1].name)
    if buttons.size() >= 3:
        buttons[2].pressed.connect(_on_quit)
        print("Salir conectado: ", buttons[2].name)

func _find_all_buttons(node: Node) -> Array:
    var result = []
    for child in node.get_children():
        if child is Button:
            result.append(child)
        result.append_array(_find_all_buttons(child))
    return result

func _on_new_game() -> void:
    print("-> Nuevo Juego presionado")
    GameConfig.reset()
    get_tree().change_scene_to_file(
        "res://scenes/menus/PlayerSetup.tscn"
    )

func _on_options() -> void:
    print("-> Opciones presionado")

func _on_quit() -> void:
    print("-> Salir presionado")
    get_tree().quit()
