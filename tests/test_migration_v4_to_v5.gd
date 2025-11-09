## Test Migration v4 to v5: Verify save schema migration
## 
## Tests that v4 saves migrate correctly to v5 with affix fields.

extends Node

func _ready() -> void:
	print("=== Running Migration v4 to v5 Tests ===\n")
	
	var all_passed := true
	
	# Test 1: v4 save migrates to v5
	all_passed = test_v4_to_v5_migration() and all_passed
	
	# Test 2: Missing affix fields are initialized
	all_passed = test_missing_affix_fields_initialized() and all_passed
	
	# Test 3: Existing items get default affix fields
	all_passed = test_existing_items_get_affixes() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All migration v4 to v5 tests passed!")
	else:
		print("✗ Some migration v4 to v5 tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_v4_to_v5_migration() -> bool:
	print("Test: v4 save migrates to v5")
	
	# Create a synthetic v4 save
	var v4_data := {
		"version": 4,
		"timestamp": 1234567890,
		"last_saved_time": 1234567890,
		"resources": {
			"gold": {"amount": 5000.0, "unlocked": true}
		},
		"upgrades": {},
		"inventory": [
			{
				"id": "iron_sword",
				"display_name": "Iron Sword",
				"rarity": "common",
				"slot": "weapon",
				"effects": [{"type": "combat_attack_add", "value": 5.0}],
				"stackable": false,
				"quantity": 1,
				"instance_id": "test-instance-1"
			}
		],
		"player_stats": {},
		"essence": 10.0,
		"lifetime_gold": 3000000.0,
		"total_prestiges": 2,
		"essence_spent": 5.0,
		"prestige_settings": {"formula_version": 1},
		"current_wave": 5,
		"lifetime_enemies_defeated": 100,
		"equipped_slots": {"weapon": "test-instance-1"}
	}
	
	# Load into SaveSchemaModel
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v4_data)
	
	# Verify it's still v4
	if save_data.version != 4:
		print("  ✗ Expected version 4 after from_dict, got %d" % save_data.version)
		return false
	
	# Migrate to v5
	save_data.migrate(4)
	
	# Verify migration
	if save_data.version != 5:
		print("  ✗ Expected version 5 after migration, got %d" % save_data.version)
		return false
	
	# Verify inventory items have affix fields
	if save_data.inventory.size() != 1:
		print("  ✗ Expected 1 inventory item, got %d" % save_data.inventory.size())
		return false
	
	var item_data: Dictionary = save_data.inventory[0]
	
	# Check base_id
	if not item_data.has("base_id"):
		print("  ✗ Item missing base_id field")
		return false
	
	if item_data["base_id"] != "iron_sword":
		print("  ✗ Expected base_id 'iron_sword', got '%s'" % item_data["base_id"])
		return false
	
	# Check affixes
	if not item_data.has("affixes"):
		print("  ✗ Item missing affixes field")
		return false
	
	if not item_data["affixes"] is Array:
		print("  ✗ affixes should be an Array")
		return false
	
	if item_data["affixes"].size() != 0:
		print("  ✗ affixes should be empty for migrated items")
		return false
	
	# Check reroll_count
	if not item_data.has("reroll_count"):
		print("  ✗ Item missing reroll_count field")
		return false
	
	if item_data["reroll_count"] != 0:
		print("  ✗ Expected reroll_count 0, got %d" % item_data["reroll_count"])
		return false
	
	# Verify old fields preserved
	if save_data.essence != 10.0:
		print("  ✗ essence should be preserved (expected 10.0, got %.1f)" % save_data.essence)
		return false
	
	if save_data.current_wave != 5:
		print("  ✗ current_wave should be preserved (expected 5, got %d)" % save_data.current_wave)
		return false
	
	print("  ✓ v4 migrated to v5 successfully")
	return true

func test_missing_affix_fields_initialized() -> bool:
	print("\nTest: Missing affix fields are initialized correctly")
	
	# Create v4 save with item missing all new fields
	var v4_data := {
		"version": 4,
		"timestamp": 1234567890,
		"last_saved_time": 1234567890,
		"resources": {},
		"upgrades": {},
		"inventory": [
			{
				"id": "rusty_sword",
				"display_name": "Rusty Sword",
				"rarity": "common",
				"slot": "weapon",
				"effects": [],
				"stackable": false,
				"quantity": 1,
				"instance_id": "test-instance-2"
				# Note: base_id, affixes, reroll_count all missing
			}
		],
		"player_stats": {},
		"essence": 0.0,
		"lifetime_gold": 0.0,
		"total_prestiges": 0,
		"essence_spent": 0.0,
		"prestige_settings": {},
		"current_wave": 0,
		"lifetime_enemies_defeated": 0,
		"equipped_slots": {}
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v4_data)
	save_data.migrate(4)
	
	var item_data: Dictionary = save_data.inventory[0]
	
	# Verify all new fields were added
	if not item_data.has("base_id") or item_data["base_id"] != "rusty_sword":
		print("  ✗ base_id not initialized correctly")
		return false
	
	if not item_data.has("affixes") or not item_data["affixes"] is Array:
		print("  ✗ affixes not initialized as Array")
		return false
	
	if not item_data.has("reroll_count") or item_data["reroll_count"] != 0:
		print("  ✗ reroll_count not initialized to 0")
		return false
	
	print("  ✓ Missing affix fields initialized correctly")
	return true

func test_existing_items_get_affixes() -> bool:
	print("\nTest: Multiple existing items all get affix fields")
	
	# Create v4 save with multiple items
	var v4_data := {
		"version": 4,
		"timestamp": 1234567890,
		"last_saved_time": 1234567890,
		"resources": {},
		"upgrades": {},
		"inventory": [
			{
				"id": "iron_sword",
				"instance_id": "item-1",
				"rarity": "common",
				"slot": "weapon",
				"effects": [],
				"stackable": false,
				"quantity": 1
			},
			{
				"id": "steel_armor",
				"instance_id": "item-2",
				"rarity": "uncommon",
				"slot": "armor",
				"effects": [],
				"stackable": false,
				"quantity": 1
			},
			{
				"id": "crit_ring",
				"instance_id": "item-3",
				"rarity": "rare",
				"slot": "trinket1",
				"effects": [],
				"stackable": false,
				"quantity": 1
			}
		],
		"player_stats": {},
		"essence": 0.0,
		"lifetime_gold": 0.0,
		"total_prestiges": 0,
		"essence_spent": 0.0,
		"prestige_settings": {},
		"current_wave": 0,
		"lifetime_enemies_defeated": 0,
		"equipped_slots": {}
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v4_data)
	save_data.migrate(4)
	
	# Check all items
	if save_data.inventory.size() != 3:
		print("  ✗ Expected 3 items, got %d" % save_data.inventory.size())
		return false
	
	for i in range(3):
		var item: Dictionary = save_data.inventory[i]
		if not item.has("base_id") or not item.has("affixes") or not item.has("reroll_count"):
			print("  ✗ Item %d missing affix fields" % i)
			return false
		
		# Verify base_id defaults to id
		if item["base_id"] != item["id"]:
			print("  ✗ Item %d base_id doesn't match id" % i)
			return false
	
	print("  ✓ All existing items got affix fields")
	return true
