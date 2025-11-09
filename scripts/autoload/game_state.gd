extends Node
## GameState: In-memory authoritative game state
## 
## Stores resources, upgrades, items, player stats, and essence.
## This is the single source of truth for game data.

# Signals
signal resource_changed(resource_id: String, new_amount: float)
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal item_acquired(item_id: String, quantity: int)
signal prestige_performed(new_essence_total: float)
signal rates_updated()
signal essence_changed(total_essence: float)

# State data
var resources: Dictionary = {}  # {id: ResourceModel}
var upgrades: Dictionary = {}   # {id: UpgradeModel}
var items: Array[ItemModel] = []
var player_stats: PlayerStatsModel = PlayerStatsModel.new()
var essence: float = 0.0
var lifetime_gold: float = 0.0
var total_prestiges: int = 0
var essence_spent: float = 0.0  # For future meta-upgrades

# Combat state
var current_wave: int = 0
var lifetime_enemies_defeated: int = 0

func _ready() -> void:
	_initialize_default_state()

func _initialize_default_state() -> void:
	# Load resources from data file
	_load_resources_from_file()
	
	# Load upgrades from data file
	_load_upgrades_from_file()
	
	print("GameState initialized")

func _load_resources_from_file() -> void:
	var file_path := "res://data/resources.json"
	if not FileAccess.file_exists(file_path):
		push_error("Resources data file not found: %s" % file_path)
		_create_fallback_resources()
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open resources data file")
		_create_fallback_resources()
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse resources JSON: %s" % json.get_error_message())
		_create_fallback_resources()
		return
	
	var data: Dictionary = json.data
	if not data.has("resources"):
		push_error("Resources JSON missing 'resources' array")
		_create_fallback_resources()
		return
	
	var resources_array: Array = data["resources"]
	for resource_data in resources_array:
		if not resource_data is Dictionary:
			continue
		
		var resource := ResourceModel.new(
			resource_data.get("id", ""),
			resource_data.get("display_name", ""),
			resource_data.get("base_rate", 0.0),
			resource_data.get("unlocked", false)
		)
		resources[resource.id] = resource
	
	print("Loaded %d resources from data file" % resources.size())

func _load_upgrades_from_file() -> void:
	var file_path := "res://data/upgrades.json"
	if not FileAccess.file_exists(file_path):
		push_error("Upgrades data file not found: %s" % file_path)
		_create_fallback_upgrades()
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open upgrades data file")
		_create_fallback_upgrades()
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse upgrades JSON: %s" % json.get_error_message())
		_create_fallback_upgrades()
		return
	
	var data: Dictionary = json.data
	if not data.has("upgrades"):
		push_error("Upgrades JSON missing 'upgrades' array")
		_create_fallback_upgrades()
		return
	
	var upgrades_array: Array = data["upgrades"]
	for upgrade_data in upgrades_array:
		if not upgrade_data is Dictionary:
			continue
		
		# Parse upgrade type
		var upgrade_type := UpgradeModel.UpgradeType.RATE
		var type_str: String = upgrade_data.get("type", "rate")
		if type_str == "multiplier":
			upgrade_type = UpgradeModel.UpgradeType.MULTIPLIER
		
		# Parse cost scaling type
		var scaling_type := Constants.CostScalingType.EXPONENTIAL
		var scaling_str: String = upgrade_data.get("cost_scaling_type", "exponential")
		match scaling_str:
			"quadratic":
				scaling_type = Constants.CostScalingType.QUADRATIC
			"linear":
				scaling_type = Constants.CostScalingType.LINEAR
			"custom":
				scaling_type = Constants.CostScalingType.CUSTOM
		
		var upgrade := UpgradeModel.new(
			upgrade_data.get("id", ""),
			upgrade_data.get("display_name", ""),
			upgrade_data.get("target_resource", ""),
			upgrade_data.get("base_cost", 10.0),
			upgrade_data.get("unlocked", false),
			upgrade_type
		)
		upgrade.description = upgrade_data.get("description", "")
		upgrade.cost_scaling_type = scaling_type
		upgrade.cost_growth_factor = upgrade_data.get("cost_growth_factor", 1.15)
		upgrade.base_bonus = upgrade_data.get("base_bonus", 1.0)
		upgrade.level = 0  # Always start at level 0
		
		upgrades[upgrade.id] = upgrade
	
	print("Loaded %d upgrades from data file" % upgrades.size())

func _create_fallback_resources() -> void:
	# Create default resources as fallback
	var gold := ResourceModel.new("gold", "Gold", 1.0, true)
	resources["gold"] = gold
	print("Created fallback resources")

func _create_fallback_upgrades() -> void:
	# Create default upgrades as fallback
	var gold_boost := UpgradeModel.new("gold_boost", "Gold Production", "gold", 10.0, true)
	gold_boost.description = "Increases gold production"
	gold_boost.base_bonus = 0.5
	upgrades["gold_boost"] = gold_boost
	print("Created fallback upgrades")

func get_resource(resource_id: String) -> ResourceModel:
	return resources.get(resource_id, null)

func get_upgrade(upgrade_id: String) -> UpgradeModel:
	return upgrades.get(upgrade_id, null)

func add_resource_amount(resource_id: String, amount: float) -> void:
	if resources.has(resource_id):
		resources[resource_id].amount += amount
		resource_changed.emit(resource_id, resources[resource_id].amount)

func can_afford(resource_id: String, cost: float) -> bool:
	if resources.has(resource_id):
		return resources[resource_id].amount >= cost
	return false

func spend_resource(resource_id: String, cost: float) -> bool:
	if can_afford(resource_id, cost):
		resources[resource_id].amount -= cost
		resource_changed.emit(resource_id, resources[resource_id].amount)
		return true
	return false

func reset_for_prestige() -> void:
	# TODO: Implement prestige reset logic
	pass
