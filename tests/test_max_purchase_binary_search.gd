## Test Max Purchase Binary Search: Tests max purchase calculation using binary search
## 
## Validates that binary search returns correct maximum quantity for exponential scaling.

extends Node

func _ready() -> void:
	print("=== Running Max Purchase Binary Search Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Basic max purchase
	all_passed = test_basic_max_purchase() and all_passed
	
	# Test 2: Max purchase with level offset
	all_passed = test_max_purchase_with_level() and all_passed
	
	# Test 3: Max purchase matches iterative
	all_passed = test_max_vs_iterative() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All max purchase tests passed!")
	else:
		print("✗ Some max purchase tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_basic_max_purchase() -> bool:
	print("Test: Basic max purchase")
	
	# Setup: growth=1.15, base_cost=10, gold=10_000
	var upgrade := UpgradeModel.new("test_max", "Test Max", "gold", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.level = 0
	GameState.upgrades["test_max"] = upgrade
	
	# Set gold amount
	var gold := ResourceModel.new("gold", "Gold", 0.0, true)
	gold.amount = 10_000.0
	GameState.resources["gold"] = gold
	
	# Calculate max purchase
	var max_qty := UpgradeService.compute_max_purchase("test_max")
	
	# Verify that we can afford max_qty but not max_qty + 1
	var cost_max := UpgradeService.compute_bulk_cost("test_max", max_qty)
	var cost_max_plus_one := UpgradeService.compute_bulk_cost("test_max", max_qty + 1)
	
	if cost_max > gold.amount:
		print("  ✗ Max quantity too high (cost: %.2f, gold: %.2f)" % [cost_max, gold.amount])
		return false
	
	if cost_max_plus_one <= gold.amount:
		print("  ✗ Max quantity too low (cost+1: %.2f, gold: %.2f)" % [cost_max_plus_one, gold.amount])
		return false
	
	print("  ✓ Max purchase correct: %d levels (cost: %.2f / %.2f gold)" % [max_qty, cost_max, gold.amount])
	return true

func test_max_purchase_with_level() -> bool:
	print("\nTest: Max purchase with existing levels")
	
	# Setup: Same as before but starting at level 10
	var upgrade := UpgradeModel.new("test_max2", "Test Max 2", "gold", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.level = 10
	GameState.upgrades["test_max2"] = upgrade
	
	# Set gold amount
	var gold := ResourceModel.new("gold", "Gold", 0.0, true)
	gold.amount = 5_000.0
	GameState.resources["gold"] = gold
	
	# Calculate max purchase
	var max_qty := UpgradeService.compute_max_purchase("test_max2")
	
	if max_qty == 0:
		print("  ✗ Max quantity is 0, but should be purchasable")
		return false
	
	# Verify affordability
	var cost_max := UpgradeService.compute_bulk_cost("test_max2", max_qty)
	var cost_max_plus_one := UpgradeService.compute_bulk_cost("test_max2", max_qty + 1)
	
	if cost_max > gold.amount:
		print("  ✗ Max quantity too high at level 10")
		return false
	
	if cost_max_plus_one <= gold.amount:
		print("  ✗ Max quantity too low at level 10")
		return false
	
	print("  ✓ Max purchase with level offset correct: %d levels" % max_qty)
	return true

func test_max_vs_iterative() -> bool:
	print("\nTest: Max purchase matches iterative simulation")
	
	# Setup
	var upgrade := UpgradeModel.new("test_max3", "Test Max 3", "gold", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.level = 0
	GameState.upgrades["test_max3"] = upgrade
	
	# Set gold amount
	var gold := ResourceModel.new("gold", "Gold", 0.0, true)
	gold.amount = 10_000.0
	GameState.resources["gold"] = gold
	
	# Binary search result
	var max_qty := UpgradeService.compute_max_purchase("test_max3")
	
	# Iterative simulation
	var iterative_max := 0
	var total_cost := 0.0
	for i in range(1, 1000):  # Reasonable upper bound
		var next_cost := UpgradeService.compute_bulk_cost("test_max3", i)
		if next_cost <= gold.amount:
			iterative_max = i
		else:
			break
	
	if max_qty != iterative_max:
		print("  ✗ Binary search (%d) doesn't match iterative (%d)" % [max_qty, iterative_max])
		return false
	
	print("  ✓ Binary search matches iterative: %d levels" % max_qty)
	return true
