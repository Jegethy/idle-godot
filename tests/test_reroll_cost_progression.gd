## Test Reroll Cost Progression: Verify reroll costs increase correctly
## 
## Tests exponential cost growth for item rerolls.

extends SceneTree

func _init() -> void:
	print("=== Running Reroll Cost Progression Tests ===\n")
	
	var all_passed := true
	
	# Test 1: First reroll has base cost
	all_passed = test_first_reroll_base_cost() and all_passed
	
	# Test 2: Cost increases exponentially
	all_passed = test_exponential_cost_growth() and all_passed
	
	# Test 3: Reroll count increments
	all_passed = test_reroll_count_increments() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All reroll cost progression tests passed!")
	else:
		print("✗ Some reroll cost progression tests failed")
	
	quit(0 if all_passed else 1)

func test_first_reroll_base_cost() -> bool:
	print("Test: First reroll has base cost")
	
	# Create a test item
	var item := ItemModel.new()
	item.id = "test_sword"
	item.base_id = "test_sword"
	item.display_name = "Test Sword"
	item.rarity = "rare"
	item.slot = "weapon"
	item.stackable = false
	item.reroll_count = 0
	item.instance_id = UUID.generate()
	
	# Add to game state
	GameState.items.append(item)
	
	# Get cost
	var cost_info := InventorySystem.get_reroll_cost(item.instance_id)
	
	var expected_gold := BalanceConstants.BASE_REROLL_GOLD
	var expected_essence := BalanceConstants.BASE_REROLL_ESSENCE
	
	var actual_gold: float = cost_info.get("gold", 0.0)
	var actual_essence: float = cost_info.get("essence", 0.0)
	
	if abs(actual_gold - expected_gold) > 0.01:
		print("  ✗ Expected gold cost %.2f, got %.2f" % [expected_gold, actual_gold])
		GameState.items.clear()
		return false
	
	if abs(actual_essence - expected_essence) > 0.01:
		print("  ✗ Expected essence cost %.2f, got %.2f" % [expected_essence, actual_essence])
		GameState.items.clear()
		return false
	
	print("  ✓ First reroll costs %.0f gold, %.1f essence" % [actual_gold, actual_essence])
	
	# Clean up
	GameState.items.clear()
	return true

func test_exponential_cost_growth() -> bool:
	print("\nTest: Reroll cost grows exponentially")
	
	# Test progression for reroll counts 0, 1, 2, 3
	var test_counts := [0, 1, 2, 3]
	var previous_gold := 0.0
	
	for reroll_count in test_counts:
		# Calculate expected cost
		var expected_gold := BalanceConstants.BASE_REROLL_GOLD * pow(BalanceConstants.REROLL_GOLD_GROWTH, reroll_count)
		var expected_essence := BalanceConstants.BASE_REROLL_ESSENCE * pow(BalanceConstants.REROLL_ESSENCE_GROWTH, reroll_count)
		
		# Create test item
		var item := ItemModel.new()
		item.id = "test_item"
		item.base_id = "test_item"
		item.reroll_count = reroll_count
		item.instance_id = UUID.generate()
		item.stackable = false
		
		GameState.items.append(item)
		
		# Get actual cost
		var cost_info := InventorySystem.get_reroll_cost(item.instance_id)
		var actual_gold: float = cost_info.get("gold", 0.0)
		var actual_essence: float = cost_info.get("essence", 0.0)
		
		# Verify
		if abs(actual_gold - expected_gold) > 0.01:
			print("  ✗ At reroll_count=%d: Expected gold %.2f, got %.2f" % [reroll_count, expected_gold, actual_gold])
			GameState.items.clear()
			return false
		
		if abs(actual_essence - expected_essence) > 0.01:
			print("  ✗ At reroll_count=%d: Expected essence %.2f, got %.2f" % [reroll_count, expected_essence, actual_essence])
			GameState.items.clear()
			return false
		
		# Verify growth (should increase each time)
		if reroll_count > 0 and actual_gold <= previous_gold:
			print("  ✗ Gold cost did not increase from reroll %d to %d" % [reroll_count - 1, reroll_count])
			GameState.items.clear()
			return false
		
		previous_gold = actual_gold
		
		# Clean up this item
		GameState.items.pop_back()
	
	print("  ✓ Costs grow exponentially as expected")
	GameState.items.clear()
	return true

func test_reroll_count_increments() -> bool:
	print("\nTest: Reroll count increments after each reroll")
	
	# Create test item with affixes
	var item := ItemModel.new()
	item.id = "test_sword"
	item.base_id = "test_sword"
	item.display_name = "Test Sword"
	item.rarity = "epic"
	item.slot = "weapon"
	item.stackable = false
	item.reroll_count = 0
	item.instance_id = UUID.generate()
	item.affixes = [
		{
			"id": "sharp",
			"category": "prefix",
			"rolled_effects": [{"type": "combat_attack_add", "value": 5.0}]
		}
	]
	
	# Add to game state
	GameState.items.append(item)
	
	# Give player enough resources
	GameState.add_resource_amount("gold", 10000.0)
	GameState.essence = 100.0
	GameState.current_wave = 10
	
	# Perform first reroll
	var initial_count := item.reroll_count
	var success := InventorySystem.reroll_item(item.instance_id)
	
	if not success:
		print("  ✗ First reroll failed")
		GameState.items.clear()
		return false
	
	if item.reroll_count != initial_count + 1:
		print("  ✗ Reroll count did not increment (expected %d, got %d)" % [initial_count + 1, item.reroll_count])
		GameState.items.clear()
		return false
	
	# Perform second reroll
	success = InventorySystem.reroll_item(item.instance_id)
	
	if not success:
		print("  ✗ Second reroll failed")
		GameState.items.clear()
		return false
	
	if item.reroll_count != initial_count + 2:
		print("  ✗ Reroll count incorrect after second reroll (expected %d, got %d)" % [initial_count + 2, item.reroll_count])
		GameState.items.clear()
		return false
	
	print("  ✓ Reroll count increments correctly")
	
	# Clean up
	GameState.items.clear()
	return true
