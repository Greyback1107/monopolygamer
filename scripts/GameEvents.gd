# scripts/GameEvents.gd  ← agregar a Autoloads en Project Settings
extends Node

# --- Tablero ---
signal square_clicked(square)
signal player_landed_on_square(player, square)

# --- Propiedades ---
signal property_available(player, square)
signal rent_due(player, owner, amount)

# --- Carreras ---
signal trigger_grand_prix(player)

# --- Dados ---
signal request_bonus_roll(player, mode)   # "numeric" o "collect_coins"

# --- Personajes ---
signal activate_superstar(player)

# --- Bananas ---
signal banana_triggered(player, square)

# En GameEvents.gd — agregar:

# Dados
signal dice_roll_started(player)
signal dice_roll_completed(player, numeric_result, powerup_face, resolve_order)
signal bonus_roll_requested(player, mode)   # "numeric" o "collect_coins"

# Power-Up effects (los emite el DiceSystem después de resolver)
signal effect_collect_coins(player, amount)
signal effect_target_next_drop(target_player, amount)
signal effect_target_any_drop(source_player, amount)
signal effect_all_drop(source_player, amount)
signal effect_place_banana(player)

# En GameEvents.gd — agregar al bloque de personajes:

# Super Star
signal superstar_animation(player_id)
signal powerup_skipped(player_id)
signal metal_mario_activated(player_id)

# Efectos de power-up

signal effect_steal_coins(player_id, target_id, amount)
signal effect_steal_from_all(player_id, amount)

signal effect_others_drop(player_id, amount)
signal effect_richest_drops(player_id, amount)

signal effect_collect_dropped(player_id)
signal effect_collect_board_coins(player_id)
signal effect_swap_position(player_id)
signal effect_spend_coins_move(player_id, max_coins)
signal effect_place_bananas_owned(player_id, count)
signal effect_remove_bananas_coins(player_id, coins_per_banana)
signal effect_move_cheapest_property(player_id)
signal effect_move_to_superstar(player_id)
signal effect_target_choice_drop(player_id, amount, direction)

# Grand Prix
signal show_race_ui(trigger_player_id, card_data)
signal race_ui_closed()
signal award_race_points(player_id, points)
signal award_grand_prix_card(player_id, card_data)
signal trigger_game_over()

# Grand Prix — premios complejos
signal effect_roll_and_collect(player_id)
signal effect_buy_from_player(player_id)
signal effect_swap_properties(player_id, can_include_self)
signal effect_auction_property(player_id, payment_to)
signal effect_send_to_free_parking(player_id, target, skip_go, skip_coins)
signal effect_send_to_jail(player_id, target)
signal effect_steal_card_rematch(player_id, all_can_participate)

# Scoring
signal score_updated(player_id, score_data)
signal show_end_screen(ranking)

# Resoluciones de interacciones
signal coins_dropped(player_id, amount)
signal coins_stolen(source_id, target_id, amount)
signal property_bought_from_player(buyer_id, square_id)
signal auction_started(square_id, payment_to)
signal player_sent_to_free_parking(player_id, skip_go, skip_coins)
signal player_sent_to_jail(player_id)
signal positions_swapped(player_a, player_b)
signal properties_swapped(source_id, player_a, player_b)
signal rematch_started(winner_id, card_data, all_participate)

# TurnManager
signal turn_started(player_id)
signal turn_ended(player_id)
signal turn_state_changed(player_id, state)
signal update_turn_hud(player_id)
signal roll_button_pressed()
signal dice_order_chosen(order)
signal interaction_completed()

# Movimiento
signal player_move_completed(player_id, landed_square)
signal square_effect_completed(player_id)
signal passed_go(player_id)
signal powerup_effect_completed(player_id)

# Cárcel
signal jail_turn_skipped(player_id)

# PlayerManager — estado del jugador
signal player_coins_changed(player_id, new_amount)
signal player_properties_changed(player_id, properties)
signal player_cards_changed(player_id, cards)
signal player_jailed(player_id)
signal player_released_from_jail(player_id)
signal player_move_forced(player_id, target_square)
signal coins_placed_on_square(square_index, amount)

# BoardManager
signal player_token_move(player_id, target_square)
signal coins_collected_on_path(player_id, square_index, amount)
signal coins_collected_on_land(player_id, square_index, amount)
signal coins_collected_all(player_id, total)
signal board_coins_updated(square_index, amount)
signal banana_placed(square_index)
signal banana_removed(square_index)
signal banana_limit_reached()
signal request_banana_placement(player_id)
signal request_banana_removal(player_id, available_squares, coins_per_banana)

# PropertySystem
signal show_buy_panel(player_id, square)
signal hide_buy_panel()
signal property_purchased(player_id, square_id)
signal cant_afford_property(player_id, price)

signal show_rent_panel(owner_id, payer_id, amount, window)
signal hide_rent_panel()
signal rent_paid(payer_id, owner_id, amount)
signal rent_expired(owner_id, amount)
signal rent_timer_updated(remaining, total)

signal show_auction_panel(square, payment_to)
signal hide_auction_panel()
signal auction_completed(winner_id, square_id, amount)

signal property_transferred(buyer_id, seller_id, square_id)
signal property_swap_completed(player_a, square_a, player_b, square_b)
