class_name PropertySystem
extends Node

# Tiempo en segundos que tiene el dueño para cobrar renta
const RENT_CLAIM_WINDOW = 8.0

# Estado de renta pendiente
var _pending_rent: Dictionary = {}
# {
#   "payer_id": int,
#   "owner_id": int,
#   "amount": int,
#   "timer": float,
#   "claimed": bool
# }

var _rent_timer: float = 0.0
var _rent_active: bool = false

func _ready() -> void:
    GameEvents.property_available.connect(_on_property_available)
    GameEvents.rent_due.connect(_on_rent_due)
    GameEvents.effect_buy_from_player.connect(_on_buy_from_player)
    GameEvents.effect_swap_properties.connect(_on_swap_properties)
    GameEvents.effect_auction_property.connect(_on_auction_any)
    GameEvents.properties_swapped.connect(_on_execute_swap)
    GameEvents.property_bought_from_player.connect(_on_execute_buy_from_player)
    GameEvents.auction_started.connect(_on_auction_started)
    GameEvents.turn_started.connect(_on_turn_started)

# ─────────────────────────────────────────
# PROCESO — temporizador de renta
# ─────────────────────────────────────────
func _process(delta: float) -> void:
    if not _rent_active:
        return

    _rent_timer -= delta
    GameEvents.rent_timer_updated.emit(_rent_timer, RENT_CLAIM_WINDOW)

    if _rent_timer <= 0.0:
        _expire_rent()

# ─────────────────────────────────────────
# COMPRA DE PROPIEDAD
# ─────────────────────────────────────────
func _on_property_available(player_id: int, square) -> void:
    # Mostrar panel de compra al jugador
    GameEvents.show_buy_panel.emit(player_id, square)

func player_buys_property(player_id: int, square) -> void:
    var player = PlayerManager.get_player(player_id)
    if not player.can_afford(square.data.buy_cost):
        # No puede pagar — forzar subasta
        _start_auction(square, "bank")
        return

    player.pay_coins(square.data.buy_cost)
    _assign_property(player_id, square)
    GameEvents.property_purchased.emit(player_id, square.square_id)
    GameEvents.hide_buy_panel.emit()

func player_declines_property(square) -> void:
    # El jugador no quiere comprar — va a subasta
    GameEvents.hide_buy_panel.emit()
    _start_auction(square, "bank")

func _assign_property(player_id: int, square) -> void:
    square.owner_player = PlayerManager.get_player(player_id)
    PlayerManager.get_player(player_id).add_property(square.square_id)
    # Actualizar puntos de propiedad en ScoringSystem
    var pts = PlayerManager.get_property_points(player_id)
    ScoringSystem.update_property_points(player_id, pts)

# ─────────────────────────────────────────
# RENTA
# ─────────────────────────────────────────
func _on_rent_due(payer_id: int, owner_id: int, amount: int) -> void:
    _pending_rent = {
        "payer_id": payer_id,
        "owner_id": owner_id,
        "amount": amount,
        "claimed": false
    }
    _rent_timer = RENT_CLAIM_WINDOW
    _rent_active = true

    # Mostrar panel al dueño para que cobre
    GameEvents.show_rent_panel.emit(owner_id, payer_id, amount, RENT_CLAIM_WINDOW)

func owner_claims_rent() -> void:
    if not _rent_active or _pending_rent.is_empty():
        return
    if _pending_rent["claimed"]:
        return

    _execute_rent_payment()

func _execute_rent_payment() -> void:
    var payer = PlayerManager.get_player(_pending_rent["payer_id"])
    var owner = PlayerManager.get_player(_pending_rent["owner_id"])
    var amount = _pending_rent["amount"]

    var actual = payer.pay_coins(amount)
    owner.add_coins(actual)

    _pending_rent["claimed"] = true
    _rent_active = false
    _rent_timer = 0.0

    GameEvents.rent_paid.emit(
        _pending_rent["payer_id"],
        _pending_rent["owner_id"],
        actual
    )
    GameEvents.hide_rent_panel.emit()

func _expire_rent() -> void:
    # El tiempo se agotó — el dueño pierde el cobro
    _rent_active = false
    _rent_timer = 0.0
    GameEvents.rent_expired.emit(
        _pending_rent["owner_id"],
        _pending_rent["amount"]
    )
    GameEvents.hide_rent_panel.emit()
    _pending_rent = {}

func _on_turn_started(_player_id: int) -> void:
    # Si hay renta sin cobrar cuando empieza el siguiente turno → expira
    if _rent_active and not _pending_rent.get("claimed", true):
        _expire_rent()

