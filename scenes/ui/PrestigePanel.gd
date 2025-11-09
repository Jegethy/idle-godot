extends PanelContainer
## PrestigePanel: Interactive prestige system UI
## 
## Shows lifetime gold, essence, projected gain, and current multiplier.
## Allows player to prestige with confirmation.

@onready var lifetime_gold_label: Label = %LifetimeGoldLabel
@onready var essence_label: Label = %EssenceLabel
@onready var projected_gain_label: Label = %ProjectedGainLabel
@onready var multiplier_label: Label = %MultiplierLabel
@onready var prestige_button: Button = %PrestigeButton
@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog

func _ready() -> void:
	# Connect signals
	if prestige_button:
		prestige_button.pressed.connect(_on_prestige_button_pressed)
	
	if confirmation_dialog:
		confirmation_dialog.confirmed.connect(_on_prestige_confirmed)
	
	# Connect to game state signals
	GameState.resource_changed.connect(_on_resource_changed)
	PrestigeService.essence_changed.connect(_on_essence_changed)
	PrestigeService.prestige_performed.connect(_on_prestige_performed)
	
	# Initial update
	_update_display()

func _process(_delta: float) -> void:
	# Update display every frame for real-time feedback
	_update_display()

func _update_display() -> void:
	# Update lifetime gold
	if lifetime_gold_label:
		var lifetime_gold: float = GameState.lifetime_gold
		lifetime_gold_label.text = "Lifetime Gold: %s" % NumberFormatter.format_short(lifetime_gold)
	
	# Update essence
	if essence_label:
		var essence: float = GameState.essence
		essence_label.text = "Essence: %s" % NumberFormatter.format_short(essence)
	
	# Update projected gain
	if projected_gain_label:
		var projected: int = PrestigeService.preview_essence_gain()
		projected_gain_label.text = "Projected Gain: +%d" % projected
	
	# Update multiplier
	if multiplier_label:
		var multiplier_text: String = PrestigeService.get_essence_multiplier_display()
		multiplier_label.text = "Idle Rate Multiplier: %s" % multiplier_text
	
	# Update button state
	if prestige_button:
		var can_prestige: bool = PrestigeService.can_prestige()
		prestige_button.disabled = not can_prestige
		
		if can_prestige:
			prestige_button.text = "Prestige"
		else:
			prestige_button.text = "Requirements Not Met"

func _on_prestige_button_pressed() -> void:
	if not confirmation_dialog:
		_perform_prestige()
		return
	
	# Show confirmation dialog
	var projected: int = PrestigeService.preview_essence_gain()
	confirmation_dialog.dialog_text = (
		"Are you sure you want to prestige?\n\n" +
		"You will gain: +%d Essence\n\n" % projected +
		"This will reset:\n" +
		"• Gold to 0\n" +
		"• All upgrades to level 0\n" +
		"• All items\n\n" +
		"You will keep:\n" +
		"• Essence (permanent)\n" +
		"• Lifetime Gold (tracking)\n" +
		"• Prestige count"
	)
	confirmation_dialog.popup_centered()

func _on_prestige_confirmed() -> void:
	_perform_prestige()

func _perform_prestige() -> void:
	var result: Dictionary = PrestigeService.perform_prestige()
	if result.get("success", false):
		# Animate essence label (simple pulse effect)
		if essence_label:
			_animate_essence_label()

func _animate_essence_label() -> void:
	# Simple scale animation
	if not essence_label:
		return
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(essence_label, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(essence_label, "scale", Vector2(1.0, 1.0), 0.3)

func _on_resource_changed(_resource_id: String, _new_amount: float) -> void:
	_update_display()

func _on_essence_changed(_total_essence: float) -> void:
	_update_display()

func _on_prestige_performed(_gained: int, _total_essence: float, _total_prestiges: int) -> void:
	_update_display()
