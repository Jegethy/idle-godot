## Test ROI Sorting: Verify ROI calculations and ranking
## 
## Tests that upgrades are correctly sorted by return on investment.

extends SceneTree

func _init() -> void:
	print("=== Running ROI Sorting Tests ===\n")
	
	var all_passed := true
	
	# Test 1: ROI calculation for different upgrade types
	all_passed = test_roi_calculation() and all_passed
	
	# Test 2: Ranking sorts by ROI descending
	all_passed = test_roi_ranking() and all_passed
	
	# Test 3: Maxed upgrades have 0 ROI
	all_passed = test_maxed_upgrade_roi() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All ROI sorting tests passed!")
	else:
		print("✗ Some ROI sorting tests failed")
	
	quit(0 if all_passed else 1)

func test_roi_calculation() -> bool:
	print("Test: ROI calculation for different upgrade types")
	
	# Reset and sync
	GameState.meta_upgrades.clear()
	GameState.essence = 10000.0
	GameState.total_prestiges = 10
	MetaUpgradeService.sync_levels_from_game_state()
	
	var current_idle_rate := 100.0
	
	# Test idle_rate_multiplier ROI
	# idle_core: effect=0.02, cost(0)=10
	# ROI = (0.02 * 100) / 10 = 2.0 / 10 = 0.2
	var idle_core_roi := MetaUpgradeService.compute_roi("idle_core", current_idle_rate)
	var expected_idle_roi := (0.02 * current_idle_rate) / 10.0
	
	if not is_equal_approx(idle_core_roi, expected_idle_roi):
		print("  ✗ Expected idle_core ROI %.3f, got %.3f" % [expected_idle_roi, idle_core_roi])
		return false
	
	# Test idle_rate_add ROI
	# idle_boost: effect=0.5, cost(0)=15
	# ROI = 0.5 / 15 ≈ 0.033
	var idle_boost_roi := MetaUpgradeService.compute_roi("idle_boost", current_idle_rate)
	var expected_boost_roi := 0.5 / 15.0
	
	if not is_equal_approx(idle_boost_roi, expected_boost_roi):
		print("  ✗ Expected idle_boost ROI %.3f, got %.3f" % [expected_boost_roi, idle_boost_roi])
		return false
	
	# Test combat ROI (uses different scaling)
	# combat_edge: effect=0.015, cost(0)=25
	# ROI = (0.015 * 5.0) / 25 = 0.075 / 25 = 0.003
	var combat_edge_roi := MetaUpgradeService.compute_roi("combat_edge", current_idle_rate)
	var expected_combat_roi := (0.015 * 5.0) / 25.0
	
	if not is_equal_approx(combat_edge_roi, expected_combat_roi):
		print("  ✗ Expected combat_edge ROI %.3f, got %.3f" % [expected_combat_roi, combat_edge_roi])
		return false
	
	print("  ✓ ROI calculations correct")
	return true

func test_roi_ranking() -> bool:
	print("\nTest: Upgrades ranked by ROI descending")
	
	# Reset and sync
	GameState.meta_upgrades.clear()
	GameState.essence = 10000.0
	GameState.total_prestiges = 10
	MetaUpgradeService.sync_levels_from_game_state()
	
	var current_idle_rate := 100.0
	
	# Get all upgrade IDs
	var upgrade_ids := []
	for id in MetaUpgradeService.definitions.keys():
		upgrade_ids.append(id)
	
	# Rank them
	var ranked := MetaProjection.rank_upgrades_by_roi(upgrade_ids, current_idle_rate, MetaUpgradeService)
	
	# Verify sorted descending
	for i in range(ranked.size() - 1):
		var current_roi: float = ranked[i]["roi"]
		var next_roi: float = ranked[i + 1]["roi"]
		
		if current_roi < next_roi:
			print("  ✗ ROI not sorted descending at index %d (%.3f < %.3f)" % [i, current_roi, next_roi])
			return false
	
	print("  ✓ Upgrades ranked by ROI descending (%d upgrades)" % ranked.size())
	
	# Display top 3 for reference
	print("  Top 3 by ROI:")
	for i in range(min(3, ranked.size())):
		var entry = ranked[i]
		print("    %d. %s (ROI: %.3f)" % [i+1, entry["name"], entry["roi"]])
	
	return true

func test_maxed_upgrade_roi() -> bool:
	print("\nTest: Maxed upgrades have 0 ROI")
	
	# Reset and sync
	GameState.meta_upgrades.clear()
	GameState.essence = 10000.0
	GameState.total_prestiges = 10
	
	# Get idle_core and set it to max level
	var upgrade := MetaUpgradeService.get_upgrade("idle_core")
	if not upgrade:
		print("  ✗ idle_core upgrade not found")
		return false
	
	# Set to max level
	upgrade.current_level = upgrade.max_level
	GameState.meta_upgrades["idle_core"] = upgrade.max_level
	MetaUpgradeService.sync_levels_from_game_state()
	
	# Compute ROI
	var roi := MetaUpgradeService.compute_roi("idle_core", 100.0)
	
	if not is_equal_approx(roi, 0.0):
		print("  ✗ Expected ROI 0.0 for maxed upgrade, got %.3f" % roi)
		return false
	
	print("  ✓ Maxed upgrade has 0 ROI")
	return true