# ─────────────────────────────────────────
# SUBASTA
# ─────────────────────────────────────────
func _start_auction(square, payment_to: String) -> void:
    GameEvents.show_auction_panel.emit(square, payment_to)

func _on_auction_any(player_id: int, payment_to: String) -> void:
    # Premio Grand Prix — el ganador elige cualquier propiedad para subastar
    InteractionUI.request_property_pick(
        player_id,
        "Elegir propiedad para subastar",
        {"any": true},
        func(square_id):
            var square = BoardManager.get_square(square_id)
            _start_auction(square, payment_to)
    )

func _on_auction_started(square_id: int, payment_to: String) -> void:
    var square = BoardManager.get_square(square_id)
    if square:
        _start_auction(square, payment_to)

func execute_auction_result(
        winner_id: int,
        square,
        bid_amount: int,
        payment_to: String) -> void:

    var winner = PlayerManager.get_player(winner_id)
    winner.pay_coins(bid_amount)

    if payment_to == "bank":
        # El dinero va al banco — simplemente desaparece
        pass
    else:
        # El dinero va al dueño anterior
        var prev_owner = square.owner_player
        if prev_owner:
            prev_owner.remove_property(square.square_id)
            prev_owner.add_coins(bid_amount)

    _assign_property(winner_id, square)
    GameEvents.auction_completed.emit(winner_id, square.square_id, bid_amount)
    GameEvents.hide_auction_panel.emit()

# ─────────────────────────────────────────
# TRANSFERENCIAS — premios Grand Prix
# ─────────────────────────────────────────
func _on_buy_from_player(buyer_id: int) -> void:
    # Royal Raceway 1°: comprar propiedad de otro jugador al precio del tablero
    InteractionUI.request_property_pick(
        buyer_id,
        "Elegir propiedad para comprar",
        {"owned_by_others": true},
        func(square_id): _execute_buy_from_player(buyer_id, square_id)
    )

func _on_execute_buy_from_player(buyer_id: int, square_id: int) -> void:
    _execute_buy_from_player(buyer_id, square_id)

func _execute_buy_from_player(buyer_id: int, square_id: int) -> void:
    var square = BoardManager.get_square(square_id)
    if not square or not square.owner_player:
        return

    var buyer = PlayerManager.get_player(buyer_id)
    var prev_owner = square.owner_player
    var price = square.data.buy_cost

    if not buyer.can_afford(price):
        GameEvents.cant_afford_property.emit(buyer_id, price)
        return

    buyer.pay_coins(price)
    prev_owner.add_coins(price)
    prev_owner.remove_property(square_id)
    _assign_property(buyer_id, square)

    GameEvents.property_transferred.emit(
        buyer_id, prev_owner.player_id, square_id
    )

func _on_swap_properties(source_id: int, can_include_self: bool) -> void:
    # Serbet Land 1°: dos jugadores intercambian una propiedad cada uno
    InteractionUI.request_swap_pick(source_id, can_include_self)

func _on_execute_swap(
        _source_id: int,
        player_a: int,
        player_b: int) -> void:

    # Cada jugador elige qué propiedad suya dar
    InteractionUI.request_property_pick(
        player_a,
        "%s: elegir propiedad a intercambiar" % \
            PlayerManager.get_player_name(player_a),
        {"owned_by_self_id": player_a},
        func(sq_a):
            InteractionUI.request_property_pick(
                player_b,
                "%s: elegir propiedad a intercambiar" % \
                    PlayerManager.get_player_name(player_b),
                {"owned_by_self_id": player_b},
                func(sq_b):
                    _execute_property_swap(player_a, sq_a, player_b, sq_b)
            )
    )

func _execute_property_swap(
        player_a: int, square_id_a: int,
        player_b: int, square_id_b: int) -> void:

    var sq_a = BoardManager.get_square(square_id_a)
    var sq_b = BoardManager.get_square(square_id_b)
    var pa = PlayerManager.get_player(player_a)
    var pb = PlayerManager.get_player(player_b)

    # Intercambiar dueños
    pa.remove_property(square_id_a)
    pb.remove_property(square_id_b)
    pa.add_property(square_id_b)
    pb.add_property(square_id_a)
    sq_a.owner_player = pb
    sq_b.owner_player = pa

    # Actualizar puntos de ambos
    ScoringSystem.update_property_points(
        player_a, PlayerManager.get_property_points(player_a)
    )
    ScoringSystem.update_property_points(
        player_b, PlayerManager.get_property_points(player_b)
    )

    GameEvents.property_swap_completed.emit(
        player_a, square_id_a,
        player_b, square_id_b
    )
