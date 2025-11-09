## Test Sync Levels Invocation: Verify MetaUpgradeService.sync_levels_from_game_state() 
## is called via instance, not static
## 
## Tests that the method is called through the autoload instance.

extends SceneTree

func _init() -> void:
	print("=== Running Sync Levels Invocation Tests ===\n")
	
	var all_passed := true
	
	# Test 1: MetaUpgradeService is an autoload Node
	print("Test 1: MetaUpgradeService is an autoload Node")
	var passed := test_meta_service_is_node()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 2: sync_levels_from_game_state method exists
	print("Test 2: sync_levels_from_game_state method exists")
	passed = test_sync_method_exists()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 3: Can call sync_levels_from_game_state without error
	print("Test 3: Can call sync_levels_from_game_state")
	passed = test_can_call_sync()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Summary
	print("=== Summary ===")
	if all_passed:
		print("✓ All sync levels invocation tests passed!")
		quit(0)
	else:
		print("✗ Some sync levels invocation tests failed")
		quit(1)

func test_meta_service_is_node() -> bool:
	# MetaUpgradeService should be accessible as an autoload
	if not MetaUpgradeService:
		push_error("MetaUpgradeService autoload not found")
		return false
	
	# It should be a Node (not just a class)
	if not MetaUpgradeService is Node:
		push_error("MetaUpgradeService is not a Node instance")
		return false
	
	print("  ✓ MetaUpgradeService is a Node instance")
	return true

func test_sync_method_exists() -> bool:
	# Check method exists
	if not MetaUpgradeService.has_method("sync_levels_from_game_state"):
		push_error("MetaUpgradeService missing sync_levels_from_game_state method")
		return false
	
	print("  ✓ sync_levels_from_game_state method exists")
	return true

func test_can_call_sync() -> bool:
	# Initialize GameState with some meta upgrades
	GameState.meta_upgrades = {
		"idle_rate_boost": 2,
		"essence_multiplier": 1
	}
	
	# Call the method (should not error)
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Verify levels were synced to definitions
	var idle_boost_def = MetaUpgradeService.get_upgrade("idle_rate_boost")
	if idle_boost_def and idle_boost_def.current_level != 2:
		push_error("Sync failed: idle_rate_boost level not synced correctly")
		return false
	
	print("  ✓ sync_levels_from_game_state executed successfully")
	return true
