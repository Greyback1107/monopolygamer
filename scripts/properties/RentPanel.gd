class_name RentPanel
extends PanelContainer

func _ready() -> void:
    GameEvents.show_rent_panel.connect(_on_show)
    GameEvents.hide_rent_panel.connect(func(): visible = false)
    GameEvents.rent_timer_updated.connect(_on_timer_update)
    $ClaimButton.pressed.connect(func():
        PropertySystem.owner_claims_rent()
    )
    visible = false

func _on_show(
        owner_id: int,
        payer_id: int,
        amount: int,
        window: float) -> void:

    $PayerLabel.text = "%s debe pagarte:" % \
        PlayerManager.get_player_name(payer_id)
    $AmountLabel.text = "%d monedas" % amount
    $TimerBar.max_value = window
    $TimerBar.value = window
    visible = true

func _on_timer_update(remaining: float, total: float) -> void:
    $TimerBar.value = remaining
    $TimerLabel.text = "%.1fs" % remaining
    # Cambiar color cuando queda poco tiempo
    if remaining < 3.0:
        $TimerBar.modulate = Color.RED
    else:
        $TimerBar.modulate = Color.WHITE
