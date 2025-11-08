extends Node
## Economy: Resource income calculation and upgrade management
## 
## Handles tick-based resource generation, upgrade application,
## cost scaling, and prestige formulas.

func _ready() -> void:
	print("Economy initialized")

func calculate_income_per_second(resource: ResourceModel) -> float:
	# Base rate + sum of modifiers * global multipliers
	var total_rate: float = resource.get_total_rate()
	total_rate *= GameState.player_stats.idle_rate_multiplier
	return total_rate

func apply_tick(delta: float) -> void:
	# Apply resource generation for this tick
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		if resource.unlocked:
			var income: float = calculate_income_per_second(resource) * delta
			GameState.add_resource_amount(resource_id, income)

func purchase_upgrade(upgrade_id: String) -> bool:
	var upgrade: UpgradeModel = GameState.get_upgrade(upgrade_id)
	if not upgrade or not upgrade.unlocked:
		return false
	
	var cost: float = upgrade.get_current_cost()
	# Assume upgrades cost the primary resource (gold for now)
	# TODO: Support multi-resource costs
	if GameState.spend_resource("gold", cost):
		upgrade.level += 1
		_apply_upgrade_effect(upgrade)
		GameState.upgrade_purchased.emit(upgrade_id, upgrade.level)
		return true
	
	return false

func _apply_upgrade_effect(upgrade: UpgradeModel) -> void:
	# Apply the upgrade's effect to the target
	# TODO: More sophisticated effect system
	if GameState.resources.has(upgrade.target):
		var resource: ResourceModel = GameState.resources[upgrade.target]
		resource.add_modifier(upgrade.effect_value)

func calculate_prestige_essence(primary_resource_total: float) -> float:
	# essence_gain = floor( (total / threshold) ^ exponent )
	var ratio: float = primary_resource_total / Constants.PRESTIGE_THRESHOLD
	if ratio < 1.0:
		return 0.0
	return floor(pow(ratio, Constants.PRESTIGE_ESSENCE_EXPONENT))

func can_prestige() -> bool:
	# Check if player meets prestige requirements
	if GameState.resources.has("gold"):
		var gold_total: float = GameState.resources["gold"].amount
		return gold_total >= Constants.PRESTIGE_THRESHOLD
	return false

func perform_prestige() -> void:
	# TODO: Implement full prestige logic
	if can_prestige():
		var essence_gain: float = calculate_prestige_essence(GameState.resources["gold"].amount)
		GameState.essence += essence_gain
		GameState.reset_for_prestige()
		GameState.prestige_performed.emit(GameState.essence)
