# scripts/ui/InteractionUI.gd
class_name InteractionUI
extends CanvasLayer

# Referencia a los pickers hijos
@onready var player_picker: PlayerPicker = $PlayerPicker
@onready var property_picker: PropertyPicker = $PropertyPicker
@onready var card_picker: CardPicker = $CardPicker

# Callback interno — se llama cuando el jugador elige
var _resolve_callback: Callable

func _ready() -> void:
    # Escuchar todas las señales que requieren una elección del jugador
    GameEvents.effect_target_any_drop.connect(
        func(pid, amt): request_player_pick(pid,
            "Elegir jugador para Concha Espinosa",
            func(target): GameEvents.coins_dropped.emit(target, amt)
        )
    )
    GameEvents.effect_steal_coins.connect(
        func(pid, _t, amt): request_player_pick(pid,
            "Elegir jugador para robar %d monedas" % amt,
            func(target): GameEvents.coins_stolen.emit(pid, target, amt)
        )
    )
    GameEvents.effect_buy_from_player.connect(
        func(pid): request_property_pick(pid,
            "Elegir propiedad para comprar",
            {"owned_by_others": true},
            func(prop): GameEvents.property_bought_from_player.emit(pid, prop)
        )
    )
    GameEvents.effect_swap_properties.connect(
        func(pid, can_self): request_swap_pick(pid, can_self)
    )
    GameEvents.effect_auction_property.connect(
        func(pid, pay_to): request_property_pick(pid,
            "Elegir propiedad para subastar",
            {"any": true},
            func(prop): GameEvents.auction_started.emit(prop, pay_to)
        )
    )
    GameEvents.effect_send_to_free_parking.connect(
        func(pid, target, skip_go, skip_coins):
            if target == "any":
                request_player_pick(pid,
                    "Enviar jugador a Parada Libre",
                    func(t): GameEvents.player_sent_to_free_parking.emit(
                        t, skip_go, skip_coins
                    )
                )
    )
    GameEvents.effect_send_to_jail.connect(
        func(pid, target):
            if target == "any":
                request_player_pick(pid,
                    "Enviar jugador a la Cárcel",
                    func(t): GameEvents.player_sent_to_jail.emit(t)
                )
    )
    GameEvents.effect_steal_card_rematch.connect(
        func(pid, all_participate): request_card_pick(pid,
            "Elegir carta de Gran Premio para rematchar",
            func(card): GameEvents.rematch_started.emit(pid, card, all_participate)
        )
    )
    GameEvents.effect_swap_position.connect(
        func(pid): request_player_pick(pid,
            "Elegir jugador para intercambiar posición",
            func(target): GameEvents.positions_swapped.emit(pid, target)
        )
    )

# ─────────────────────────────────────────
# API PÚBLICA — los sistemas llaman estos métodos
# ─────────────────────────────────────────
func request_player_pick(
        source_player: int,
        title: String,
        on_picked: Callable) -> void:
    _resolve_callback = on_picked
    player_picker.show_picker(source_player, title)
    player_picker.player_chosen.connect(_on_chosen.bind(player_picker),
        CONNECT_ONE_SHOT)

func request_property_pick(
        source_player: int,
        title: String,
        filter: Dictionary,
        on_picked: Callable) -> void:
    _resolve_callback = on_picked
    property_picker.show_picker(source_player, title, filter)
    property_picker.property_chosen.connect(_on_chosen.bind(property_picker),
        CONNECT_ONE_SHOT)

func request_card_pick(
        source_player: int,
        title: String,
        on_picked: Callable) -> void:
    _resolve_callback = on_picked
    card_picker.show_picker(source_player, title)
    card_picker.card_chosen.connect(_on_chosen.bind(card_picker),
        CONNECT_ONE_SHOT)

func request_swap_pick(source_player: int, can_include_self: bool) -> void:
    # Primero elige jugador A, luego jugador B
    request_player_pick(source_player,
        "Intercambiar propiedades — Jugador A",
        func(player_a):
            request_player_pick(source_player,
                "Intercambiar propiedades — Jugador B",
                func(player_b):
                    GameEvents.properties_swapped.emit(
                        source_player, player_a, player_b
                    )
            )
    )

func _on_chosen(result, picker_node) -> void:
    picker_node.hide()
    _resolve_callback.call(result)
