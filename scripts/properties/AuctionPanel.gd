class_name AuctionPanel
extends PanelContainer

var _square = null
var _payment_to: String = "bank"
var _current_bid: int = 0
var _current_leader: int = -1
var _passed_players: Array = []
var _active_bidders: Array = []

func _ready() -> void:
    GameEvents.show_auction_panel.connect(_on_show)
    GameEvents.hide_auction_panel.connect(func(): visible = false)
    visible = false

func _on_show(square, payment_to: String) -> void:
    _square = square
    _payment_to = payment_to
    _current_bid = 0
    _current_leader = -1
    _passed_players = []
    _active_bidders = PlayerManager.get_active_player_ids().duplicate()

    # Construir filas de jugadores
    _build_bidder_rows()

    var d = square.data
    var bm = get_node_or_null("/root/GameScene/BoardManager")
    if bm:
        $PropertyInfoContainer/ColorBar.color = bm.get_group_color(d.color_group)
    $PropertyInfoContainer/PropertyNameLabel.text = d.square_name
    $PropertyInfoContainer/RentInfoLabel.text = \
        "Renta: %d  |  Par: %d" % [d.rent_base, d.rent_double]
    $CurrentBidLabel.text = "Oferta inicial: 1 moneda"
    $AuctionStatusLabel.text = "La subasta comienza — mínimo 1 moneda"

    visible = true

func _build_bidder_rows() -> void:
    for child in $BiddersContainer.get_children():
        child.queue_free()

    for pid in _active_bidders:
        var row = HBoxContainer.new()
        var name_lbl = Label.new()
        var coins_lbl = Label.new()
        var bid_btn = Button.new()
        var pass_btn = Button.new()

        name_lbl.text = PlayerManager.get_player_name(pid)
        coins_lbl.text = "%d 🪙" % PlayerManager.get_player(pid).coins
        bid_btn.text = "Ofertar"
        pass_btn.text = "Pasar"

        bid_btn.pressed.connect(func(): _on_player_bids(pid))
        pass_btn.pressed.connect(func(): _on_player_passes(pid))

        row.add_child(name_lbl)
        row.add_child(coins_lbl)
        row.add_child(bid_btn)
        row.add_child(pass_btn)
        row.name = "Row_%d" % pid
        $BiddersContainer.add_child(row)

func _on_player_bids(player_id: int) -> void:
    var new_bid = _current_bid + 1
    var player = PlayerManager.get_player(player_id)

    if not player.can_afford(new_bid):
        return

    _current_bid = new_bid
    _current_leader = player_id

    $CurrentBidLabel.text = "Oferta actual: %d monedas" % _current_bid
    $CurrentLeaderLabel.text = "Liderando: %s" % \
        PlayerManager.get_player_name(player_id)

    # Deshabilitar botón del lider actual
    # (no puede superar su propia oferta)
    _refresh_bid_buttons()

func _on_player_passes(player_id: int) -> void:
    _passed_players.append(player_id)
    # Deshabilitar fila del jugador que pasó
    var row = $BiddersContainer.get_node("Row_%d" % player_id)
    if row:
        for child in row.get_children():
            if child is Button:
                child.disabled = true

    # Verificar si la subasta terminó
    var still_active = _active_bidders.filter(func(pid):
        return not _passed_players.has(pid)
    )

    if still_active.size() <= 1:
        _conclude_auction()

func _conclude_auction() -> void:
    if _current_leader == -1:
        # Nadie ofertó — la propiedad queda sin dueño
        $AuctionStatusLabel.text = "Sin ofertas — propiedad no vendida"
        await get_tree().create_timer(1.5).timeout
        GameEvents.hide_auction_panel.emit()
        return

    $AuctionStatusLabel.text = "%s gana por %d monedas" % [
        PlayerManager.get_player_name(_current_leader),
        _current_bid
    ]
    await get_tree().create_timer(1.5).timeout
    var ps = get_node_or_null("/root/GameScene/PropertySystem")
    if ps:
        ps.execute_auction_result(
            _current_leader,
            _square,
            _current_bid,
            _payment_to
        )

func _refresh_bid_buttons() -> void:
    for pid in _active_bidders:
        var row = $BiddersContainer.get_node_or_null("Row_%d" % pid)
        if not row:
            continue
        var bid_btn = row.get_node("Button")  # ajustar nombre si difiere
        var player = PlayerManager.get_player(pid)
        # El líder actual no puede ofertar hasta que alguien más suba
        bid_btn.disabled = (pid == _current_leader) or \
            not player.can_afford(_current_bid + 1)
