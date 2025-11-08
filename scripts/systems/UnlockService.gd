extends Node
## UnlockService: Handles unlock conditions for resources and upgrades
## 
## Evaluates unlock conditions and manages unlocking of game content.

# Signal emitted when something unlocks
signal content_unlocked(content_type: String, content_id: String)

func _ready() -> void:
	print("UnlockService initialized")
	# Connect to signals to check unlock conditions
	GameState.resource_changed.connect(_check_unlock_conditions)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)

## Check if an upgrade's unlock condition is met
func is_upgrade_unlocked(upgrade_id: StringName) -> bool:
	var upgrade: UpgradeModel = GameState.get_upgrade(upgrade_id)
	if not upgrade:
		return false
	
	# If already unlocked, return true
	if upgrade.unlocked:
		return true
	
	# Check unlock condition (stored in upgrade data)
	# For now, we'll check if the upgrade has an unlock_condition field
	# This will be populated from JSON data
	return false

## Check if a resource's unlock condition is met
func is_resource_unlocked(resource_id: StringName) -> bool:
	var resource: ResourceModel = GameState.get_resource(resource_id)
	if not resource:
		return false
	
	# If already unlocked, return true
	if resource.unlocked:
		return true
	
	return false

## Evaluate an unlock condition dictionary
func evaluate_condition(condition: Dictionary) -> bool:
	if condition.is_empty():
		return true
	
	var condition_type := condition.get("type", "")
	
	match condition_type:
		"resource_amount":
			var resource_id := condition.get("resource", "")
			var threshold := condition.get("threshold", 0.0)
			if GameState.resources.has(resource_id):
				return GameState.resources[resource_id].amount >= threshold
			return false
		
		"upgrade_level":
			var upgrade_id := condition.get("upgrade_id", "")
			var required_level := condition.get("level", 1)
			if GameState.upgrades.has(upgrade_id):
				return GameState.upgrades[upgrade_id].level >= required_level
			return false
		
		_:
			# Unknown condition type - default to false
			return false

## Check all unlock conditions (called when resources change)
func _check_unlock_conditions(_resource_id: String = "", _amount: float = 0.0) -> void:
	# Check upgrades for unlock conditions
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		if not upgrade.unlocked:
			# This would check the upgrade's unlock_condition if it exists
			# For now, we'll skip this since we need to add unlock conditions to the data
			pass
	
	# Check resources for unlock conditions
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		if not resource.unlocked:
			# Similar to upgrades, check unlock conditions
			pass

func _on_upgrade_purchased(_upgrade_id: String, _level: int) -> void:
	# Check unlock conditions when upgrades are purchased
	_check_unlock_conditions()
