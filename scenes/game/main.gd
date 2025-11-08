extends Control
## Main: Main game scene controller
## 
## Manages UI updates and player interactions.

@onready var resources_list: VBoxContainer = %ResourcesList
@onready var upgrades_list: VBoxContainer = %UpgradesList

var resource_labels: Dictionary = {}
var upgrade_buttons: Dictionary = {}

func _ready() -> void:
	# Connect to game state signals
	GameState.resource_changed.connect(_on_resource_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	
	# Initialize UI
	_setup_resources_ui()
	_setup_upgrades_ui()
	
	# Try to load saved game
	SaveSystem.load_game()
	
	print("Main scene ready")

func _setup_resources_ui() -> void:
	# Create labels for each resource
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		if resource.unlocked:
			var label := Label.new()
			label.text = _format_resource_text(resource)
			resources_list.add_child(label)
			resource_labels[resource_id] = label

func _setup_upgrades_ui() -> void:
	# Create buttons for each upgrade
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		if upgrade.unlocked:
			var button := Button.new()
			button.text = _format_upgrade_text(upgrade)
			button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade_id))
			upgrades_list.add_child(button)
			upgrade_buttons[upgrade_id] = button

func _format_resource_text(resource: ResourceModel) -> String:
	return "%s: %.2f (%.2f/s)" % [
		resource.display_name,
		resource.amount,
		Economy.calculate_income_per_second(resource)
	]

func _format_upgrade_text(upgrade: UpgradeModel) -> String:
	return "%s (Level %d) - Cost: %.0f" % [
		upgrade.display_name,
		upgrade.level,
		upgrade.get_current_cost()
	]

func _process(_delta: float) -> void:
	# Update resource displays
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
			upgrade_buttons[upgrade_id].text = _format_upgrade_text(upgrade)
			# Disable button if can't afford
			var cost: float = upgrade.get_current_cost()
			upgrade_buttons[upgrade_id].disabled = not GameState.can_afford("gold", cost)

func _on_upgrade_button_pressed(upgrade_id: String) -> void:
	Economy.purchase_upgrade(upgrade_id)

func _on_resource_changed(_resource_id: String, _new_amount: float) -> void:
	# Resource displays are updated in _process
	pass

func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	# Upgrade displays are updated in _process
	pass

func _on_save_button_pressed() -> void:
	SaveSystem.save_game()

func _on_load_button_pressed() -> void:
	SaveSystem.load_game()
	# Refresh UI after loading
	_clear_ui()
	_setup_resources_ui()
	_setup_upgrades_ui()

func _clear_ui() -> void:
	# Clear existing UI elements
	for child in resources_list.get_children():
		child.queue_free()
	for child in upgrades_list.get_children():
		child.queue_free()
	resource_labels.clear()
	upgrade_buttons.clear()
