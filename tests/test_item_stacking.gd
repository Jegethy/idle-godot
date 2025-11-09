## Test Item Stacking: Verify stackable items combine correctly
## 
## Tests that stackable items merge quantities and respect MAX_STACK cap.

extends SceneTree

func _init() -> void:
	print("=== Running Item Stacking Tests ===\n")
	
	# Reset UUID counter for consistent testing
	UUID.reset()
	
	var all_passed := true
	
	# Test 1: Adding stackable items merges quantities
	all_passed = test_stackable_items_merge() and all_passed
	
	# Test 2: Non-stackable items create separate entries
	all_passed = test_non_stackable_items_separate() and all_passed
	
	# Test 3: Stack cap enforcement
	all_passed = test_stack_cap_enforcement() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All item stacking tests passed!")
	else:
		print("✗ Some item stacking tests failed")
	
	quit(0 if all_passed else 1)

func test_stackable_items_merge() -> bool:
	print("Test: Stackable items merge quantities")
	
	# Clear inventory
	GameState.items.clear()
	
	# Add health potion (stackable) 3 times
	InventorySystem.add_item("health_potion", 5)
	InventorySystem.add_item("health_potion", 3)
	InventorySystem.add_item("health_potion", 2)
	
	# Should have only 1 stack with quantity 10
	if GameState.items.size() != 1:
		print("  ✗ Expected 1 item stack, got %d" % GameState.items.size())
		return false
	
	var item: ItemModel = GameState.items[0]
	if item.quantity != 10:
		print("  ✗ Expected quantity 10, got %d" % item.quantity)
		return false
	
	if item.id != "health_potion":
		print("  ✗ Expected health_potion, got %s" % item.id)
		return false
	
	print("  ✓ Stackable items merged correctly (quantity: %d)" % item.quantity)
	return true

func test_non_stackable_items_separate() -> bool:
	print("\nTest: Non-stackable items create separate entries")
	
	# Clear inventory
	GameState.items.clear()
	UUID.reset()
	
	# Add iron swords (non-stackable) 3 times
	InventorySystem.add_item("iron_sword", 1)
	InventorySystem.add_item("iron_sword", 1)
	InventorySystem.add_item("iron_sword", 1)
	
	# Should have 3 separate items
	if GameState.items.size() != 3:
		print("  ✗ Expected 3 separate items, got %d" % GameState.items.size())
		return false
	
	# Each should have unique instance_id
	var instance_ids := {}
	for item in GameState.items:
		if instance_ids.has(item.instance_id):
			print("  ✗ Duplicate instance_id found: %s" % item.instance_id)
			return false
		instance_ids[item.instance_id] = true
		
		if item.id != "iron_sword":
			print("  ✗ Expected iron_sword, got %s" % item.id)
			return false
	
	print("  ✓ Non-stackable items created %d separate entries" % GameState.items.size())
	return true

func test_stack_cap_enforcement() -> bool:
	print("\nTest: Stack cap enforcement")
	
	# Clear inventory
	GameState.items.clear()
	
	# Add health potion up to max stack
	InventorySystem.add_item("health_potion", BalanceConstants.MAX_STACK)
	
	var item: ItemModel = GameState.items[0]
	if item.quantity != BalanceConstants.MAX_STACK:
		print("  ✗ Expected quantity %d, got %d" % [BalanceConstants.MAX_STACK, item.quantity])
		return false
	
	# Try to add more - should cap at MAX_STACK
	InventorySystem.add_item("health_potion", 100)
	
	if item.quantity != BalanceConstants.MAX_STACK:
		print("  ✗ Stack exceeded MAX_STACK: %d" % item.quantity)
		return false
	
	print("  ✓ Stack capped at MAX_STACK (%d)" % BalanceConstants.MAX_STACK)
	return true
