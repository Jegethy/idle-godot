## Test Loadout Simulation: Verify DPS and idle rate calculations
## 
## Tests the LoadoutSimulation tool for balancing and analysis.

extends Node

func _ready() -> void:
	print("=== Running Loadout Simulation Tests ===\n")
	
	# Reset state
	UUID.reset()
	
	var all_passed := true
	
	# Test 1: Idle gain simulation
	all_passed = test_idle_gain_simulation() and all_passed
	
	# Test 2: Combat DPS simulation
	all_passed = test_combat_dps_simulation() and all_passed
	
	# Test 3: Loadout stats calculation
	all_passed = test_loadout_stats_calculation() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All loadout simulation tests passed!")
	else:
		print("✗ Some loadout simulation tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_idle_gain_simulation() -> bool:
	print("Test: Idle gain simulation")
	
	# Create a loadout with idle rate modifiers
	var loadout: Array = []
	
	# Iron sword: +5% idle rate multiplier
	var sword := ItemModel.new()
	sword.from_dict(InventorySystem.item_definitions["iron_sword"])
	loadout.append(sword)
	
	# Epic gem: +10% idle rate multiplier
	var gem := ItemModel.new()
	gem.from_dict(InventorySystem.item_definitions["epic_gem"])
	loadout.append(gem)
	
	# Simulate with base rate of 10.0
	var base_rate := 10.0
	var result := LoadoutSimulation.simulate_idle_gain(loadout, base_rate)
	
	# Expected: 10.0 * (1 + 0.05 + 0.10) = 10.0 * 1.15 = 11.5
	var expected := 11.5
	var tolerance := 0.01
	
	if abs(result - expected) > tolerance:
		print("  ✗ Expected ~%.2f, got %.2f" % [expected, result])
		return false
	
	print("  ✓ Idle gain simulation correct (%.2f gold/sec)" % result)
	return true

func test_combat_dps_simulation() -> bool:
	print("\nTest: Combat DPS simulation")
	
	# Create a loadout with combat modifiers
	var loadout: Array = []
	
	# Iron sword: +5 attack
	var sword := ItemModel.new()
	sword.from_dict(InventorySystem.item_definitions["iron_sword"])
	loadout.append(sword)
	
	# Simulate with base attack of 10.0, no essence
	var base_attack := 10.0
	var essence := 0.0
	var result := LoadoutSimulation.simulate_combat_dps(loadout, base_attack, essence)
	
	# Expected: (10 + 5) * 1.0 (attacks/sec) = 15.0 DPS (without crit)
	# With crit chance 5% and crit mult 2.0: 15.0 * (1 + 1.0 * 0.05) = 15.75
	var expected_min := 15.0
	var expected_max := 16.0
	
	if result < expected_min or result > expected_max:
		print("  ✗ Expected DPS between %.2f and %.2f, got %.2f" % [expected_min, expected_max, result])
		return false
	
	print("  ✓ Combat DPS simulation correct (%.2f DPS)" % result)
	return true

func test_loadout_stats_calculation() -> bool:
	print("\nTest: Loadout stats calculation")
	
	# Create a loadout
	var loadout: Array = []
	
	# Iron sword: +5 attack, +5% idle rate
	var sword := ItemModel.new()
	sword.from_dict(InventorySystem.item_definitions["iron_sword"])
	loadout.append(sword)
	
	# Steel armor: +8 defense, +10% attack mult
	var armor := ItemModel.new()
	armor.from_dict(InventorySystem.item_definitions["steel_armor"])
	loadout.append(armor)
	
	# Calculate stats
	var stats := LoadoutSimulation.calculate_loadout_stats(loadout, 10.0, 5.0, 0.0)
	
	# Verify attack_add
	if stats["attack_add"] != 5.0:
		print("  ✗ Expected attack_add 5.0, got %.1f" % stats["attack_add"])
		return false
	
	# Verify attack_mult (1.0 + 0.1 from steel armor)
	if abs(stats["attack_mult"] - 1.1) > 0.01:
		print("  ✗ Expected attack_mult 1.1, got %.2f" % stats["attack_mult"])
		return false
	
	# Verify defense_add
	if stats["defense_add"] != 8.0:
		print("  ✗ Expected defense_add 8.0, got %.1f" % stats["defense_add"])
		return false
	
	# Verify idle_mult (1.0 + 0.05 from iron sword)
	if abs(stats["idle_mult"] - 1.05) > 0.01:
		print("  ✗ Expected idle_mult 1.05, got %.2f" % stats["idle_mult"])
		return false
	
	# Verify effective_attack: (10 + 5) * 1.1 = 16.5
	var expected_attack := 16.5
	if abs(stats["effective_attack"] - expected_attack) > 0.1:
		print("  ✗ Expected effective_attack %.1f, got %.2f" % [expected_attack, stats["effective_attack"]])
		return false
	
	print("  ✓ Loadout stats calculated correctly")
	return true
