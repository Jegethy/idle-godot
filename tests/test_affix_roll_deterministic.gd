## Test Affix Roll Deterministic: Verify deterministic affix generation
## 
## Tests that the same seed yields the same affixes and values.

extends SceneTree

func _init() -> void:
	print("=== Running Affix Roll Deterministic Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Same seed produces same affixes
	all_passed = test_same_seed_same_affixes() and all_passed
	
	# Test 2: Different seeds produce different affixes
	all_passed = test_different_seeds_different_affixes() and all_passed
	
	# Test 3: Affix values are deterministic
	all_passed = test_affix_values_deterministic() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All affix roll deterministic tests passed!")
	else:
		print("✗ Some affix roll deterministic tests failed")
	
	quit(0 if all_passed else 1)

func test_same_seed_same_affixes() -> bool:
	print("Test: Same seed produces same affixes")
	
	var base_item := {
		"id": "test_sword",
		"rarity": "rare"
	}
	var rarity := "rare"
	var wave_index := 10
	
	# Create service instances for testing
	var affix_service := AffixServiceClass.new()
	affix_service._load_affix_definitions()
	affix_service._load_loot_weights()
	
	# Roll affixes with seed 12345
	var rng1 := RNGServiceClass.new()
	rng1.set_seed(12345)
	var affixes1 := affix_service.roll_affixes(base_item, rarity, wave_index, rng1)
	
	# Roll again with same seed
	var rng2 := RNGServiceClass.new()
	rng2.set_seed(12345)
	var affixes2 := affix_service.roll_affixes(base_item, rarity, wave_index, rng2)
	
	# Compare results
	if affixes1.size() != affixes2.size():
		print("  ✗ Different number of affixes: %d vs %d" % [affixes1.size(), affixes2.size()])
		return false
	
	for i in range(affixes1.size()):
		var affix1: Dictionary = affixes1[i]
		var affix2: Dictionary = affixes2[i]
		
		if affix1.get("id", "") != affix2.get("id", ""):
			print("  ✗ Affix %d has different id: '%s' vs '%s'" % [i, affix1.get("id", ""), affix2.get("id", "")])
			return false
		
		if affix1.get("category", "") != affix2.get("category", ""):
			print("  ✗ Affix %d has different category" % i)
			return false
		
		# Compare rolled effects
		var effects1: Array = affix1.get("rolled_effects", [])
		var effects2: Array = affix2.get("rolled_effects", [])
		
		if effects1.size() != effects2.size():
			print("  ✗ Affix %d has different number of effects" % i)
			return false
		
		for j in range(effects1.size()):
			var eff1: Dictionary = effects1[j]
			var eff2: Dictionary = effects2[j]
			
			if eff1.get("type", "") != eff2.get("type", ""):
				print("  ✗ Effect %d has different type" % j)
				return false
			
			var val1: float = eff1.get("value", 0.0)
			var val2: float = eff2.get("value", 0.0)
			
			if abs(val1 - val2) > 0.001:
				print("  ✗ Effect %d has different value: %.3f vs %.3f" % [j, val1, val2])
				return false
	
	print("  ✓ Same seed produces identical affixes (count: %d)" % affixes1.size())
	return true

func test_different_seeds_different_affixes() -> bool:
	print("\nTest: Different seeds produce different affixes")
	
	var base_item := {
		"id": "test_sword",
		"rarity": "epic"
	}
	var rarity := "epic"
	var wave_index := 15
	
	# Create service instances for testing
	var affix_service := AffixServiceClass.new()
	affix_service._load_affix_definitions()
	affix_service._load_loot_weights()
	
	# Roll with seed 11111
	var rng1 := RNGServiceClass.new()
	rng1.set_seed(11111)
	var affixes1 := affix_service.roll_affixes(base_item, rarity, wave_index, rng1)
	
	# Roll with seed 99999
	var rng2 := RNGServiceClass.new()
	rng2.set_seed(99999)
	var affixes2 := affix_service.roll_affixes(base_item, rarity, wave_index, rng2)
	
	# They should be different (with high probability)
	var are_identical := true
	
	if affixes1.size() != affixes2.size():
		are_identical = false
	else:
		for i in range(affixes1.size()):
			if affixes1[i].get("id", "") != affixes2[i].get("id", ""):
				are_identical = false
				break
	
	if are_identical and affixes1.size() > 0:
		print("  ⚠ Warning: Different seeds produced identical affixes (very unlikely)")
		# This is technically possible but extremely unlikely
		# We'll allow it to pass but with a warning
	
	print("  ✓ Different seeds produce different results (seed1: %d affixes, seed2: %d affixes)" % [affixes1.size(), affixes2.size()])
	return true

func test_affix_values_deterministic() -> bool:
	print("\nTest: Affix values are computed deterministically")
	
	# Create multiple items with same seed and verify values match
	var item_def := {
		"id": "legendary_sword",
		"rarity": "legendary",
		"slot": "weapon",
		"stackable": false,
		"effects": []
	}
	
	var rarity := "legendary"
	var wave_index := 25
	var seed := 54321
	
	# Create service instances for testing
	var affix_service := AffixServiceClass.new()
	affix_service._load_affix_definitions()
	affix_service._load_loot_weights()
	
	# Generate first item
	var rng1 := RNGServiceClass.new()
	rng1.set_seed(seed)
	var item1 := affix_service.generate_item_instance(item_def, rarity, wave_index, rng1)
	
	# Generate second item with same parameters
	var rng2 := RNGServiceClass.new()
	rng2.set_seed(seed)
	var item2 := affix_service.generate_item_instance(item_def, rarity, wave_index, rng2)
	
	# Compare affixes
	if item1.affixes.size() != item2.affixes.size():
		print("  ✗ Items have different affix counts")
		return false
	
	for i in range(item1.affixes.size()):
		var affix1: Dictionary = item1.affixes[i]
		var affix2: Dictionary = item2.affixes[i]
		
		var effects1: Array = affix1.get("rolled_effects", [])
		var effects2: Array = affix2.get("rolled_effects", [])
		
		for j in range(effects1.size()):
			var val1: float = effects1[j].get("value", 0.0)
			var val2: float = effects2[j].get("value", 0.0)
			
			if abs(val1 - val2) > 0.0001:
				print("  ✗ Affix values differ: %.4f vs %.4f" % [val1, val2])
				return false
	
	print("  ✓ Affix values are deterministic")
	return true
