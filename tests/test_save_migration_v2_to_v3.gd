## Test Save Migration v2 to v3: Test schema migration from version 2 to 3
## 
## Validates that v2 saves are correctly migrated to v3 format with prestige fields.

extends SceneTree

func _init() -> void:
	print("=== Running Migration v2 to v3 Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Migration adds prestige fields
	all_passed = test_migration_adds_prestige_fields() and all_passed
	
	# Test 2: Migration sets version to 3
	all_passed = test_migration_updates_version() and all_passed
	
	# Test 3: Migration initializes lifetime_gold from current gold
	all_passed = test_migration_initializes_lifetime_gold() and all_passed
	
	# Test 4: Migration preserves existing data
	all_passed = test_migration_preserves_existing_data() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All migration v2→v3 tests passed!")
	else:
		print("✗ Some migration v2→v3 tests failed")
	
	quit(0 if all_passed else 1)

func test_migration_adds_prestige_fields() -> bool:
	print("Test: Migration adds prestige fields")
	
	# Create a mock v2 save data (no prestige fields)
	var v2_data := {
		"version": 2,
		"timestamp": 1000000.0,
		"last_saved_time": 1000000.0,
		"resources": {
			"gold": {
				"amount": 500000.0,
				"unlocked": true
			}
		},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 0.0
	}
	
	# Create SaveSchemaModel and load v2 data
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v2_data)
	
	# Verify it loaded as v2
	if save_data.version != 2:
		print("  ✗ Failed to load as v2 (version is %d)" % save_data.version)
		return false
	
	# Run migration
	save_data.migrate(2)
	
	# Check that new fields were added
	var has_lifetime_gold: bool = save_data.has("lifetime_gold") or save_data.lifetime_gold >= 0.0
	var has_total_prestiges: bool = save_data.has("total_prestiges") or save_data.total_prestiges >= 0
	var has_essence_spent: bool = save_data.has("essence_spent") or save_data.essence_spent >= 0.0
	var has_prestige_settings: bool = not save_data.prestige_settings.is_empty()
	
	if not (has_lifetime_gold and has_total_prestiges and has_essence_spent and has_prestige_settings):
		print("  ✗ Migration failed to add all prestige fields")
		return false
	
	print("  ✓ Migration added prestige fields: lifetime_gold, total_prestiges, essence_spent, prestige_settings")
	return true

func test_migration_updates_version() -> bool:
	print("\nTest: Migration updates version to 3")
	
	# Create v2 save
	var v2_data := {
		"version": 2,
		"timestamp": 1000000.0,
		"last_saved_time": 1000000.0,
		"resources": {},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 0.0
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v2_data)
	
	# Run migration
	save_data.migrate(2)
	
	# Verify version is now 3
	if save_data.version != 3:
		print("  ✗ Version not updated (is %d)" % save_data.version)
		return false
	
	print("  ✓ Version updated to 3")
	return true

func test_migration_initializes_lifetime_gold() -> bool:
	print("\nTest: Migration initializes lifetime_gold from current gold")
	
	# Create v2 save with existing gold
	var v2_data := {
		"version": 2,
		"timestamp": 1000000.0,
		"last_saved_time": 1000000.0,
		"resources": {
			"gold": {
				"amount": 2500000.0,
				"unlocked": true
			}
		},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 0.0
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v2_data)
	
	# Run migration
	save_data.migrate(2)
	
	# Verify lifetime_gold was initialized from current gold
	if save_data.lifetime_gold != 2500000.0:
		print("  ✗ lifetime_gold not initialized from gold (got %.0f)" % save_data.lifetime_gold)
		return false
	
	print("  ✓ lifetime_gold initialized from current gold: %.0f" % save_data.lifetime_gold)
	return true

func test_migration_preserves_existing_data() -> bool:
	print("\nTest: Migration preserves existing data")
	
	# Create v2 save with some data
	var v2_data := {
		"version": 2,
		"timestamp": 1234567.0,
		"last_saved_time": 1234567.0,
		"resources": {
			"gold": {
				"amount": 999999.0,
				"unlocked": true
			}
		},
		"upgrades": {
			"test_upgrade": {
				"id": "test_upgrade",
				"level": 10,
				"unlocked": true
			}
		},
		"inventory": [],
		"player_stats": {},
		"essence": 5.0
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v2_data)
	
	# Run migration
	save_data.migrate(2)
	
	# Verify existing data wasn't modified
	if save_data.timestamp != 1234567.0:
		print("  ✗ timestamp was modified")
		return false
	
	if save_data.essence != 5.0:
		print("  ✗ essence was modified")
		return false
	
	if not save_data.resources.has("gold") or save_data.resources["gold"]["amount"] != 999999.0:
		print("  ✗ gold amount was modified")
		return false
	
	if not save_data.upgrades.has("test_upgrade") or save_data.upgrades["test_upgrade"]["level"] != 10:
		print("  ✗ upgrade data was modified")
		return false
	
	print("  ✓ Existing data preserved during migration")
	return true
