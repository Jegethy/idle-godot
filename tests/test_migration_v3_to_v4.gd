## Test Migration v3 to v4: Verify save schema migration
## 
## Tests that v3 saves migrate correctly to v4 with inventory fields.

extends Node

func _ready() -> void:
	print("=== Running Migration v3 to v4 Tests ===\n")
	
	var all_passed := true
	
	# Test 1: v3 save migrates to v4
	all_passed = test_v3_to_v4_migration() and all_passed
	
	# Test 2: Missing fields are initialized
	all_passed = test_missing_fields_initialized() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All migration v3 to v4 tests passed!")
	else:
		print("✗ Some migration v3 to v4 tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_v3_to_v4_migration() -> bool:
	print("Test: v3 save migrates to v4")
	
	# Create a synthetic v3 save
	var v3_data := {
		"version": 3,
		"timestamp": 1234567890,
		"last_saved_time": 1234567890,
		"resources": {
			"gold": {"amount": 1000.0, "unlocked": true}
		},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 5.0,
		"lifetime_gold": 2000000.0,
		"total_prestiges": 1,
		"essence_spent": 0.0,
		"prestige_settings": {"formula_version": 1},
		"current_wave": 3,
		"lifetime_enemies_defeated": 25
	}
	
	# Load into SaveSchemaModel
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v3_data)
	
	# Verify it's still v3
	if save_data.version != 3:
		print("  ✗ Expected version 3 after from_dict, got %d" % save_data.version)
		return false
	
	# Migrate to v4
	save_data.migrate(3)
	
	# Verify migration
	if save_data.version != 4:
		print("  ✗ Expected version 4 after migration, got %d" % save_data.version)
		return false
	
	# Verify new fields exist
	if not save_data.equipped_slots is Dictionary:
		print("  ✗ equipped_slots should be a Dictionary")
		return false
	
	if save_data.equipped_slots.size() != 0:
		print("  ✗ equipped_slots should be empty after migration")
		return false
	
	# Verify old fields preserved
	if save_data.essence != 5.0:
		print("  ✗ essence should be preserved (expected 5.0, got %.1f)" % save_data.essence)
		return false
	
	if save_data.current_wave != 3:
		print("  ✗ current_wave should be preserved (expected 3, got %d)" % save_data.current_wave)
		return false
	
	print("  ✓ v3 migrated to v4 successfully")
	return true

func test_missing_fields_initialized() -> bool:
	print("\nTest: Missing fields are initialized correctly")
	
	# Create v3 save without equipped_slots
	var v3_data := {
		"version": 3,
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
		"lifetime_enemies_defeated": 0
		# Note: equipped_slots is missing
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v3_data)
	save_data.migrate(3)
	
	# Verify equipped_slots was initialized
	if not save_data.equipped_slots is Dictionary:
		print("  ✗ equipped_slots should be initialized as Dictionary")
		return false
	
	if save_data.equipped_slots.size() != 0:
		print("  ✗ equipped_slots should be empty")
		return false
	
	# Verify inventory is an array
	if not save_data.inventory is Array:
		print("  ✗ inventory should be an Array")
		return false
	
	print("  ✓ Missing fields initialized correctly")
	return true
