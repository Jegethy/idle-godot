## Test Equip Modifiers: Verify item effects modify stats correctly
## 
## Tests that equipping items applies stat modifiers and formulas are correct.

extends Node

func _ready() -> void:
	print("=== Running Equip Modifiers Tests ===\n")
	
	# Reset state
	UUID.reset()
	GameState.items.clear()
	GameState.equipped_slots.clear()
	
	var all_passed := true
	
	# Test 1: Equip item applies attack bonus
	all_passed = test_equip_attack_bonus() and all_passed
	
	# Test 2: Equip item applies multiplier bonus
	all_passed = test_equip_multiplier_bonus() and all_passed
	
	# Test 3: Unequip removes modifiers
	all_passed = test_unequip_removes_modifiers() and all_passed
	
	# Test 4: Multiple items stack correctly
	all_passed = test_multiple_items_stack() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All equip modifiers tests passed!")
	else:
		print("✗ Some equip modifiers tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_equip_attack_bonus() -> bool:
	print("Test: Equip item with attack bonus")
	
	# Clear and reset
	GameState.items.clear()
	GameState.equipped_slots.clear()
	InventorySystem.recompute_all_modifiers()
	
	# Initial combat modifiers should be at defaults
	var initial_attack_add: float = GameState.combat_modifiers["attack_add"]
	if initial_attack_add != 0.0:
		print("  ✗ Expected initial attack_add 0.0, got %.1f" % initial_attack_add)
		return false
	
	# Add iron sword and equip it
	InventorySystem.add_item("iron_sword", 1)
	var item: ItemModel = GameState.items[0]
	InventorySystem.equip_item(item.instance_id)
	
	# Should have +5 attack from iron_sword
	var new_attack_add: float = GameState.combat_modifiers["attack_add"]
	if new_attack_add != 5.0:
		print("  ✗ Expected attack_add 5.0, got %.1f" % new_attack_add)
		return false
	
	print("  ✓ Attack bonus applied correctly (+%.1f)" % new_attack_add)
	return true

func test_equip_multiplier_bonus() -> bool:
	print("\nTest: Equip item with multiplier bonus")
	
	# Clear and reset
	GameState.items.clear()
	GameState.equipped_slots.clear()
	InventorySystem.recompute_all_modifiers()
	
	# Add steel armor and equip it
	InventorySystem.add_item("steel_armor", 1)
	var item: ItemModel = GameState.items[0]
	InventorySystem.equip_item(item.instance_id)
	
	# Should have +0.1 (10%) attack multiplier from steel_armor
	var attack_mult: float = GameState.combat_modifiers["attack_mult"]
	if abs(attack_mult - 1.1) > 0.001:
		print("  ✗ Expected attack_mult 1.1, got %.2f" % attack_mult)
		return false
	
	# Should have +8 defense
	var defense_add: float = GameState.combat_modifiers["defense_add"]
	if defense_add != 8.0:
		print("  ✗ Expected defense_add 8.0, got %.1f" % defense_add)
		return false
	
	print("  ✓ Multiplier bonus applied correctly (×%.2f)" % attack_mult)
	return true

func test_unequip_removes_modifiers() -> bool:
	print("\nTest: Unequip removes modifiers")
	
	# Clear and reset
	GameState.items.clear()
	GameState.equipped_slots.clear()
	InventorySystem.recompute_all_modifiers()
	
	# Equip iron sword
	InventorySystem.add_item("iron_sword", 1)
	var item: ItemModel = GameState.items[0]
	InventorySystem.equip_item(item.instance_id)
	
	var equipped_attack_add: float = GameState.combat_modifiers["attack_add"]
	if equipped_attack_add != 5.0:
		print("  ✗ Expected attack_add 5.0 after equip, got %.1f" % equipped_attack_add)
		return false
	
	# Unequip
	InventorySystem.unequip_slot("weapon")
	
	# Should be back to 0
	var unequipped_attack_add: float = GameState.combat_modifiers["attack_add"]
	if unequipped_attack_add != 0.0:
		print("  ✗ Expected attack_add 0.0 after unequip, got %.1f" % unequipped_attack_add)
		return false
	
	print("  ✓ Unequip removed modifiers correctly")
	return true

func test_multiple_items_stack() -> bool:
	print("\nTest: Multiple items stack correctly")
	
	# Clear and reset
	GameState.items.clear()
	GameState.equipped_slots.clear()
	InventorySystem.recompute_all_modifiers()
	
	# Equip multiple items
	InventorySystem.add_item("iron_sword", 1)
	var sword: ItemModel = GameState.items[0]
	InventorySystem.equip_item(sword.instance_id)
	
	InventorySystem.add_item("steel_armor", 1)
	var armor: ItemModel = GameState.items[1]
	InventorySystem.equip_item(armor.instance_id)
	
	# Attack should be +5 (sword) with defense +8 (armor)
	var attack_add: float = GameState.combat_modifiers["attack_add"]
	var defense_add: float = GameState.combat_modifiers["defense_add"]
	var attack_mult: float = GameState.combat_modifiers["attack_mult"]
	
	if attack_add != 5.0:
		print("  ✗ Expected attack_add 5.0, got %.1f" % attack_add)
		return false
	
	if defense_add != 8.0:
		print("  ✗ Expected defense_add 8.0, got %.1f" % defense_add)
		return false
	
	if abs(attack_mult - 1.1) > 0.001:
		print("  ✗ Expected attack_mult 1.1, got %.2f" % attack_mult)
		return false
	
	print("  ✓ Multiple items stacked correctly (attack_add=%.1f, defense_add=%.1f, attack_mult=%.2f)" % [attack_add, defense_add, attack_mult])
	return true
