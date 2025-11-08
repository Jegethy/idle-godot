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

# State data
var resources: Dictionary = {}  # {id: ResourceModel}
var upgrades: Dictionary = {}   # {id: UpgradeModel}
var items: Array[ItemModel] = []
var player_stats: PlayerStatsModel = PlayerStatsModel.new()
var essence: float = 0.0

func _ready() -> void:
	_initialize_default_state()

func _initialize_default_state() -> void:
	# TODO: Load from data files or create default resources/upgrades
	# For now, create a simple example resource
	var gold := ResourceModel.new("gold", "Gold", 1.0, true)
	resources["gold"] = gold
	
	# Example upgrade
	var gold_boost := UpgradeModel.new("gold_boost", "Gold Production", "gold", 10.0, true)
	gold_boost.description = "Increases gold production"
	gold_boost.effect_value = 0.5
	upgrades["gold_boost"] = gold_boost
	
	print("GameState initialized")

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
