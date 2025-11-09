## Test Upgrade Costs: Test upgrade cost calculations
## 
## Validates cost scaling formulas (exponential, quadratic).

extends Node

func _ready() -> void:
	print("=== Running Upgrade Cost Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Exponential cost scaling
	all_passed = test_exponential_cost_scaling() and all_passed
	
	# Test 2: Quadratic cost scaling
	all_passed = test_quadratic_cost_scaling() and all_passed
	
	# Test 3: Purchase flow and cost progression
	all_passed = test_purchase_flow() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All upgrade cost tests passed!")
	else:
		print("✗ Some upgrade cost tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_exponential_cost_scaling() -> bool:
	print("Test: Exponential cost scaling")
	
	var upgrade := UpgradeModel.new("test_exp", "Test Exp", "gold", 100.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.5
	
	# Test level 0: base_cost * (growth ^ 0) = 100 * 1 = 100
	upgrade.level = 0
	var cost0 := upgrade.get_current_cost()
	if abs(cost0 - 100.0) > 0.01:
		print("  ✗ Level 0 cost incorrect (expected 100.0, got %.2f)" % cost0)
		return false
	
	# Test level 1: base_cost * (growth ^ 1) = 100 * 1.5 = 150
	upgrade.level = 1
	var cost1 := upgrade.get_current_cost()
	if abs(cost1 - 150.0) > 0.01:
		print("  ✗ Level 1 cost incorrect (expected 150.0, got %.2f)" % cost1)
		return false
	
	# Test level 2: base_cost * (growth ^ 2) = 100 * 2.25 = 225
	upgrade.level = 2
	var cost2 := upgrade.get_current_cost()
	if abs(cost2 - 225.0) > 0.01:
		print("  ✗ Level 2 cost incorrect (expected 225.0, got %.2f)" % cost2)
		return false
	
	print("  ✓ Exponential cost scaling correct (100 -> 150 -> 225)")
	return true

func test_quadratic_cost_scaling() -> bool:
	print("\nTest: Quadratic cost scaling")
	
	var upgrade := UpgradeModel.new("test_quad", "Test Quad", "gold", 100.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.QUADRATIC
	
	# Formula: base_cost * (1 + level + level^2 * 0.1)
	
	# Test level 0: 100 * (1 + 0 + 0) = 100
	upgrade.level = 0
	var cost0 := upgrade.get_current_cost()
	if abs(cost0 - 100.0) > 0.01:
		print("  ✗ Level 0 cost incorrect (expected 100.0, got %.2f)" % cost0)
		return false
	
	# Test level 1: 100 * (1 + 1 + 1*1*0.1) = 100 * 2.1 = 210
	upgrade.level = 1
	var expected1 := 100.0 * (1.0 + 1.0 + 1.0 * 1.0 * 0.1)
	var cost1 := upgrade.get_current_cost()
	if abs(cost1 - expected1) > 0.01:
		print("  ✗ Level 1 cost incorrect (expected %.2f, got %.2f)" % [expected1, cost1])
		return false
	
	# Test level 2: 100 * (1 + 2 + 4*0.1) = 100 * 3.4 = 340
	upgrade.level = 2
	var expected2 := 100.0 * (1.0 + 2.0 + 2.0 * 2.0 * 0.1)
	var cost2 := upgrade.get_current_cost()
	if abs(cost2 - expected2) > 0.01:
		print("  ✗ Level 2 cost incorrect (expected %.2f, got %.2f)" % [expected2, cost2])
		return false
	
	print("  ✓ Quadratic cost scaling correct (100 -> %.0f -> %.0f)" % [expected1, expected2])
	return true

func test_purchase_flow() -> bool:
	print("\nTest: Purchase flow and cost progression")
	
	# Setup a fresh resource
	var gold := ResourceModel.new("test_purchase_gold", "Test Gold", 0.0, true)
	gold.amount = 1000.0
	GameState.resources["test_purchase_gold"] = gold
	
	# Create an upgrade
	var upgrade := UpgradeModel.new(
		"test_purchase_upgrade",
		"Test Purchase",
		"test_purchase_gold",
		100.0,
		true
	)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.base_bonus = 1.0
	upgrade.type = UpgradeModel.UpgradeType.RATE
	GameState.upgrades["test_purchase_upgrade"] = upgrade
	
	# Purchase once (level 0->1, cost 100)
	var initial_gold := gold.amount
	var success := Economy.purchase_upgrade("test_purchase_upgrade")
	
	if not success:
		print("  ✗ First purchase failed")
		return false
	
	if upgrade.level != 1:
		print("  ✗ Upgrade level not incremented (expected 1, got %d)" % upgrade.level)
		return false
	
	var gold_spent := initial_gold - gold.amount
	if abs(gold_spent - 100.0) > 0.01:
		print("  ✗ Incorrect gold spent (expected 100, got %.2f)" % gold_spent)
		return false
	
	# Purchase again (level 1->2, cost 115)
	initial_gold = gold.amount
	success = Economy.purchase_upgrade("test_purchase_upgrade")
	
	if not success:
		print("  ✗ Second purchase failed")
		return false
	
	if upgrade.level != 2:
		print("  ✗ Upgrade level not incremented to 2 (got %d)" % upgrade.level)
		return false
	
	gold_spent = initial_gold - gold.amount
	var expected_cost := 100.0 * 1.15  # 115
	if abs(gold_spent - expected_cost) > 0.01:
		print("  ✗ Incorrect gold spent on second purchase (expected %.2f, got %.2f)" % [expected_cost, gold_spent])
		return false
	
	print("  ✓ Purchase flow correct (level progression and gold deduction)")
	return true
