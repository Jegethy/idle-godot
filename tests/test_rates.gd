## Test Rates: Test resource rate calculations
## 
## Validates base rate accumulation, rate upgrades, and multiplier upgrades.

extends SceneTree

func _init() -> void:
	print("=== Running Rate Calculation Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Base rate accumulation
	all_passed = test_base_rate_accumulation() and all_passed
	
	# Test 2: Rate upgrade effects
	all_passed = test_rate_upgrade_effect() and all_passed
	
	# Test 3: Multiplier upgrade effects
	all_passed = test_multiplier_upgrade_effect() and all_passed
	
	# Test 4: Stacked multiplier upgrades
	all_passed = test_stacked_multipliers() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All rate tests passed!")
	else:
		print("✗ Some rate tests failed")
	
	quit(0 if all_passed else 1)

func test_base_rate_accumulation() -> bool:
	print("Test: Base rate accumulation")
	
	# Create a test resource with base_rate = 1.0
	var resource := ResourceModel.new("test_gold", "Test Gold", 1.0, true)
	GameState.resources["test_gold"] = resource
	
	# Simulate 10 ticks of 1 second each
	var initial_amount := resource.amount
	for i in range(10):
		Economy.apply_tick(1.0)
	
	var expected_gain := 10.0  # 1.0 per second * 10 seconds
	var actual_gain := resource.amount - initial_amount
	
	# Allow small floating point error
	if abs(actual_gain - expected_gain) > 0.01:
		print("  ✗ Base rate accumulation failed (expected %.2f, got %.2f)" % [expected_gain, actual_gain])
		return false
	
	print("  ✓ Base rate accumulation correct")
	return true

func test_rate_upgrade_effect() -> bool:
	print("\nTest: Rate upgrade effect")
	
	# Create a fresh test resource
	var resource := ResourceModel.new("test_gold2", "Test Gold 2", 1.0, true)
	GameState.resources["test_gold2"] = resource
	
	# Create a rate upgrade with base_bonus = 2.0
	var upgrade := UpgradeModel.new(
		"test_rate_upgrade",
		"Test Rate Upgrade",
		"test_gold2",
		10.0,
		true,
		UpgradeModel.UpgradeType.RATE
	)
	upgrade.base_bonus = 2.0
	upgrade.level = 3  # Set to level 3 directly
	GameState.upgrades["test_rate_upgrade"] = upgrade
	
	# Compute expected rate: base_rate (1.0) + (base_bonus * level) = 1.0 + (2.0 * 3) = 7.0
	var expected_rate := 7.0
	var actual_rate := Economy.compute_resource_rate("test_gold2")
	
	if abs(actual_rate - expected_rate) > 0.01:
		print("  ✗ Rate upgrade effect incorrect (expected %.2f/sec, got %.2f/sec)" % [expected_rate, actual_rate])
		return false
	
	print("  ✓ Rate upgrade effect correct (+%.2f/sec at level 3)" % (upgrade.base_bonus * 3))
	return true

func test_multiplier_upgrade_effect() -> bool:
	print("\nTest: Multiplier upgrade effect")
	
	# Create a fresh test resource
	var resource := ResourceModel.new("test_gold3", "Test Gold 3", 10.0, true)
	GameState.resources["test_gold3"] = resource
	
	# Create a multiplier upgrade with base_bonus = 0.1 (10% per level)
	var upgrade := UpgradeModel.new(
		"test_mult_upgrade",
		"Test Multiplier Upgrade",
		"test_gold3",
		100.0,
		true,
		UpgradeModel.UpgradeType.MULTIPLIER
	)
	upgrade.base_bonus = 0.1
	upgrade.level = 3  # Set to level 3
	GameState.upgrades["test_mult_upgrade"] = upgrade
	
	# Expected rate: base_rate (10.0) * (1 + base_bonus * level) = 10.0 * (1 + 0.1 * 3) = 10.0 * 1.3 = 13.0
	var expected_rate := 13.0
	var actual_rate := Economy.compute_resource_rate("test_gold3")
	
	if abs(actual_rate - expected_rate) > 0.01:
		print("  ✗ Multiplier upgrade effect incorrect (expected %.2f/sec, got %.2f/sec)" % [expected_rate, actual_rate])
		return false
	
	print("  ✓ Multiplier upgrade effect correct (x%.2f at level 3)" % (1.0 + upgrade.base_bonus * 3))
	return true

func test_stacked_multipliers() -> bool:
	print("\nTest: Stacked multiplier upgrades")
	
	# Create a fresh test resource
	var resource := ResourceModel.new("test_gold4", "Test Gold 4", 5.0, true)
	GameState.resources["test_gold4"] = resource
	
	# Create two multiplier upgrades
	var upgrade1 := UpgradeModel.new(
		"test_mult1",
		"Multiplier 1",
		"test_gold4",
		100.0,
		true,
		UpgradeModel.UpgradeType.MULTIPLIER
	)
	upgrade1.base_bonus = 0.2  # 20% per level
	upgrade1.level = 2
	GameState.upgrades["test_mult1"] = upgrade1
	
	var upgrade2 := UpgradeModel.new(
		"test_mult2",
		"Multiplier 2",
		"test_gold4",
		100.0,
		true,
		UpgradeModel.UpgradeType.MULTIPLIER
	)
	upgrade2.base_bonus = 0.1  # 10% per level
	upgrade2.level = 3
	GameState.upgrades["test_mult2"] = upgrade2
	
	# Expected: base_rate (5.0) * (1 + 0.2 * 2) * (1 + 0.1 * 3)
	#         = 5.0 * 1.4 * 1.3 = 9.1
	var expected_rate := 9.1
	var actual_rate := Economy.compute_resource_rate("test_gold4")
	
	if abs(actual_rate - expected_rate) > 0.01:
		print("  ✗ Stacked multipliers incorrect (expected %.2f/sec, got %.2f/sec)" % [expected_rate, actual_rate])
		return false
	
	print("  ✓ Stacked multipliers correct (x%.2f total)" % (actual_rate / 5.0))
	return true
