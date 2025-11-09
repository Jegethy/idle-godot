## Test Import NDJSON: Additional import validation tests
## 
## Tests import validation and error handling.

extends SceneTree

func _init() -> void:
	print("=== Running Import NDJSON Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Import with invalid JSON lines
	all_passed = test_import_with_invalid_lines() and all_passed
	
	# Test 2: Import with missing required fields
	all_passed = test_import_with_invalid_schema() and all_passed
	
	# Test 3: Import appends to existing data
	all_passed = test_import_appends() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All import NDJSON tests passed!")
	else:
		print("✗ Some import NDJSON tests failed")
	
	quit(0 if all_passed else 1)

func test_import_with_invalid_lines() -> bool:
	print("Test: Import with invalid JSON lines")
	
	# Create test file with mix of valid and invalid lines
	var import_path := "user://test_import_mixed.ndjson"
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	if not file:
		print("  ✗ Failed to create test file")
		return false
	
	# Valid event
	var valid_event := {
		"ts": Time.get_unix_time_from_system(),
		"session_id": "test",
		"event": "valid.event",
		"ver": 1,
		"seq": 0,
		"data": {"value": 1}
	}
	file.store_line(JSON.stringify(valid_event))
	
	# Invalid JSON
	file.store_line("{invalid json")
	
	# Another valid event
	valid_event["seq"] = 1
	valid_event["event"] = "valid.event2"
	file.store_line(JSON.stringify(valid_event))
	
	file.close()
	
	# Import
	var store := EventStore.new()
	var result := store.import_from_ndjson(import_path)
	
	if not result.get("success", false):
		print("  ✗ Import should succeed even with some invalid lines")
		return false
	
	# Should import 2 valid events, skip 1 invalid
	var imported := result.get("imported", 0)
	var skipped := result.get("skipped", 0)
	
	if imported != 2:
		print("  ✗ Expected 2 imported events, got %d" % imported)
		return false
	
	if skipped != 1:
		print("  ✗ Expected 1 skipped line, got %d" % skipped)
		return false
	
	# Clean up
	DirAccess.remove_absolute(import_path)
	
	print("  ✓ Invalid lines skipped correctly")
	return true

func test_import_with_invalid_schema() -> bool:
	print("Test: Import with invalid event schema")
	
	# Create test file with events missing required fields
	var import_path := "user://test_import_invalid_schema.ndjson"
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	if not file:
		print("  ✗ Failed to create test file")
		return false
	
	# Event missing 'ts'
	var invalid1 := {
		"session_id": "test",
		"event": "invalid.event",
		"data": {}
	}
	file.store_line(JSON.stringify(invalid1))
	
	# Event missing 'data'
	var invalid2 := {
		"ts": Time.get_unix_time_from_system(),
		"session_id": "test",
		"event": "invalid.event2"
	}
	file.store_line(JSON.stringify(invalid2))
	
	# Valid event
	var valid := {
		"ts": Time.get_unix_time_from_system(),
		"session_id": "test",
		"event": "valid.event",
		"data": {"value": 1}
	}
	file.store_line(JSON.stringify(valid))
	
	file.close()
	
	# Import
	var store := EventStore.new()
	var result := store.import_from_ndjson(import_path)
	
	# Should import only the valid event
	var imported := result.get("imported", 0)
	var skipped := result.get("skipped", 0)
	
	if imported != 1:
		print("  ✗ Expected 1 imported event, got %d" % imported)
		return false
	
	if skipped != 2:
		print("  ✗ Expected 2 skipped events, got %d" % skipped)
		return false
	
	# Clean up
	DirAccess.remove_absolute(import_path)
	
	print("  ✓ Invalid schema events skipped correctly")
	return true

func test_import_appends() -> bool:
	print("Test: Import appends to existing data")
	
	# Create EventStore with existing events
	var store := EventStore.new()
	
	# Add initial events
	for i in range(2):
		var event := {
			"ts": Time.get_unix_time_from_system() + i,
			"session_id": "existing",
			"event": "existing.event%d" % i,
			"ver": 1,
			"seq": i,
			"data": {"existing": true}
		}
		store.add_to_ring_buffer(event)
	
	var initial_count := store.ring_buffer.size()
	
	# Create import file
	var import_path := "user://test_import_append.ndjson"
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	if not file:
		print("  ✗ Failed to create test file")
		return false
	
	# Add new events
	for i in range(2):
		var event := {
			"ts": Time.get_unix_time_from_system() + 100 + i,
			"session_id": "imported",
			"event": "imported.event%d" % i,
			"ver": 1,
			"seq": i,
			"data": {"imported": true}
		}
		file.store_line(JSON.stringify(event))
	
	file.close()
	
	# Import
	var result := store.import_from_ndjson(import_path)
	
	if not result.get("success", false):
		print("  ✗ Import failed")
		return false
	
	# Should have initial + imported events
	var expected_total := initial_count + 2
	if store.ring_buffer.size() != expected_total:
		print("  ✗ Expected %d total events, got %d" % [expected_total, store.ring_buffer.size()])
		return false
	
	# Verify we have both existing and imported events
	var has_existing := false
	var has_imported := false
	
	for event in store.ring_buffer:
		var session_id = event.get("session_id", "")
		if session_id == "existing":
			has_existing = true
		elif session_id == "imported":
			has_imported = true
	
	if not (has_existing and has_imported):
		print("  ✗ Import should append to existing data")
		return false
	
	# Clean up
	DirAccess.remove_absolute(import_path)
	
	print("  ✓ Import appends to existing data correctly")
	return true
