## Test Bulk Cost Exponential: Tests bulk cost calculation for exponential scaling
## 
## Validates geometric series formula against iterative summation.

extends Node

func _ready() -> void:
	print("=== Running Bulk Cost Exponential Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Single purchase (n=1)
	all_passed = test_single_purchase() and all_passed
	
	# Test 2: Multiple purchases
	all_passed = test_multiple_purchases() and all_passed
	
	# Test 3: Formula vs iterative accuracy
	all_passed = test_formula_accuracy() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All bulk cost exponential tests passed!")
	else:
		print("✗ Some bulk cost exponential tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_single_purchase() -> bool:
	print("Test: Single purchase (n=1)")
	
	# Create test upgrade
	var upgrade := UpgradeModel.new("test_bulk", "Test Bulk", "gold", 100.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.level = 5
	GameState.upgrades["test_bulk"] = upgrade
	
	# Calculate bulk cost for 1 level
	var bulk_cost := UpgradeService.compute_bulk_cost("test_bulk", 1)
	
	# Should equal the current cost
	var expected_cost := upgrade.get_current_cost()
	
	if abs(bulk_cost - expected_cost) > 0.01:
		print("  ✗ Single purchase cost mismatch (expected %.2f, got %.2f)" % [expected_cost, bulk_cost])
		return false
	
	print("  ✓ Single purchase cost correct: %.2f" % bulk_cost)
	return true

func test_multiple_purchases() -> bool:
	print("\nTest: Multiple purchases")
	
	# Create fresh upgrade
	var upgrade := UpgradeModel.new("test_bulk2", "Test Bulk 2", "gold", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.level = 0
	GameState.upgrades["test_bulk2"] = upgrade
	
	# Calculate bulk cost for 10 levels
	var bulk_cost := UpgradeService.compute_bulk_cost("test_bulk2", 10)
	
	# Calculate iteratively for comparison
	var iterative_cost := 0.0
	for i in range(10):
		var temp_level: int = i
		var cost: float = upgrade.base_cost * pow(upgrade.cost_growth_factor, temp_level)
		iterative_cost += cost
	
	var difference := abs(bulk_cost - iterative_cost)
	if difference > 0.01:
		print("  ✗ Bulk cost differs from iterative (formula: %.2f, iterative: %.2f, diff: %.4f)" % 
			[bulk_cost, iterative_cost, difference])
		return false
	
	print("  ✓ Bulk cost matches iterative: %.2f (diff: %.4f)" % [bulk_cost, difference])
	return true

func test_formula_accuracy() -> bool:
	print("\nTest: Formula accuracy for various scenarios")
	
	var scenarios := [
		{"base": 100.0, "growth": 1.15, "level": 0, "quantity": 5},
		{"base": 50.0, "growth": 1.2, "level": 10, "quantity": 20},
		{"base": 1000.0, "growth": 1.1, "level": 25, "quantity": 15}
	]
	
	for scenario in scenarios:
		var upgrade := UpgradeModel.new("test_scenario", "Test", "gold", scenario["base"], true)
		upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
		upgrade.cost_growth_factor = scenario["growth"]
		upgrade.level = scenario["level"]
		GameState.upgrades["test_scenario"] = upgrade
		
		# Bulk formula cost
		var bulk_cost := UpgradeService.compute_bulk_cost("test_scenario", scenario["quantity"])
		
		# Iterative cost
		var iterative_cost := 0.0
		for i in range(scenario["quantity"]):
			var temp_level: int = int(scenario["level"]) + i
			var cost: float = float(scenario["base"]) * pow(float(scenario["growth"]), temp_level)
			iterative_cost += cost
		
		var difference := abs(bulk_cost - iterative_cost)
		if difference > 0.01:
			print("  ✗ Scenario failed (base: %.0f, growth: %.2f, level: %d, qty: %d)" % 
				[scenario["base"], scenario["growth"], scenario["level"], scenario["quantity"]])
			print("    Formula: %.2f, Iterative: %.2f, Diff: %.4f" % [bulk_cost, iterative_cost, difference])
			return false
	
	print("  ✓ Formula accurate for all scenarios")
	return true
