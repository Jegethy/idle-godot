extends PanelContainer
## DebugPanel: Temporary debug UI for testing resource rates and upgrades
## 
## Shows resource amounts, per-second rates, and upgrade purchase buttons.

@onready var resources_container: VBoxContainer = %ResourcesContainer
@onready var upgrades_container: VBoxContainer = %UpgradesContainer
@onready var refresh_timer: Timer = %RefreshTimer

var resource_labels: Dictionary = {}  # {resource_id: Label}
var upgrade_buttons: Dictionary = {}  # {upgrade_id: {button: Button, label: Label}}

func _ready() -> void:
	# Connect to game state signals
	GameState.resource_changed.connect(_on_resource_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.rates_updated.connect(_on_rates_updated)
	
	# Setup UI
	_setup_resources_ui()
	_setup_upgrades_ui()
	
	# Start refresh timer
	refresh_timer.timeout.connect(_on_refresh_timer_timeout)
	refresh_timer.start()
	
	# Initial update
	_update_all_displays()

func _setup_resources_ui() -> void:
	# Create labels for each resource
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		if resource.unlocked:
			var label := Label.new()
			label.text = _format_resource_text(resource)
			resources_container.add_child(label)
			resource_labels[resource_id] = label

func _setup_upgrades_ui() -> void:
	# Create buttons for each upgrade
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		if upgrade.unlocked:
			var hbox := HBoxContainer.new()
			
			# Info label
			var label := Label.new()
			label.text = _format_upgrade_text(upgrade)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(label)
			
			# Buy button
			var button := Button.new()
			button.text = "Buy"
			button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade_id))
			hbox.add_child(button)
			
			upgrades_container.add_child(hbox)
			upgrade_buttons[upgrade_id] = {
				"button": button,
				"label": label
			}

func _format_resource_text(resource: ResourceModel) -> String:
	var rate: float = Economy.get_per_second_rate(resource.id)
	return "Resource: %s | Amount: %.2f | Rate/sec: %.2f" % [
		resource.display_name,
		resource.amount,
		rate
	]

func _format_upgrade_text(upgrade: UpgradeModel) -> String:
	var cost: float = upgrade.get_current_cost()
	var next_delta: float = _calculate_next_delta(upgrade)
	var type_str := "Rate" if upgrade.type == UpgradeModel.UpgradeType.RATE else "Mult"
	
	return "%s [%s] Lvl:%d Cost:%.0f NextΔ/sec:+%.2f" % [
		upgrade.display_name,
		type_str,
		upgrade.level,
		cost,
		next_delta
	]

func _calculate_next_delta(upgrade: UpgradeModel) -> float:
	# Calculate the delta/sec that would result from buying this upgrade
	if not GameState.resources.has(upgrade.target):
		return 0.0
	
	var current_rate: float = Economy.get_per_second_rate(upgrade.target)
	
	# Simulate the upgrade at next level
	var temp_level := upgrade.level + 1
	var resource: ResourceModel = GameState.resources[upgrade.target]
	
	# Recalculate with upgraded level
	var rate_adders: float = resource.base_rate
	var multiplier_factors: float = 1.0
	
	for upg_id in GameState.upgrades:
		var upg: UpgradeModel = GameState.upgrades[upg_id]
		if upg.target != upgrade.target:
			continue
		
		var level_to_use := upg.level
		if upg.id == upgrade.id:
			level_to_use = temp_level
		
		if level_to_use == 0:
			continue
		
		match upg.type:
			UpgradeModel.UpgradeType.RATE:
				rate_adders += upg.base_bonus * level_to_use
			UpgradeModel.UpgradeType.MULTIPLIER:
				multiplier_factors *= (1.0 + upg.base_bonus * level_to_use)
	
	var new_rate: float = rate_adders * multiplier_factors * GameState.player_stats.idle_rate_multiplier
	
	return new_rate - current_rate

func _update_all_displays() -> void:
	_update_resource_displays()
	_update_upgrade_displays()

func _update_resource_displays() -> void:
	for resource_id in resource_labels:
		if GameState.resources.has(resource_id):
			var resource: ResourceModel = GameState.resources[resource_id]
			resource_labels[resource_id].text = _format_resource_text(resource)

func _update_upgrade_displays() -> void:
	for upgrade_id in upgrade_buttons:
		if GameState.upgrades.has(upgrade_id):
			var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
			var ui_elements: Dictionary = upgrade_buttons[upgrade_id]
			
			ui_elements["label"].text = _format_upgrade_text(upgrade)
			
			# Disable button if can't afford
			var cost: float = upgrade.get_current_cost()
			ui_elements["button"].disabled = not GameState.can_afford("gold", cost)

func _on_upgrade_button_pressed(upgrade_id: String) -> void:
	Economy.purchase_upgrade(upgrade_id)

func _on_resource_changed(_resource_id: String, _new_amount: float) -> void:
	# Will be updated on next timer tick
	pass

func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	# Update immediately after purchase
	_update_all_displays()

func _on_rates_updated() -> void:
	# Update displays when rates are recalculated
	_update_resource_displays()

func _on_refresh_timer_timeout() -> void:
	_update_all_displays()
