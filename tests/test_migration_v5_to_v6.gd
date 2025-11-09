## Test Migration v5 to v6: Verify save schema migration
## 
## Tests that v5 saves migrate correctly to v6 with meta upgrade fields.

extends SceneTree

func _init() -> void:
	print("=== Running Migration v5 to v6 Tests ===\n")
	
	var all_passed := true
	
	# Test 1: v5 save migrates to v6
	all_passed = test_v5_to_v6_migration() and all_passed
	
	# Test 2: Missing meta fields are initialized
	all_passed = test_missing_meta_fields_initialized() and all_passed
	
	# Test 3: Existing fields preserved
	all_passed = test_existing_fields_preserved() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All migration v5 to v6 tests passed!")
	else:
		print("✗ Some migration v5 to v6 tests failed")
	
	quit(0 if all_passed else 1)

func test_v5_to_v6_migration() -> bool:
	print("Test: v5 save migrates to v6")
	
	# Create a synthetic v5 save
	var v5_data := {
		"version": 5,
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
				"instance_id": "test-instance-1",
				"base_id": "iron_sword",
				"affixes": [],
				"reroll_count": 0
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
		# Note: meta_upgrades, respec_tokens, last_respec_time all missing
	}
	
	# Load into SaveSchemaModel
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v5_data)
	
	# Verify it's still v5
	if save_data.version != 5:
		print("  ✗ Expected version 5 after from_dict, got %d" % save_data.version)
		return false
	
	# Migrate to v6
	save_data.migrate(5)
	
	# Verify migration
	if save_data.version != 6:
		print("  ✗ Expected version 6 after migration, got %d" % save_data.version)
		return false
	
	# Verify new fields exist
	if not save_data.meta_upgrades is Dictionary:
		print("  ✗ meta_upgrades should be a Dictionary")
		return false
	
	if save_data.meta_upgrades.size() != 0:
		print("  ✗ meta_upgrades should be empty for fresh v6")
		return false
	
	if save_data.respec_tokens != 0:
		print("  ✗ Expected respec_tokens = 0, got %d" % save_data.respec_tokens)
		return false
	
	if save_data.last_respec_time != 0:
		print("  ✗ Expected last_respec_time = 0, got %d" % save_data.last_respec_time)
		return false
	
	# Verify old fields preserved
	if save_data.essence != 10.0:
		print("  ✗ essence should be preserved (expected 10.0, got %.1f)" % save_data.essence)
		return false
	
	if save_data.total_prestiges != 2:
		print("  ✗ total_prestiges should be preserved (expected 2, got %d)" % save_data.total_prestiges)
		return false
	
	print("  ✓ v5 migrated to v6 successfully")
	return true

func test_missing_meta_fields_initialized() -> bool:
	print("\nTest: Missing meta fields are initialized correctly")
	
	# Create v5 save with minimal data
	var v5_data := {
		"version": 5,
		"timestamp": 1234567890,
		"last_saved_time": 1234567890,
		"resources": {},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 0.0,
		"lifetime_gold": 0.0,
		"total_prestiges": 0,
		"essence_spent": 0.0,
		"prestige_settings": {},
		"current_wave": 0,
		"lifetime_enemies_defeated": 0,
		"equipped_slots": {}
		# All meta fields missing
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v5_data)
	save_data.migrate(5)
	
	# Verify all new fields were added with correct defaults
	if not save_data.meta_upgrades is Dictionary or save_data.meta_upgrades.size() != 0:
		print("  ✗ meta_upgrades not initialized as empty Dictionary")
		return false
	
	if save_data.respec_tokens != 0:
		print("  ✗ respec_tokens not initialized to 0")
		return false
	
	if save_data.last_respec_time != 0:
		print("  ✗ last_respec_time not initialized to 0")
		return false
	
	print("  ✓ Missing meta fields initialized correctly")
	return true

func test_existing_fields_preserved() -> bool:
	print("\nTest: All existing v5 fields are preserved")
	
	# Create v5 save with some existing data
	var v5_data := {
		"version": 5,
		"timestamp": 1234567890,
		"last_saved_time": 1234567890,
		"resources": {
			"gold": {"amount": 123456.0, "unlocked": true}
		},
		"upgrades": {
			"gold_boost": {"level": 10}
		},
		"inventory": [],
		"player_stats": {"attack": 50.0},
		"essence": 42.0,
		"lifetime_gold": 999999.0,
		"total_prestiges": 7,
		"essence_spent": 15.0,
		"prestige_settings": {"formula_version": 1},
		"current_wave": 12,
		"lifetime_enemies_defeated": 500,
		"equipped_slots": {}
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v5_data)
	save_data.migrate(5)
	
	# Verify all old fields preserved
	var checks := [
		["essence", 42.0],
		["lifetime_gold", 999999.0],
		["total_prestiges", 7],
		["essence_spent", 15.0],
		["current_wave", 12],
		["lifetime_enemies_defeated", 500]
	]
	
	for check in checks:
		var field: String = check[0]
		var expected = check[1]
		var actual = save_data.get(field)
		
		if actual != expected:
			print("  ✗ Field '%s' not preserved (expected %s, got %s)" % [field, str(expected), str(actual)])
			return false
	
	# Check nested fields
	if not save_data.resources.has("gold"):
		print("  ✗ resources['gold'] not preserved")
		return false
	
	if save_data.resources["gold"]["amount"] != 123456.0:
		print("  ✗ resources['gold']['amount'] not preserved")
		return false
	
	print("  ✓ All existing fields preserved")
	return true
