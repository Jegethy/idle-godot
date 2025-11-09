## Test Prestige Reset: Validate prestige reset behavior
## 
## Tests that perform_prestige properly resets resources, upgrades,
## and items while preserving essence and lifetime_gold.

extends SceneTree

func _init() -> void:
	print("=== Running Prestige Reset Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Gold resets to 0
	all_passed = test_gold_resets_to_zero() and all_passed
	
	# Test 2: Upgrades reset to level 0
	all_passed = test_upgrades_reset_to_zero() and all_passed
	
	# Test 3: Essence increases by expected amount
	all_passed = test_essence_increases() and all_passed
	
	# Test 4: Lifetime gold unchanged
	all_passed = test_lifetime_gold_retained() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All prestige reset tests passed!")
	else:
		print("✗ Some prestige reset tests failed")
	
	quit(0 if all_passed else 1)

func test_gold_resets_to_zero() -> bool:
	print("Test: Gold resets to 0 after prestige")
	
	# Setup: Set gold to a high value
	if GameState.resources.has("gold"):
		GameState.resources["gold"].amount = 5_000_000.0
		GameState.lifetime_gold = 5_000_000.0
	
	var gold_before: float = GameState.resources["gold"].amount
	
	# Perform prestige
	var result := PrestigeService.perform_prestige()
	
	if not result.get("success", false):
		print("  ✗ Prestige failed (requirements not met?)")
		return false
	
	var gold_after: float = GameState.resources["gold"].amount
	
	if gold_after != 0.0:
		print("  ✗ Gold not reset (was %.0f, now %.0f)" % [gold_before, gold_after])
		return false
	
	print("  ✓ Gold reset from %.0f to 0" % gold_before)
	return true

func test_upgrades_reset_to_zero() -> bool:
	print("\nTest: Upgrades reset to level 0 after prestige")
	
	# Setup: Set some upgrades to non-zero levels
	var upgrade_count := 0
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		upgrade.level = 5
		upgrade_count += 1
		if upgrade_count >= 3:
			break
	
	if upgrade_count == 0:
		print("  ⚠ No upgrades available to test")
		return true
	
	# Setup gold and lifetime_gold for prestige
	if GameState.resources.has("gold"):
		GameState.resources["gold"].amount = 5_000_000.0
		GameState.lifetime_gold = 10_000_000.0
	
	# Perform prestige
	var result := PrestigeService.perform_prestige()
	
	if not result.get("success", false):
		print("  ✗ Prestige failed")
		return false
	
	# Check all upgrades are level 0
	var all_zero := true
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		if upgrade.level != 0:
			print("  ✗ Upgrade '%s' not reset (level %d)" % [upgrade_id, upgrade.level])
			all_zero = false
	
	if not all_zero:
		return false
	
	print("  ✓ All upgrades reset to level 0")
	return true

func test_essence_increases() -> bool:
	print("\nTest: Essence increases by expected amount")
	
	# Setup: Set initial state
	GameState.essence = 10.0
	if GameState.resources.has("gold"):
		GameState.resources["gold"].amount = 5_000_000.0
		GameState.lifetime_gold = 5_000_000.0
	
	var essence_before: float = GameState.essence
	var expected_gain: int = PrestigeService.preview_essence_gain()
	
	# Perform prestige
	var result := PrestigeService.perform_prestige()
	
	if not result.get("success", false):
		print("  ✗ Prestige failed")
		return false
	
	var essence_after: float = GameState.essence
	var actual_gain: float = essence_after - essence_before
	
	if int(actual_gain) != expected_gain:
		print("  ✗ Essence gain mismatch (expected %d, got %.0f)" % [expected_gain, actual_gain])
		return false
	
	print("  ✓ Essence increased from %.0f to %.0f (+%d)" % [essence_before, essence_after, expected_gain])
	return true

func test_lifetime_gold_retained() -> bool:
	print("\nTest: Lifetime gold retained after prestige")
	
	# Setup
	if GameState.resources.has("gold"):
		GameState.resources["gold"].amount = 3_000_000.0
		GameState.lifetime_gold = 8_000_000.0
	
	var lifetime_before: float = GameState.lifetime_gold
	
	# Perform prestige
	var result := PrestigeService.perform_prestige()
	
	if not result.get("success", false):
		print("  ✗ Prestige failed")
		return false
	
	var lifetime_after: float = GameState.lifetime_gold
	
	if lifetime_after != lifetime_before:
		print("  ✗ Lifetime gold changed (was %.0f, now %.0f)" % [lifetime_before, lifetime_after])
		return false
	
	print("  ✓ Lifetime gold retained: %.0f" % lifetime_after)
	return true
