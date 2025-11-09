## Test Max Affixes Per Rarity: Verify affix count limits
## 
## Tests that items don't exceed max affixes based on rarity.

extends SceneTree

func _init() -> void:
	print("=== Running Max Affixes Per Rarity Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Common items have max 1 affix
	all_passed = test_common_max_affixes() and all_passed
	
	# Test 2: Legendary items have max 3 affixes
	all_passed = test_legendary_max_affixes() and all_passed
	
	# Test 3: Epic items have max 2 affixes
	all_passed = test_epic_max_affixes() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All max affixes per rarity tests passed!")
	else:
		print("✗ Some max affixes per rarity tests failed")
	
	quit(0 if all_passed else 1)

func test_common_max_affixes() -> bool:
	print("Test: Common items have max 1 affix")
	
	var base_item := {"id": "common_sword", "rarity": "common"}
	var rarity := "common"
	var wave_index := 10
	
	# Roll many times to ensure we never exceed
	var max_seen := 0
	
	for i in range(100):
		var rng := RNGService.new()
		rng.set_seed(i * 1000)
		var affixes := AffixService.roll_affixes(base_item, rarity, wave_index, rng)
		
		if affixes.size() > 1:
			print("  ✗ Common item rolled %d affixes (max should be 1)" % affixes.size())
			return false
		
		max_seen = maxi(max_seen, affixes.size())
	
	print("  ✓ Common items never exceed 1 affix (max seen: %d)" % max_seen)
	return true

func test_legendary_max_affixes() -> bool:
	print("\nTest: Legendary items have max 3 affixes")
	
	var base_item := {"id": "legendary_artifact", "rarity": "legendary"}
	var rarity := "legendary"
	var wave_index := 50
	
	# Roll many times
	var max_seen := 0
	var count_with_3 := 0
	
	for i in range(100):
		var rng := RNGService.new()
		rng.set_seed(i * 2000)
		var affixes := AffixService.roll_affixes(base_item, rarity, wave_index, rng)
		
		if affixes.size() > 3:
			print("  ✗ Legendary item rolled %d affixes (max should be 3)" % affixes.size())
			return false
		
		max_seen = maxi(max_seen, affixes.size())
		if affixes.size() == 3:
			count_with_3 += 1
	
	# Legendary should have high chance of rolling 3 affixes
	if count_with_3 < 30:
		print("  ⚠ Only %d/100 legendary items had 3 affixes (expected more)" % count_with_3)
	
	print("  ✓ Legendary items never exceed 3 affixes (max seen: %d, with 3: %d/100)" % [max_seen, count_with_3])
	return true

func test_epic_max_affixes() -> bool:
	print("\nTest: Epic items have max 2 affixes")
	
	var base_item := {"id": "epic_gem", "rarity": "epic"}
	var rarity := "epic"
	var wave_index := 30
	
	# Roll many times
	var max_seen := 0
	
	for i in range(100):
		var rng := RNGService.new()
		rng.set_seed(i * 3000)
		var affixes := AffixService.roll_affixes(base_item, rarity, wave_index, rng)
		
		if affixes.size() > 2:
			print("  ✗ Epic item rolled %d affixes (max should be 2)" % affixes.size())
			return false
		
		max_seen = maxi(max_seen, affixes.size())
	
	print("  ✓ Epic items never exceed 2 affixes (max seen: %d)" % max_seen)
	return true
