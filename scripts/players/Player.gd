class_name Player
extends RefCounted        # no es un nodo, es solo datos

# ─────────────────────────────────────────
# IDENTIDAD
# ─────────────────────────────────────────
var player_id: int
var player_name: String
var character_id: String
var color: Color

# ─────────────────────────────────────────
# ESTADO EN PARTIDA
# ─────────────────────────────────────────
var coins: int = 10
var square_index: int = 0       # posición actual en el tablero (0–39)
var owned_properties: Array = [] # Array de square_id (int)
var owned_grand_prix_cards: Array = []  # Array de card_data (Dictionary)

# ─────────────────────────────────────────
# CÁRCEL
# ─────────────────────────────────────────
var is_in_jail: bool = false
var jail_turns_remaining: int = 0
const JAIL_TURNS = 3             # turnos máximos en cárcel
const JAIL_SQUARE_INDEX = 18     # índice de la casilla cárcel en el tablero

# ─────────────────────────────────────────
# OPERACIONES DE MONEDAS
# ─────────────────────────────────────────
func add_coins(amount: int) -> void:
    coins = max(0, coins + amount)
    GameEvents.player_coins_changed.emit(player_id, coins)

func pay_coins(amount: int) -> int:
    # Devuelve cuánto pudo pagar realmente (puede no tener suficiente)
    var actual = min(coins, amount)
    coins -= actual
    GameEvents.player_coins_changed.emit(player_id, coins)
    return actual

func can_afford(amount: int) -> bool:
    return coins >= amount

# ─────────────────────────────────────────
# OPERACIONES DE PROPIEDADES
# ─────────────────────────────────────────
func add_property(square_id: int) -> void:
    if not owned_properties.has(square_id):
        owned_properties.append(square_id)
        GameEvents.player_properties_changed.emit(player_id, owned_properties)

func remove_property(square_id: int) -> void:
    owned_properties.erase(square_id)
    GameEvents.player_properties_changed.emit(player_id, owned_properties)

func owns_property(square_id: int) -> bool:
    return owned_properties.has(square_id)

func get_property_count() -> int:
    return owned_properties.size()

# ─────────────────────────────────────────
# OPERACIONES DE CARTAS GRAND PRIX
# ─────────────────────────────────────────
func add_grand_prix_card(card: Dictionary) -> void:
    owned_grand_prix_cards.append(card)
    GameEvents.player_cards_changed.emit(player_id, owned_grand_prix_cards)

func remove_grand_prix_card(card_id: int) -> Dictionary:
    for i in owned_grand_prix_cards.size():
        if owned_grand_prix_cards[i]["id"] == card_id:
            var card = owned_grand_prix_cards[i]
            owned_grand_prix_cards.remove_at(i)
            GameEvents.player_cards_changed.emit(player_id, owned_grand_prix_cards)
            return card
    return {}

# ─────────────────────────────────────────
# OPERACIONES DE CÁRCEL
# ─────────────────────────────────────────
func send_to_jail() -> void:
    is_in_jail = true
    jail_turns_remaining = JAIL_TURNS
    square_index = JAIL_SQUARE_INDEX
    GameEvents.player_jailed.emit(player_id)

func tick_jail_turn() -> void:
    if not is_in_jail:
        return
    jail_turns_remaining -= 1
    if jail_turns_remaining <= 0:
        release_from_jail()

func release_from_jail() -> void:
    is_in_jail = false
    jail_turns_remaining = 0
    GameEvents.player_released_from_jail.emit(player_id)

# ─────────────────────────────────────────
# SERIALIZACIÓN — para guardar estado
# ─────────────────────────────────────────
func to_dict() -> Dictionary:
    return {
        "player_id": player_id,
        "player_name": player_name,
        "character_id": character_id,
        "coins": coins,
        "square_index": square_index,
        "owned_properties": owned_properties,
        "is_in_jail": is_in_jail,
        "jail_turns_remaining": jail_turns_remaining
    }

func from_dict(data: Dictionary) -> void:
    player_id = data["player_id"]
    player_name = data["player_name"]
    character_id = data["character_id"]
    coins = data["coins"]
    square_index = data["square_index"]
    owned_properties = data["owned_properties"]
    is_in_jail = data["is_in_jail"]
    jail_turns_remaining = data["jail_turns_remaining"]
