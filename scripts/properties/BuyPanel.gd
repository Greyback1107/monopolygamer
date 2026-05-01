class_name BuyPanel
extends PanelContainer

var _current_square = null
var _current_player_id: int = -1

func _ready() -> void:
    GameEvents.show_buy_panel.connect(_on_show)
    GameEvents.hide_buy_panel.connect(func(): visible = false)
    $BuyButton.pressed.connect(_on_buy)
    var auction_btn = get_node_or_null("AuctionButton")
    if auction_btn:
        auction_btn.pressed.connect(_on_auction)
    var aution_btn = get_node_or_null("AutionButton")
    if aution_btn:
        aution_btn.pressed.connect(_on_auction)
    visible = false

func _on_show(player_id: int, square) -> void:
    _current_square = square
    _current_player_id = player_id

    var d = square.data
    var bm = get_node_or_null("/root/GameScene/BoardManager")
    if bm:
        $ColorBar.color = bm.get_group_color(d.color_group)
    $PropertyNameLabel.text = d.square_name
    $CostLabel.text = "Precio: %d monedas" % d.buy_cost
    $RentInfoLabel.text = "Renta: %d  |  Par: %d" % [d.rent_base, d.rent_double]
    $PointsLabel.text = "Vale %d pts al final" % d.point_value

    var player = PlayerManager.get_player(player_id)
    $PlayerCoinsLabel.text = "Tus monedas: %d" % player.coins
    $BuyButton.disabled = not player.can_afford(d.buy_cost)

    visible = true

func _on_buy() -> void:
    var ps = get_node_or_null("/root/GameScene/PropertySystem")
    if ps:
        ps.player_buys_property(_current_player_id, _current_square)

func _on_auction() -> void:
    var ps = get_node_or_null("/root/GameScene/PropertySystem")
    if ps:
        ps.player_declines_property(_current_square)
