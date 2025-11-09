## Test Bulk Delta: Tests projected rate increase from bulk purchases
## 
## Validates that compute_bulk_delta matches actual rate increase after purchase.

extends Node

func _ready() -> void:
	print("=== Running Bulk Delta Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Single level delta
	all_passed = test_single_level_delta() and all_passed
	
	# Test 2: Multiple levels delta
	all_passed = test_multiple_levels_delta() and all_passed
	
	# Test 3: Delta accuracy with multiplier upgrade
	all_passed = test_delta_with_multiplier() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All bulk delta tests passed!")
	else:
		print("✗ Some bulk delta tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_single_level_delta() -> bool:
	print("Test: Single level delta")
	
	# Create test resource
	var resource := ResourceModel.new("test_gold", "Test Gold", 1.0, true)
	GameState.resources["test_gold"] = resource
	
	# Create rate upgrade
	var upgrade := UpgradeModel.new("test_delta", "Test Delta", "test_gold", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.base_bonus = 2.0
	upgrade.type = UpgradeModel.UpgradeType.RATE
	upgrade.level = 0
	GameState.upgrades["test_delta"] = upgrade
	
	# Get current rate
	Economy.recalculate_all_rates()
	var current_rate := Economy.get_per_second_rate("test_gold")
	
	# Calculate projected delta for 1 level
	var projected_delta := UpgradeService.compute_bulk_delta("test_delta", 1)
	
	# Expected delta: base_bonus * 1 = 2.0
	var expected_delta := 2.0
	
	if abs(projected_delta - expected_delta) > 0.01:
		print("  ✗ Single level delta incorrect (expected %.2f, got %.2f)" % [expected_delta, projected_delta])
		return false
	
	print("  ✓ Single level delta correct: +%.2f/sec" % projected_delta)
	return true

func test_multiple_levels_delta() -> bool:
	print("\nTest: Multiple levels delta")
	
	# Create test resource
	var resource := ResourceModel.new("test_gold2", "Test Gold 2", 1.0, true)
	GameState.resources["test_gold2"] = resource
	
	# Create rate upgrade
	var upgrade := UpgradeModel.new("test_delta2", "Test Delta 2", "test_gold2", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.base_bonus = 3.0
	upgrade.type = UpgradeModel.UpgradeType.RATE
	upgrade.level = 5
	GameState.upgrades["test_delta2"] = upgrade
	
	# Get current rate
	Economy.recalculate_all_rates()
	var current_rate := Economy.get_per_second_rate("test_gold2")
	
	# Calculate projected delta for 10 levels
	var projected_delta := UpgradeService.compute_bulk_delta("test_delta2", 10)
	
	# Expected delta: base_bonus * 10 = 30.0
	var expected_delta := 30.0
	
	if abs(projected_delta - expected_delta) > 0.01:
		print("  ✗ Multiple levels delta incorrect (expected %.2f, got %.2f)" % [expected_delta, projected_delta])
		return false
	
	print("  ✓ Multiple levels delta correct: +%.2f/sec" % projected_delta)
	return true

func test_delta_with_multiplier() -> bool:
	print("\nTest: Delta with multiplier upgrade")
	
	# Create test resource
	var resource := ResourceModel.new("test_gold3", "Test Gold 3", 10.0, true)
	GameState.resources["test_gold3"] = resource
	
	# Create rate upgrade (provides base rate)
	var rate_upgrade := UpgradeModel.new("test_rate", "Test Rate", "test_gold3", 10.0, true)
	rate_upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	rate_upgrade.cost_growth_factor = 1.15
	rate_upgrade.base_bonus = 5.0
	rate_upgrade.type = UpgradeModel.UpgradeType.RATE
	rate_upgrade.level = 2  # Adds 10 to rate
	GameState.upgrades["test_rate"] = rate_upgrade
	
	# Create multiplier upgrade
	var mult_upgrade := UpgradeModel.new("test_mult", "Test Mult", "test_gold3", 50.0, true)
	mult_upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	mult_upgrade.cost_growth_factor = 1.15
	mult_upgrade.base_bonus = 0.1  # 10% per level
	mult_upgrade.type = UpgradeModel.UpgradeType.MULTIPLIER
	mult_upgrade.level = 0
	GameState.upgrades["test_mult"] = mult_upgrade
	
	# Current rate: (base 10 + rate 10) * (1 + 0) = 20
	Economy.recalculate_all_rates()
	var current_rate := Economy.get_per_second_rate("test_gold3")
	
	# Calculate projected delta for 1 multiplier level
	var projected_delta := UpgradeService.compute_bulk_delta("test_mult", 1)
	
	# After purchase: (10 + 10) * (1 + 0.1*1) = 20 * 1.1 = 22
	# Delta: 22 - 20 = 2
	var expected_delta := 2.0
	
	var tolerance := 0.01
	if abs(projected_delta - expected_delta) > tolerance:
		print("  ✗ Multiplier delta incorrect (expected %.2f, got %.2f)" % [expected_delta, projected_delta])
		return false
	
	print("  ✓ Multiplier delta correct: +%.2f/sec" % projected_delta)
	return true
