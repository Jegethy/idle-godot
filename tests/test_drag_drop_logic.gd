## Test Drag Drop Logic: Verify equip/unequip logic works correctly
## 
## Tests the headless logic for drag/drop operations without UI.

extends Node

func _ready() -> void:
	print("=== Running Drag Drop Logic Tests ===\n")
	
	# Reset state
	UUID.reset()
	
	var all_passed := true
	
	# Test 1: Can equip item to correct slot
	all_passed = test_equip_to_correct_slot() and all_passed
	
	# Test 2: Equipping to occupied slot replaces item
	all_passed = test_equip_replaces_occupied_slot() and all_passed
	
	# Test 3: Cannot equip consumables
	all_passed = test_cannot_equip_consumables() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All drag drop logic tests passed!")
	else:
		print("✗ Some drag drop logic tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_equip_to_correct_slot() -> bool:
	print("Test: Can equip item to correct slot")
	
	# Reset
	GameState.items.clear()
	GameState.equipped_slots.clear()
	
	# Add a weapon
	InventorySystem.add_item("iron_sword", 1)
	var sword: ItemModel = GameState.items[0]
	
	# Equip it
	var success := InventorySystem.equip_item(sword.instance_id)
	
	if not success:
		print("  ✗ Failed to equip iron_sword")
		return false
	
	# Verify it's in the weapon slot
	if not GameState.equipped_slots.has("weapon"):
		print("  ✗ weapon slot should be occupied")
		return false
	
	if GameState.equipped_slots["weapon"] != sword.instance_id:
		print("  ✗ weapon slot has wrong instance_id")
		return false
	
	print("  ✓ Item equipped to correct slot")
	return true

func test_equip_replaces_occupied_slot() -> bool:
	print("\nTest: Equipping to occupied slot replaces item")
	
	# Reset
	GameState.items.clear()
	GameState.equipped_slots.clear()
	UUID.reset()
	
	# Add two weapons
	InventorySystem.add_item("iron_sword", 1)
	var sword1: ItemModel = GameState.items[0]
	
	InventorySystem.add_item("rusty_sword", 1)
	var sword2: ItemModel = GameState.items[1]
	
	# Equip first sword
	InventorySystem.equip_item(sword1.instance_id)
	
	if GameState.equipped_slots["weapon"] != sword1.instance_id:
		print("  ✗ First sword should be equipped")
		return false
	
	# Equip second sword (should replace first)
	InventorySystem.equip_item(sword2.instance_id)
	
	if GameState.equipped_slots["weapon"] != sword2.instance_id:
		print("  ✗ Second sword should replace first")
		return false
	
	# Only one item should be in weapon slot
	if GameState.equipped_slots.size() != 1:
		print("  ✗ Should only have one equipped item")
		return false
	
	print("  ✓ Equipping to occupied slot replaces item correctly")
	return true

func test_cannot_equip_consumables() -> bool:
	print("\nTest: Cannot equip consumable items")
	
	# Reset
	GameState.items.clear()
	GameState.equipped_slots.clear()
	
	# Add a consumable
	InventorySystem.add_item("health_potion", 1)
	var potion: ItemModel = GameState.items[0]
	
	# Try to equip it (should fail)
	var success := InventorySystem.equip_item(potion.instance_id)
	
	if success:
		print("  ✗ Should not be able to equip consumable")
		return false
	
	# Verify no slots are occupied
	if GameState.equipped_slots.size() != 0:
		print("  ✗ No slots should be occupied")
		return false
	
	print("  ✓ Consumables cannot be equipped (as expected)")
	return true
