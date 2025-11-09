## Test Essence Gain Multiplier Integration: Verify meta upgrade affects essence gain
## 
## Tests that essence_gain_multiplier meta upgrade increases prestige essence gain.

extends SceneTree

func _init() -> void:
	print("=== Running Essence Gain Multiplier Integration Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Base essence gain without multiplier
	all_passed = test_base_essence_gain() and all_passed
	
	# Test 2: Essence gain with multiplier
	all_passed = test_essence_gain_with_multiplier() and all_passed
	
	# Test 3: Multiple levels stack
	all_passed = test_multiple_levels_stack() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All essence gain multiplier integration tests passed!")
	else:
		print("✗ Some essence gain multiplier integration tests failed")
	
	quit(0 if all_passed else 1)

func test_base_essence_gain() -> bool:
	print("Test: Base essence gain without multiplier")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.lifetime_gold = 10_000_000.0  # 10M gold
	GameState.total_prestiges = 0
	
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Calculate base essence gain
	# Formula: floor((10_000_000 / 1_000_000)^0.6) = floor(10^0.6) ≈ floor(3.981) = 3
	var base_gain := PrestigeService.preview_essence_gain()
	
	if base_gain != 3:
		print("  ✗ Expected base gain 3, got %d" % base_gain)
		return false
	
	print("  ✓ Base essence gain: %d" % base_gain)
	return true

func test_essence_gain_with_multiplier() -> bool:
	print("\nTest: Essence gain increases with multiplier")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.lifetime_gold = 10_000_000.0  # 10M gold
	GameState.total_prestiges = 10
	
	# Set essence_mastery to level 10
	# essence_mastery: effect_per_level = 0.01, so level 10 = 0.1 (10% multiplier)
	GameState.meta_upgrades["essence_mastery"] = 10
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Verify meta effect cached
	var mult := GameState.meta_effects_cache.get("essence_gain_multiplier", 0.0)
	if not is_equal_approx(mult, 0.1):
		print("  ✗ Expected essence_gain_multiplier 0.1, got %.3f" % mult)
		return false
	
	# Calculate essence gain with multiplier
	# Base: floor(3.981) = 3
	# With mult: floor(3.981 * 1.1) = floor(4.379) = 4
	var gain_with_mult := PrestigeService.preview_essence_gain()
	
	if gain_with_mult != 4:
		print("  ✗ Expected gain with multiplier 4, got %d" % gain_with_mult)
		return false
	
	print("  ✓ Essence gain with 10%% multiplier: %d (up from 3)" % gain_with_mult)
	return true

func test_multiple_levels_stack() -> bool:
	print("\nTest: Multiple levels of essence_mastery stack")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.lifetime_gold = 10_000_000.0  # 10M gold
	GameState.total_prestiges = 10
	
	# Set essence_mastery to level 20
	# essence_mastery: effect_per_level = 0.01, so level 20 = 0.2 (20% multiplier)
	GameState.meta_upgrades["essence_mastery"] = 20
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Verify meta effect cached
	var mult := GameState.meta_effects_cache.get("essence_gain_multiplier", 0.0)
	if not is_equal_approx(mult, 0.2):
		print("  ✗ Expected essence_gain_multiplier 0.2, got %.3f" % mult)
		return false
	
	# Calculate essence gain with 20% multiplier
	# Base: floor(3.981) = 3
	# With mult: floor(3.981 * 1.2) = floor(4.777) = 4
	var gain_with_mult := PrestigeService.preview_essence_gain()
	
	if gain_with_mult != 4:
		print("  ✗ Expected gain with 20%% multiplier 4, got %d" % gain_with_mult)
		return false
	
	print("  ✓ Essence gain with 20%% multiplier: %d" % gain_with_mult)
	return true
