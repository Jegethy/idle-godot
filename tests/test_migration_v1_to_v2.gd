## Test Migration v1 to v2: Test schema migration from version 1 to 2
## 
## Validates that v1 saves are correctly migrated to v2 format.

extends Node

func _ready() -> void:
	print("=== Running Migration v1 to v2 Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Migration adds last_saved_time
	all_passed = test_migration_adds_last_saved_time() and all_passed
	
	# Test 2: Migration sets version to 2
	all_passed = test_migration_updates_version() and all_passed
	
	# Test 3: Migration completes missing resources
	all_passed = test_migration_completes_resources() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All migration tests passed!")
	else:
		print("✗ Some migration tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_migration_adds_last_saved_time() -> bool:
	print("Test: Migration adds last_saved_time field")
	
	# Create a mock v1 save data (no last_saved_time)
	var v1_data := {
		"version": 1,
		"timestamp": 1000000.0,
		# No last_saved_time field
		"resources": {
			"gold": {
				"amount": 100.0,
				"unlocked": true
			}
		},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 0.0
	}
	
	# Create SaveSchemaModel and load v1 data
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v1_data)
	
	# Verify it loaded as v1
	if save_data.version != 1:
		print("  ✗ Failed to load as v1 (version is %d)" % save_data.version)
		return false
	
	# Run migration
	save_data.migrate(1)
	
	# Check that last_saved_time was added
	if save_data.last_saved_time == 0.0:
		print("  ✗ Migration failed to add last_saved_time")
		return false
	
	# Check that version was updated
	if save_data.version != 2:
		print("  ✗ Migration failed to update version (is %d)" % save_data.version)
		return false
	
	print("  ✓ Migration added last_saved_time: %.0f" % save_data.last_saved_time)
	return true

func test_migration_updates_version() -> bool:
	print("\nTest: Migration updates version to 2")
	
	# Create v1 save
	var v1_data := {
		"version": 1,
		"timestamp": 1000000.0,
		"resources": {},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 0.0
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v1_data)
	
	# Run migration
	save_data.migrate(1)
	
	# Verify version is now 2
	if save_data.version != 2:
		print("  ✗ Version not updated (is %d)" % save_data.version)
		return false
	
	print("  ✓ Version updated to 2")
	return true

func test_migration_completes_resources() -> bool:
	print("\nTest: Migration completes missing resources")
	
	# Create v1 save with incomplete resources (missing some from GameState)
	var v1_data := {
		"version": 1,
		"timestamp": 1000000.0,
		"resources": {
			"gold": {
				"amount": 50.0,
				"unlocked": true
			}
			# Missing other resources that might be in GameState
		},
		"upgrades": {},
		"inventory": [],
		"player_stats": {},
		"essence": 0.0
	}
	
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(v1_data)
	
	# Count resources before migration
	var resources_before := save_data.resources.size()
	
	# Run migration
	save_data.migrate(1)
	
	# Count resources after migration
	var resources_after := save_data.resources.size()
	
	# Verify all GameState resources are present
	var all_present := true
	for resource_id in GameState.resources:
		if not save_data.resources.has(resource_id):
			print("  ✗ Resource '%s' missing after migration" % resource_id)
			all_present = false
	
	if not all_present:
		return false
	
	# Verify existing resource wasn't lost
	if not save_data.resources.has("gold"):
		print("  ✗ Existing 'gold' resource was lost")
		return false
	
	if save_data.resources["gold"]["amount"] != 50.0:
		print("  ✗ Existing 'gold' amount was modified")
		return false
	
	print("  ✓ Resources completed (had %d, now has %d)" % [resources_before, resources_after])
	return true
