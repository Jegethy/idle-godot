extends Node
## UpgradeService: Centralized upgrade purchase logic with bulk purchase support
## 
## Handles single and bulk upgrade purchases, cost calculations, and rate projections.

# Signals
signal upgrade_purchased(upgrade_id: String, new_level: int)
signal bulk_purchase_completed(upgrade_id: StringName, levels_purchased: int)

func _ready() -> void:
	print("UpgradeService initialized")

## Purchase one or more levels of an upgrade
## Returns true if the purchase was successful
func buy_upgrade(upgrade_id: StringName, quantity: int = 1) -> bool:
	if quantity < 1:
		return false
	
	var upgrade: UpgradeModel = GameState.get_upgrade(upgrade_id)
	if not upgrade or not upgrade.unlocked:
		return false
	
	# Calculate total cost for the bulk purchase
	var total_cost := compute_bulk_cost(upgrade_id, quantity)
	
	# Check if player can afford it
	if not GameState.can_afford("gold", total_cost):
		return false
	
	# Deduct the cost atomically
	if not GameState.spend_resource("gold", total_cost):
		return false
	
	# Increment the level by the quantity purchased
	upgrade.level += quantity
	
	# Emit purchase signal
	if quantity == 1:
		upgrade_purchased.emit(upgrade_id, upgrade.level)
	else:
		bulk_purchase_completed.emit(upgrade_id, quantity)
		upgrade_purchased.emit(upgrade_id, upgrade.level)
	
	# Recalculate rates after purchase
	Economy.recalculate_all_rates()
	
	return true

## Compute the total cost to purchase 'quantity' levels of an upgrade
func compute_bulk_cost(upgrade_id: StringName, quantity: int) -> float:
	var upgrade: UpgradeModel = GameState.get_upgrade(upgrade_id)
	if not upgrade:
		return 0.0
	
	var current_level := upgrade.level
	var total_cost := 0.0
	
	match upgrade.cost_scaling_type:
		Constants.CostScalingType.EXPONENTIAL:
			# Use geometric series formula: base * growth^L * (growth^n - 1) / (growth - 1)
			var base := upgrade.base_cost
			var growth := upgrade.cost_growth_factor
			var L := current_level
			
			if abs(growth - 1.0) < 0.0001:
				# Edge case: growth = 1.0 means constant cost
				total_cost = base * quantity
			else:
				total_cost = base * pow(growth, L) * (pow(growth, quantity) - 1.0) / (growth - 1.0)
		
		Constants.CostScalingType.QUADRATIC, Constants.CostScalingType.LINEAR:
			# For quadratic and linear, use iterative calculation
			# Cap at reasonable limit to prevent performance issues
			var safe_quantity := mini(quantity, 1000)
			for i in range(safe_quantity):
				total_cost += upgrade.get_cost_at_level(current_level + i)
		
		_:
			# Custom or unsupported scaling - use iterative
			for i in range(quantity):
				total_cost += upgrade.get_cost_at_level(current_level + i)
	
	return total_cost

## Compute the projected rate increase from purchasing 'quantity' levels
func compute_bulk_delta(upgrade_id: StringName, quantity: int) -> float:
	var upgrade: UpgradeModel = GameState.get_upgrade(upgrade_id)
	if not upgrade or not GameState.resources.has(upgrade.target):
		return 0.0
	
	# Get current rate
	var current_rate := Economy.get_per_second_rate(upgrade.target)
	
	# Simulate upgraded level
	var original_level := upgrade.level
	upgrade.level += quantity
	
	# Recalculate rate with new level
	var new_rate := Economy.compute_resource_rate(upgrade.target)
	
	# Restore original level
	upgrade.level = original_level
	
	return new_rate - current_rate

## Calculate the maximum quantity that can be purchased with available gold
## Uses binary search for exponential scaling, iterative for others
func compute_max_purchase(upgrade_id: StringName) -> int:
	var upgrade: UpgradeModel = GameState.get_upgrade(upgrade_id)
	if not upgrade or not upgrade.unlocked:
		return 0
	
	var available_gold := GameState.resources["gold"].amount if GameState.resources.has("gold") else 0.0
	
	if available_gold <= 0.0:
		return 0
	
	match upgrade.cost_scaling_type:
		Constants.CostScalingType.EXPONENTIAL:
			return _compute_max_exponential(upgrade, available_gold)
		_:
			return _compute_max_iterative(upgrade, available_gold)

## Binary search for maximum exponential purchase
func _compute_max_exponential(upgrade: UpgradeModel, available_gold: float) -> int:
	# Find upper bound by doubling
	var upper_bound := 1
	while true:
		var cost := compute_bulk_cost(upgrade.id, upper_bound)
		if cost > available_gold or upper_bound > 10000:  # Safety cap
			break
		upper_bound *= 2
	
	# Binary search between 0 and upper_bound
	var low := 0
	var high := upper_bound
	var result := 0
	
	while low <= high:
		var mid := (low + high) / 2
		var cost := compute_bulk_cost(upgrade.id, mid)
		
		if cost <= available_gold:
			result = mid
			low = mid + 1
		else:
			high = mid - 1
	
	return result

## Iterative search for maximum purchase (used for quadratic/linear)
func _compute_max_iterative(upgrade: UpgradeModel, available_gold: float) -> int:
	var quantity := 0
	var total_cost := 0.0
	var max_iterations := 1000  # Safety cap
	
	for i in range(max_iterations):
		var next_cost := compute_bulk_cost(upgrade.id, i + 1)
		if next_cost > available_gold:
			break
		quantity = i + 1
	
	return quantity
