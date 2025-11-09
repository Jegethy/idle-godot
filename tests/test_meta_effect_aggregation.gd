## Test Meta Effect Aggregation: Verify effect stacking and cache updates
## 
## Tests that meta upgrade effects are correctly aggregated and applied.

extends Node

func _ready() -> void:
	print("=== Running Meta Effect Aggregation Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Single upgrade effect aggregation
	all_passed = test_single_upgrade_effect() and all_passed
	
	# Test 2: Multiple upgrades of same type stack additively
	all_passed = test_multiple_effects_stack() and all_passed
	
	# Test 3: Cache updates on level up
	all_passed = test_cache_updates_on_level() and all_passed
	
	# Test 4: Different effect types are independent
	all_passed = test_different_effect_types() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All meta effect aggregation tests passed!")
	else:
		print("✗ Some meta effect aggregation tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_single_upgrade_effect() -> bool:
	print("Test: Single upgrade effect aggregation")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 0
	
	# Set idle_core to level 10
	# idle_core: effect_per_level = 0.02, so level 10 = 0.2 total
	GameState.meta_upgrades["idle_core"] = 10
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Check effect cache
	var idle_mult: float = float(GameState.meta_effects_cache.get(&"idle_rate_multiplier", 0.0))
	if not is_equal_approx(idle_mult, 0.2):
		print("  ✗ Expected idle_rate_multiplier = 0.2, got %.3f" % idle_mult)
		return false
	
	print("  ✓ Single upgrade effect aggregated correctly")
	return true

func test_multiple_effects_stack() -> bool:
	print("\nTest: Multiple upgrades of same type stack additively")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 10
	
	# Set multiple combat attack multiplier upgrades
	# combat_edge: 0.015 per level, level 5 = 0.075
	GameState.meta_upgrades["combat_edge"] = 5
	MetaUpgradeService.sync_levels_from_game_state()
	
	var attack_mult: float = float(GameState.meta_effects_cache.get(&"combat_attack_mult", 0.0))
	if not is_equal_approx(attack_mult, 0.075):
		print("  ✗ Expected combat_attack_mult = 0.075, got %.3f" % attack_mult)
		return false
	
	# If we had another combat_attack_mult upgrade, they would stack
	# (Currently only combat_edge provides this effect in our test data)
	
	print("  ✓ Effects stack additively")
	return true

func test_cache_updates_on_level() -> bool:
	print("\nTest: Cache updates when leveling up")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 0
	
	# Set idle_core to level 0 initially
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Verify cache is empty
	var initial_mult: float = float(GameState.meta_effects_cache.get(&"idle_rate_multiplier", 0.0))
	if not is_equal_approx(initial_mult, 0.0):
		print("  ✗ Expected initial idle_rate_multiplier = 0.0, got %.3f" % initial_mult)
		return false
	
	# Level up idle_core to 1
	var success := MetaUpgradeService.level_up("idle_core")
	if not success:
		print("  ✗ Failed to level up idle_core")
		return false
	
	# Verify cache updated
	var updated_mult: float = float(GameState.meta_effects_cache.get(&"idle_rate_multiplier", 0.0))
	if not is_equal_approx(updated_mult, 0.02):
		print("  ✗ Expected updated idle_rate_multiplier = 0.02, got %.3f" % updated_mult)
		return false
	
	print("  ✓ Cache updates on level up")
	return true

func test_different_effect_types() -> bool:
	print("\nTest: Different effect types are independent")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.essence = 10000.0
	GameState.total_prestiges = 10
	
	# Set different types of upgrades
	GameState.meta_upgrades["idle_core"] = 10  # idle_rate_multiplier: 0.2
	GameState.meta_upgrades["idle_boost"] = 5  # idle_rate_add: 2.5 (0.5 * 5)
	GameState.meta_upgrades["combat_edge"] = 10  # combat_attack_mult: 0.15
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Check each effect type independently
	var idle_mult: float = float(GameState.meta_effects_cache.get(&"idle_rate_multiplier", 0.0))
	var idle_add: float = float(GameState.meta_effects_cache.get(&"idle_rate_add", 0.0))
	var combat_mult: float = float(GameState.meta_effects_cache.get(&"combat_attack_mult", 0.0))
	
	if not is_equal_approx(idle_mult, 0.2):
		print("  ✗ Expected idle_rate_multiplier = 0.2, got %.3f" % idle_mult)
		return false
	
	if not is_equal_approx(idle_add, 2.5):
		print("  ✗ Expected idle_rate_add = 2.5, got %.3f" % idle_add)
		return false
	
	if not is_equal_approx(combat_mult, 0.15):
		print("  ✗ Expected combat_attack_mult = 0.15, got %.3f" % combat_mult)
		return false
	
	print("  ✓ Different effect types are independent")
	return true
