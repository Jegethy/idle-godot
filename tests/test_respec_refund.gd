## Test Respec Refund: Verify respec mechanics and refund calculations
## 
## Tests that respec returns correct percentage and resets levels.

extends SceneTree

func _init() -> void:
	print("=== Running Respec Refund Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Respec refunds correct percentage
	all_passed = test_respec_refund_percentage() and all_passed
	
	# Test 2: Respec resets all levels to 0
	all_passed = test_respec_resets_levels() and all_passed
	
	# Test 3: Respec cooldown enforced
	all_passed = test_respec_cooldown() and all_passed
	
	# Test 4: Respec with no upgrades returns 0
	all_passed = test_respec_empty() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All respec refund tests passed!")
	else:
		print("✗ Some respec refund tests failed")
	
	quit(0 if all_passed else 1)

func test_respec_refund_percentage() -> bool:
	print("Test: Respec refunds correct percentage (60%)")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 0
	GameState.essence_spent = 0.0
	GameState.last_respec_time = 0
	
	# Level up idle_core multiple times
	# idle_core: base_cost=10, growth=1.18
	# cost(0) = 10, cost(1) = 11.8, cost(2) = 13.924
	MetaUpgradeService.sync_levels_from_game_state()
	
	var initial_essence := GameState.essence
	
	# Level 1
	MetaUpgradeService.level_up("idle_core")
	# Level 2
	MetaUpgradeService.level_up("idle_core")
	# Level 3
	MetaUpgradeService.level_up("idle_core")
	
	var spent := initial_essence - GameState.essence
	var expected_refund := spent * BalanceConstants.META_REFUND_RATE
	
	# Perform respec
	var result := MetaUpgradeService.respec_all()
	
	if not result.get("success", false):
		print("  ✗ Respec failed")
		return false
	
	var refunded := result.get("refunded", 0.0)
	
	if not is_equal_approx(refunded, expected_refund):
		print("  ✗ Expected refund %.2f (60%% of %.2f), got %.2f" % [expected_refund, spent, refunded])
		return false
	
	print("  ✓ Refunded %.2f essence (60%% of %.2f spent)" % [refunded, spent])
	return true

func test_respec_resets_levels() -> bool:
	print("\nTest: Respec resets all upgrade levels to 0")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.meta_effects_cache.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 10
	GameState.essence_spent = 0.0
	GameState.last_respec_time = 0
	
	# Level up multiple upgrades
	GameState.meta_upgrades["idle_core"] = 10
	GameState.meta_upgrades["combat_edge"] = 5
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Perform respec
	var result := MetaUpgradeService.respec_all()
	
	if not result.get("success", false):
		print("  ✗ Respec failed")
		return false
	
	# Verify all levels are 0
	if GameState.meta_upgrades.size() != 0:
		print("  ✗ meta_upgrades should be empty after respec")
		return false
	
	# Verify effect cache is cleared
	var idle_mult: float = float(GameState.meta_effects_cache.get(&"idle_rate_multiplier", 0.0))
	if not is_equal_approx(idle_mult, 0.0):
		print("  ✗ Effect cache should be cleared after respec")
		return false
	
	print("  ✓ All levels reset to 0")
	return true

func test_respec_cooldown() -> bool:
	print("\nTest: Respec cooldown enforced")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 0
	GameState.essence_spent = 0.0
	
	# Set last respec time to now
	GameState.last_respec_time = Time.get_unix_time_from_system()
	
	# Try to respec immediately (should fail due to cooldown)
	var result := MetaUpgradeService.respec_all()
	
	if result.get("success", false):
		print("  ✗ Respec should fail when on cooldown")
		return false
	
	if not result.has("cooldown_remaining"):
		print("  ✗ Respec result should include cooldown_remaining")
		return false
	
	# Set last respec time to past (cooldown expired)
	GameState.last_respec_time = Time.get_unix_time_from_system() - BalanceConstants.META_RESPEC_COOLDOWN_SEC - 1
	
	# Level up something first
	MetaUpgradeService.sync_levels_from_game_state()
	MetaUpgradeService.level_up("idle_core")
	
	# Try to respec again (should succeed)
	result = MetaUpgradeService.respec_all()
	
	if not result.get("success", false):
		print("  ✗ Respec should succeed after cooldown expired")
		return false
	
	print("  ✓ Cooldown enforced correctly")
	return true

func test_respec_empty() -> bool:
	print("\nTest: Respec with no upgrades returns 0 refund")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.essence = 1000.0
	GameState.essence_spent = 0.0
	GameState.last_respec_time = 0
	
	# Perform respec with no upgrades
	var result := MetaUpgradeService.respec_all()
	
	if not result.get("success", false):
		print("  ✗ Respec should succeed even with no upgrades")
		return false
	
	var refunded := result.get("refunded", -1.0)
	if not is_equal_approx(refunded, 0.0):
		print("  ✗ Expected 0 refund, got %.2f" % refunded)
		return false
	
	print("  ✓ Empty respec returns 0 refund")
	return true
