## Test PR4 Integration: Validates new UI and services work together
## 
## Tests NumberFormatter, UpgradeService, and basic integration.

extends SceneTree

func _init() -> void:
	print("=== Running PR4 Integration Tests ===\n")
	
	var all_passed := true
	
	# Test 1: NumberFormatter is available
	all_passed = test_number_formatter() and all_passed
	
	# Test 2: UpgradeService is available
	all_passed = test_upgrade_service() and all_passed
	
	# Test 3: UnlockService is available
	all_passed = test_unlock_service() and all_passed
	
	# Test 4: Basic bulk purchase integration
	all_passed = test_bulk_purchase_integration() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All PR4 integration tests passed!")
	else:
		print("✗ Some PR4 integration tests failed")
	
	quit(0 if all_passed else 1)

func test_number_formatter() -> bool:
	print("Test: NumberFormatter available")
	
	# Test basic formatting
	var result := NumberFormatter.format_short(1234.0)
	if result != "1.23K":
		print("  ✗ NumberFormatter not working correctly (expected '1.23K', got '%s')" % result)
		return false
	
	print("  ✓ NumberFormatter working")
	return true

func test_upgrade_service() -> bool:
	print("\nTest: UpgradeService available")
	
	if not is_instance_valid(UpgradeService):
		print("  ✗ UpgradeService not loaded")
		return false
	
	# Test that compute_bulk_cost exists
	var upgrade := UpgradeModel.new("test", "Test", "gold", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.level = 0
	GameState.upgrades["test"] = upgrade
	
	var cost := UpgradeService.compute_bulk_cost("test", 1)
	if cost != 10.0:
		print("  ✗ UpgradeService compute_bulk_cost not working (expected 10.0, got %.2f)" % cost)
		return false
	
	print("  ✓ UpgradeService working")
	return true

func test_unlock_service() -> bool:
	print("\nTest: UnlockService available")
	
	if not is_instance_valid(UnlockService):
		print("  ✗ UnlockService not loaded")
		return false
	
	print("  ✓ UnlockService working")
	return true

func test_bulk_purchase_integration() -> bool:
	print("\nTest: Bulk purchase integration")
	
	# Setup
	var gold := ResourceModel.new("gold", "Gold", 0.0, true)
	gold.amount = 1000.0
	GameState.resources["gold"] = gold
	
	var upgrade := UpgradeModel.new("test_bulk_int", "Test Bulk", "gold", 10.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.15
	upgrade.level = 0
	upgrade.base_bonus = 1.0
	upgrade.type = UpgradeModel.UpgradeType.RATE
	GameState.upgrades["test_bulk_int"] = upgrade
	
	# Purchase 5 levels
	var initial_gold := gold.amount
	var success := UpgradeService.buy_upgrade("test_bulk_int", 5)
	
	if not success:
		print("  ✗ Bulk purchase failed")
		return false
	
	if upgrade.level != 5:
		print("  ✗ Level not incremented correctly (expected 5, got %d)" % upgrade.level)
		return false
	
	# Check that gold was deducted
	var expected_cost := UpgradeService.compute_bulk_cost("test_bulk_int", 5)
	# Note: we need to compute at level 0, not current level
	upgrade.level = 0
	expected_cost = UpgradeService.compute_bulk_cost("test_bulk_int", 5)
	upgrade.level = 5  # Restore
	
	var gold_spent := initial_gold - gold.amount
	if abs(gold_spent - expected_cost) > 0.01:
		print("  ✗ Gold deduction incorrect (spent %.2f, expected %.2f)" % [gold_spent, expected_cost])
		return false
	
	print("  ✓ Bulk purchase integration working (purchased 5 levels for %.2f gold)" % gold_spent)
	return true
