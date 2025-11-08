## Test Validation Script
## 
## This script validates the basic functionality of the core systems.
## Run from the Godot editor via Tools -> Script -> Run.

extends SceneTree

func _init() -> void:
	print("=== Running PR1 Validation Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Verify singletons are loaded
	all_passed = test_singletons_loaded() and all_passed
	
	# Test 2: Verify resource model
	all_passed = test_resource_model() and all_passed
	
	# Test 3: Verify upgrade model
	all_passed = test_upgrade_model() and all_passed
	
	# Test 4: Verify economy calculations
	all_passed = test_economy_calculations() and all_passed
	
	# Test 5: Verify save/load schema
	all_passed = test_save_schema() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All tests passed!")
	else:
		print("✗ Some tests failed")
	
	quit(0 if all_passed else 1)

func test_singletons_loaded() -> bool:
	print("Test: Singletons loaded")
	var result := true
	
	if not is_instance_valid(GameState):
		print("  ✗ GameState not loaded")
		result = false
	else:
		print("  ✓ GameState loaded")
	
	if not is_instance_valid(Economy):
		print("  ✗ Economy not loaded")
		result = false
	else:
		print("  ✓ Economy loaded")
	
	if not is_instance_valid(TimeService):
		print("  ✗ TimeService not loaded")
		result = false
	else:
		print("  ✓ TimeService loaded")
	
	return result

func test_resource_model() -> bool:
	print("\nTest: Resource Model")
	var resource := ResourceModel.new("test", "Test Resource", 5.0, true)
	
	if resource.id != "test":
		print("  ✗ ID not set correctly")
		return false
	
	if resource.base_rate != 5.0:
		print("  ✗ Base rate not set correctly")
		return false
	
	resource.add_modifier(2.0)
	resource.add_modifier(3.0)
	
	if resource.get_total_rate() != 10.0:
		print("  ✗ Total rate calculation failed (expected 10.0, got %.1f)" % resource.get_total_rate())
		return false
	
	print("  ✓ Resource model working correctly")
	return true

func test_upgrade_model() -> bool:
	print("\nTest: Upgrade Model")
	var upgrade := UpgradeModel.new("test_upgrade", "Test Upgrade", "gold", 100.0, true)
	upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
	upgrade.cost_growth_factor = 1.5
	
	# Level 0 should cost 100
	if upgrade.get_current_cost() != 100.0:
		print("  ✗ Initial cost incorrect (expected 100.0, got %.1f)" % upgrade.get_current_cost())
		return false
	
	# Level 1 should cost 150
	upgrade.level = 1
	if abs(upgrade.get_current_cost() - 150.0) > 0.01:
		print("  ✗ Level 1 cost incorrect (expected 150.0, got %.1f)" % upgrade.get_current_cost())
		return false
	
	print("  ✓ Upgrade model working correctly")
	return true

func test_economy_calculations() -> bool:
	print("\nTest: Economy Calculations")
	
	# Create a test resource
	var resource := ResourceModel.new("test_econ", "Test", 10.0, true)
	
	# Calculate income (should be 10.0 * 1.0 multiplier)
	var income := Economy.calculate_income_per_second(resource)
	if income != 10.0:
		print("  ✗ Income calculation incorrect (expected 10.0, got %.1f)" % income)
		return false
	
	# Test prestige calculation
	var essence := Economy.calculate_prestige_essence(2_000_000.0)
	var expected := floor(pow(2.0, 0.6))  # (2_000_000 / 1_000_000) ^ 0.6
	if essence != expected:
		print("  ✗ Prestige essence calculation incorrect (expected %.0f, got %.0f)" % [expected, essence])
		return false
	
	print("  ✓ Economy calculations working correctly")
	return true

func test_save_schema() -> bool:
	print("\nTest: Save Schema")
	
	var schema := SaveSchemaModel.new()
	schema.resources = {"gold": {"amount": 100.0}}
	schema.essence = 5.0
	
	var dict := schema.to_dict()
	
	if not dict.has("version"):
		print("  ✗ Schema missing version")
		return false
	
	if not dict.has("timestamp"):
		print("  ✗ Schema missing timestamp")
		return false
	
	if not dict.has("resources"):
		print("  ✗ Schema missing resources")
		return false
	
	# Test deserialization
	var new_schema := SaveSchemaModel.new()
	new_schema.from_dict(dict)
	
	if new_schema.essence != 5.0:
		print("  ✗ Schema deserialization failed")
		return false
	
	print("  ✓ Save schema working correctly")
	return true
