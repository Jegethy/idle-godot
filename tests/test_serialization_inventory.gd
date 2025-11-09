## Test Serialization Inventory: Verify save/load preserves inventory
## 
## Tests that items and equipped state are correctly serialized and deserialized.

extends Node

func _ready() -> void:
	print("=== Running Serialization Inventory Tests ===\n")
	
	# Reset state
	UUID.reset()
	
	var all_passed := true
	
	# Test 1: Save and load preserves inventory items
	all_passed = test_save_load_inventory() and all_passed
	
	# Test 2: Save and load preserves equipped state
	all_passed = test_save_load_equipped() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All serialization inventory tests passed!")
	else:
		print("✗ Some serialization inventory tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_save_load_inventory() -> bool:
	print("Test: Save and load preserves inventory items")
	
	# Clear and setup inventory
	GameState.items.clear()
	GameState.equipped_slots.clear()
	
	# Add some items
	InventorySystem.add_item("iron_sword", 1)
	InventorySystem.add_item("health_potion", 5)
	InventorySystem.add_item("steel_armor", 1)
	
	var original_count := GameState.items.size()
	var original_ids: Array[String] = []
	var original_quantities: Array[int] = []
	
	for item in GameState.items:
		original_ids.append(item.id)
		original_quantities.append(item.quantity)
	
	# Serialize
	var save_data := SaveSchemaModel.new()
	for item in GameState.items:
		save_data.inventory.append(item.to_dict())
	
	# Clear state
	GameState.items.clear()
	
	# Deserialize
	for item_data in save_data.inventory:
		var item := ItemModel.new()
		item.from_dict(item_data)
		GameState.items.append(item)
	
	# Verify
	if GameState.items.size() != original_count:
		print("  ✗ Expected %d items, got %d" % [original_count, GameState.items.size()])
		return false
	
	for i in range(GameState.items.size()):
		var item: ItemModel = GameState.items[i]
		if item.id != original_ids[i]:
			print("  ✗ Item %d: expected id '%s', got '%s'" % [i, original_ids[i], item.id])
			return false
		if item.quantity != original_quantities[i]:
			print("  ✗ Item %d: expected quantity %d, got %d" % [i, original_quantities[i], item.quantity])
			return false
	
	print("  ✓ Inventory preserved across save/load (%d items)" % original_count)
	return true

func test_save_load_equipped() -> bool:
	print("\nTest: Save and load preserves equipped state")
	
	# Clear and setup
	GameState.items.clear()
	GameState.equipped_slots.clear()
	UUID.reset()
	
	# Add and equip items
	InventorySystem.add_item("iron_sword", 1)
	var sword: ItemModel = GameState.items[0]
	InventorySystem.equip_item(sword.instance_id)
	
	InventorySystem.add_item("steel_armor", 1)
	var armor: ItemModel = GameState.items[1]
	InventorySystem.equip_item(armor.instance_id)
	
	var original_equipped_count := GameState.equipped_slots.size()
	var original_equipped := GameState.equipped_slots.duplicate()
	
	# Serialize
	var save_data := SaveSchemaModel.new()
	save_data.equipped_slots = GameState.equipped_slots.duplicate()
	for item in GameState.items:
		save_data.inventory.append(item.to_dict())
	
	# Clear state
	GameState.items.clear()
	GameState.equipped_slots.clear()
	
	# Deserialize
	for item_data in save_data.inventory:
		var item := ItemModel.new()
		item.from_dict(item_data)
		GameState.items.append(item)
	GameState.equipped_slots = save_data.equipped_slots.duplicate()
	
	# Verify
	if GameState.equipped_slots.size() != original_equipped_count:
		print("  ✗ Expected %d equipped slots, got %d" % [original_equipped_count, GameState.equipped_slots.size()])
		return false
	
	for slot in original_equipped:
		if not GameState.equipped_slots.has(slot):
			print("  ✗ Missing equipped slot: %s" % slot)
			return false
		if GameState.equipped_slots[slot] != original_equipped[slot]:
			print("  ✗ Slot %s: expected instance_id '%s', got '%s'" % [slot, original_equipped[slot], GameState.equipped_slots[slot]])
			return false
	
	print("  ✓ Equipped state preserved across save/load (%d slots)" % original_equipped_count)
	return true
