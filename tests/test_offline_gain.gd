## Test Offline Gain: Test offline progression calculations
## 
## Validates that offline progression grants correct resources based on time away.

extends Node

const TOLERANCE := 1.0  # Allow 1 gold tolerance for offline calculations

func _ready() -> void:
	print("=== Running Offline Gain Tests ===\n")
	
	var all_passed := true
	
	# Test 1: 1 hour offline with known rate
	all_passed = test_offline_gain_1_hour() and all_passed
	
	# Test 2: 12 hours offline (exceeds 8 hour cap)
	all_passed = test_offline_gain_exceeds_cap() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All offline gain tests passed!")
	else:
		print("✗ Some offline gain tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_offline_gain_1_hour() -> bool:
	print("Test: 1 hour offline progression with known rate")
	
	# Reset gold to 0
	if not GameState.resources.has("gold"):
		print("  ✗ Gold resource not found")
		return false
	
	GameState.resources["gold"].amount = 0.0
	
	# Set up an upgrade to give a known rate
	# Find a rate upgrade for gold
	var rate_upgrade_id := ""
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		if upgrade.target == "gold" and upgrade.type == UpgradeModel.UpgradeType.RATE:
			rate_upgrade_id = upgrade_id
			break
	
	if rate_upgrade_id == "":
		print("  ✗ No rate upgrade found for gold")
		return false
	
	# Set upgrade to level that gives 3/sec
	# If base_bonus is 2.0 and we want 3/sec total with base_rate 1.0:
	# effective_rate = base_rate + (base_bonus * level) = 1.0 + (2.0 * level)
	# For 3/sec: 1.0 + 2.0 * level = 3.0 → level = 1
	var upgrade: UpgradeModel = GameState.upgrades[rate_upgrade_id]
	var desired_rate := 3.0
	var base_rate := GameState.resources["gold"].base_rate
	var level_needed := int((desired_rate - base_rate) / upgrade.base_bonus)
	upgrade.level = level_needed
	
	# Recalculate rates
	Economy.recalculate_all_rates()
	
	# Verify the rate
	var actual_rate := Economy.get_per_second_rate("gold")
	print("  Setup: Gold rate is %.2f/sec (target: %.2f/sec)" % [actual_rate, desired_rate])
	
	# Simulate 1 hour (3600 seconds) offline
	var now := Time.get_unix_time_from_system()
	var one_hour_ago := now - 3600.0
	SaveSystem.last_saved_time = one_hour_ago
	
	# Apply offline progression
	TimeService.apply_offline_progression(now, Economy, GameState)
	
	# Expected gain: actual_rate * 3600 seconds
	var expected_gain := actual_rate * 3600.0
	var actual_gold := GameState.resources["gold"].amount
	
	if abs(actual_gold - expected_gain) > TOLERANCE:
		print("  ✗ Offline gain incorrect (expected %.2f, got %.2f)" % [expected_gain, actual_gold])
		return false
	
	print("  ✓ 1 hour offline gain correct (+%.2f gold)" % actual_gold)
	return true

func test_offline_gain_exceeds_cap() -> bool:
	print("\nTest: 12 hours offline (exceeds 8 hour cap)")
	
	# Reset gold to 0
	GameState.resources["gold"].amount = 0.0
	
	# Use same rate as before
	Economy.recalculate_all_rates()
	var rate := Economy.get_per_second_rate("gold")
	
	# Simulate 12 hours offline (should be capped at 8)
	var now := Time.get_unix_time_from_system()
	var twelve_hours_ago := now - (12.0 * 3600.0)
	SaveSystem.last_saved_time = twelve_hours_ago
	
	# Apply offline progression
	TimeService.apply_offline_progression(now, Economy, GameState)
	
	# Expected gain: rate * 8 hours (capped)
	var cap_hours := 8.0
	var expected_gain := rate * cap_hours * 3600.0
	var actual_gold := GameState.resources["gold"].amount
	
	if abs(actual_gold - expected_gain) > TOLERANCE:
		print("  ✗ Capped offline gain incorrect (expected %.2f for 8h cap, got %.2f)" % [expected_gain, actual_gold])
		return false
	
	print("  ✓ Offline gain correctly capped at 8 hours (+%.2f gold)" % actual_gold)
	return true
