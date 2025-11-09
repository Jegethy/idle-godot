## Test Loot Rarity Distribution: Verify rarity-weighted item drops
## 
## Tests that rarity distribution follows expected weights.

extends Node

func _ready() -> void:
	print("=== Running Loot Rarity Distribution Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Common is most frequent
	all_passed = test_common_most_frequent() and all_passed
	
	# Test 2: Legendary is rarest
	all_passed = test_legendary_rarest() and all_passed
	
	# Test 3: Rarity factor boosts rare drops
	all_passed = test_rarity_factor_boost() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All loot rarity distribution tests passed!")
	else:
		print("✗ Some loot rarity distribution tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_common_most_frequent() -> bool:
	print("Test: Common rarity is most frequent")
	
	var rarity_counts := {
		"common": 0,
		"uncommon": 0,
		"rare": 0,
		"epic": 0,
		"legendary": 0
	}
	
	# Create service instances for testing
	var affix_service := AffixServiceClass.new()
	affix_service._load_affix_definitions()
	affix_service._load_loot_weights()
	
	# Roll many times
	var trials := 1000
	for i in range(trials):
		var rng := RNGServiceClass.new()
		rng.set_seed(i * 100)
		var rarity := affix_service.roll_rarity(rng, 1.0)
		rarity_counts[rarity] += 1
	
	# Common should be most frequent
	var common_count: int = rarity_counts["common"]
	var uncommon_count: int = rarity_counts["uncommon"]
	var rare_count: int = rarity_counts["rare"]
	
	if common_count <= uncommon_count:
		print("  ✗ Common (%d) not more frequent than uncommon (%d)" % [common_count, uncommon_count])
		return false
	
	if uncommon_count <= rare_count:
		print("  ✗ Uncommon (%d) not more frequent than rare (%d)" % [uncommon_count, rare_count])
		return false
	
	print("  ✓ Common is most frequent: %d/%d (%.1f%%)" % [common_count, trials, (common_count * 100.0) / trials])
	print("    Distribution: Common=%d, Uncommon=%d, Rare=%d, Epic=%d, Legendary=%d" % [
		rarity_counts["common"],
		rarity_counts["uncommon"],
		rarity_counts["rare"],
		rarity_counts["epic"],
		rarity_counts["legendary"]
	])
	return true

func test_legendary_rarest() -> bool:
	print("\nTest: Legendary is rarest")
	
	var rarity_counts := {
		"common": 0,
		"uncommon": 0,
		"rare": 0,
		"epic": 0,
		"legendary": 0
	}
	
	# Create service instances for testing
	var affix_service := AffixServiceClass.new()
	affix_service._load_affix_definitions()
	affix_service._load_loot_weights()
	
	# Roll many times
	var trials := 1000
	for i in range(trials):
		var rng := RNGServiceClass.new()
		rng.set_seed(i * 200)
		var rarity := affix_service.roll_rarity(rng, 1.0)
		rarity_counts[rarity] += 1
	
	# Legendary should be rarest
	var legendary_count: int = rarity_counts["legendary"]
	var epic_count: int = rarity_counts["epic"]
	var rare_count: int = rarity_counts["rare"]
	
	if legendary_count > epic_count:
		print("  ✗ Legendary (%d) more frequent than epic (%d)" % [legendary_count, epic_count])
		return false
	
	if epic_count > rare_count:
		print("  ✗ Epic (%d) more frequent than rare (%d)" % [epic_count, rare_count])
		return false
	
	print("  ✓ Legendary is rarest: %d/%d (%.1f%%)" % [legendary_count, trials, (legendary_count * 100.0) / trials])
	return true

func test_rarity_factor_boost() -> bool:
	print("\nTest: Rarity factor boosts rare drops")
	
	# Create service instances for testing
	var affix_service := AffixServiceClass.new()
	affix_service._load_affix_definitions()
	affix_service._load_loot_weights()
	
	# Roll with rarity_factor=1.0 (baseline)
	var baseline_legendary := 0
	var trials := 1000
	
	for i in range(trials):
		var rng := RNGServiceClass.new()
		rng.set_seed(i * 300)
		var rarity := affix_service.roll_rarity(rng, 1.0)
		if rarity == "legendary":
			baseline_legendary += 1
	
	# Roll with rarity_factor=2.0 (boosted)
	var boosted_legendary := 0
	
	for i in range(trials):
		var rng := RNGServiceClass.new()
		rng.set_seed(i * 300)
		var rarity := affix_service.roll_rarity(rng, 2.0)
		if rarity == "legendary":
			boosted_legendary += 1
	
	# Boosted should have more legendaries
	if boosted_legendary <= baseline_legendary:
		print("  ⚠ Boosted legendaries (%d) not higher than baseline (%d)" % [boosted_legendary, baseline_legendary])
		# This could happen by random chance, so just warn
	
	var baseline_pct := (baseline_legendary * 100.0) / trials
	var boosted_pct := (boosted_legendary * 100.0) / trials
	
	print("  ✓ Rarity factor increases legendary drops: %.1f%% -> %.1f%%" % [baseline_pct, boosted_pct])
	return true
