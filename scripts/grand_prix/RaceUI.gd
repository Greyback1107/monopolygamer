class_name RaceUI
extends CanvasLayer

# Al inicio de RaceUI.gd, agrega:
var _grand_prix: Node


var current_card: Dictionary = {}
var triggering_player: int = -1
var player_decisions: Dictionary = {}   # player_id → true/false (joined)

func _ready() -> void:
    _grand_prix = get_node_or_null("/root/GameScene/GrandPrixSystem")
    if not _grand_prix:
        push_error("RaceUI: No se encontró GrandPrixSystem")
        return
    GameEvents.show_race_ui.connect(_on_show_race)
    $RacePanel/RollAllButton.pressed.connect(_on_roll_all)
    $RacePanel/ContinueButton.pressed.connect(_on_continue)
    $RacePanel/ContinueButton.visible = false
    visible = false

func _on_show_race(trigger_player_id: int, card: Dictionary) -> void:
    triggering_player = trigger_player_id
    current_card = card
    player_decisions = {}
    _populate_card(card)
    _populate_participants()
    visible = true

    # Carrera final: todos participan automáticamente
    if card.get("is_final", false):
        $RacePanel/FinalRaceLabel.visible = true
        $RacePanel/TitleLabel.text = "¡ÚLTIMA CARRERA — RAINBOW ROAD!"
        _auto_join_all()
    else:
        $RacePanel/FinalRaceLabel.visible = false
        $RacePanel/TitleLabel.text = "¡GRAN PREMIO!"

func _populate_card(card: Dictionary) -> void:
    # Actualiza la GrandPrixCard embebida con los datos de esta carrera
    var gpc = $RacePanel/GrandPrixCard
    gpc.setup(card)
    gpc.flip_reveal()

func _populate_participants() -> void:
    # Aquí instancias una fila por jugador activo
    # (conectado al PlayerManager que veremos en el Paso 5 — UI)
    pass

func _auto_join_all() -> void:
    for pid in GameEvents.get_active_player_ids():
        player_decisions[pid] = true
    $RacePanel/RollAllButton.disabled = false

# En RaceUI.gd — manejar el premio especial de Rainbow Road
func _on_steal_card_rematch(winner_id: int) -> void:
    # 1. Mostrar UI para que el ganador elija qué carta robar
    # 2. Iniciar una nueva carrera inmediata por esa carta
    # 3. Todos los jugadores participan, sin costo
    GameEvents.show_card_picker.emit(winner_id)
    
func _on_player_join(player_id: int) -> void:
    var joined = _grand_prix.player_joins(
        player_id,
        PlayerManager.get_player(player_id).coins
    )
    player_decisions[player_id] = joined
    _check_all_decided()

func _on_player_skip(player_id: int) -> void:
    _grand_prix.player_skips(player_id)
    player_decisions[player_id] = false
    _check_all_decided()

func _check_all_decided() -> void:
    # Habilitar botón de tirar cuando todos decidieron
    if player_decisions.size() == GameEvents.get_active_player_ids().size():
        $RacePanel/RollAllButton.disabled = false

func _on_roll_all() -> void:
    _grand_prix.roll_for_all_participants()
    _grand_prix.race_completed.connect(_on_race_resolved, CONNECT_ONE_SHOT)

func _on_race_resolved(results: Array) -> void:
    _show_results(results)
    $RacePanel/ContinueButton.visible = true
    $RacePanel/RollAllButton.visible = false

func _show_results(results: Array) -> void:
    var medals = ["🥇", "🥈", "🥉", "4️⃣"]
    for i in results.size():
        var r = results[i]
        var label_text = "%s  Jugador %d — Tiró: %d  (+%d monedas, +%d pts)" % [
            medals[i],
            r["player_id"] + 1,
            r["roll"],
            r["coins_won"],
            r["points_won"]
        ]
        # Actualizar etiquetas en RankLabel_1..4
        $RacePanel/ResultsPanel.get_child(i).text = label_text
    $RacePanel/ResultsPanel.visible = true

func _on_continue() -> void:
    visible = false
    GameEvents.race_ui_closed.emit()
