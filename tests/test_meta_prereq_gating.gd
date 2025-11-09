## Test Meta Prerequisite Gating: Verify prerequisite validation
## 
## Tests that upgrades cannot be leveled without meeting prerequisites.

extends SceneTree

func _init() -> void:
	print("=== Running Meta Prerequisite Gating Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Cannot level without prerequisite
	all_passed = test_cannot_level_without_prereq() and all_passed
	
	# Test 2: Can level after meeting prerequisite
	all_passed = test_can_level_after_prereq_met() and all_passed
	
	# Test 3: Total prestiges requirement
	all_passed = test_total_prestiges_requirement() and all_passed
	
	# Test 4: Multiple prerequisites
	all_passed = test_multiple_prerequisites() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All meta prerequisite gating tests passed!")
	else:
		print("✗ Some meta prerequisite gating tests failed")
	
	quit(0 if all_passed else 1)

func test_cannot_level_without_prereq() -> bool:
	print("Test: Cannot level upgrade without prerequisite")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 10
	
	# Get combat_edge which requires idle_core:5
	var combat_edge := MetaUpgradeService.get_upgrade("combat_edge")
	if not combat_edge:
		print("  ✗ combat_edge upgrade not found")
		return false
	
	# Verify prerequisite exists
	if combat_edge.prerequisites.size() == 0:
		print("  ✗ combat_edge should have prerequisites")
		return false
	
	# Try to level without meeting prerequisite
	if MetaUpgradeService.can_level("combat_edge"):
		print("  ✗ Should not be able to level combat_edge without idle_core:5")
		return false
	
	print("  ✓ Cannot level without prerequisite")
	return true

func test_can_level_after_prereq_met() -> bool:
	print("\nTest: Can level upgrade after prerequisite met")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 10
	
	# Set idle_core to level 5 (meets combat_edge prerequisite)
	GameState.meta_upgrades["idle_core"] = 5
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Now should be able to level combat_edge
	if not MetaUpgradeService.can_level("combat_edge"):
		print("  ✗ Should be able to level combat_edge after idle_core:5")
		return false
	
	# Actually level it
	var success := MetaUpgradeService.level_up("combat_edge")
	if not success:
		print("  ✗ Failed to level up combat_edge")
		return false
	
	# Verify level increased
	var level := GameState.meta_upgrades.get("combat_edge", 0)
	if level != 1:
		print("  ✗ Expected combat_edge level 1, got %d" % level)
		return false
	
	print("  ✓ Can level after prerequisite met")
	return true

func test_total_prestiges_requirement() -> bool:
	print("\nTest: Total prestiges requirement enforced")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 1  # combat_edge requires 2
	
	# Set prerequisite
	GameState.meta_upgrades["idle_core"] = 5
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Should not be able to level (not enough prestiges)
	if MetaUpgradeService.can_level("combat_edge"):
		print("  ✗ Should not be able to level combat_edge with only 1 prestige")
		return false
	
	# Increase prestiges
	GameState.total_prestiges = 2
	
	# Now should be able to level
	if not MetaUpgradeService.can_level("combat_edge"):
		print("  ✗ Should be able to level combat_edge with 2 prestiges")
		return false
	
	print("  ✓ Total prestiges requirement enforced")
	return true

func test_multiple_prerequisites() -> bool:
	print("\nTest: Multiple prerequisites must all be met")
	
	# Reset GameState
	GameState.meta_upgrades.clear()
	GameState.essence = 1000.0
	GameState.total_prestiges = 10
	
	# critical_power requires critical_insight:10
	# critical_insight requires combat_edge:10
	
	# Set combat_edge to 10
	GameState.meta_upgrades["combat_edge"] = 10
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Should be able to level critical_insight now
	if not MetaUpgradeService.can_level("critical_insight"):
		print("  ✗ Should be able to level critical_insight with combat_edge:10")
		return false
	
	# Set critical_insight to 5 (not enough for critical_power)
	GameState.meta_upgrades["critical_insight"] = 5
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Should NOT be able to level critical_power
	if MetaUpgradeService.can_level("critical_power"):
		print("  ✗ Should not be able to level critical_power with critical_insight:5")
		return false
	
	# Set critical_insight to 10
	GameState.meta_upgrades["critical_insight"] = 10
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Now should be able to level critical_power
	if not MetaUpgradeService.can_level("critical_power"):
		print("  ✗ Should be able to level critical_power with critical_insight:10")
		return false
	
	print("  ✓ Multiple prerequisites enforced correctly")
	return true
