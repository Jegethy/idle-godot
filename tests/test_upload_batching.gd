## Test Upload Batching: Verify batch size limits are respected
## 
## Tests that large event lists are split across multiple batches.

extends SceneTree

func _init() -> void:
	print("=== Running Upload Batching Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Batch respects max_events limit
	print("Test 1: Batch respects max_events limit")
	var passed := test_max_events_limit()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 2: Batch respects max_bytes limit
	print("Test 2: Batch respects max_bytes limit")
	passed = test_max_bytes_limit()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 3: Cursor advancement after batch read
	print("Test 3: Cursor advancement after batch read")
	passed = test_cursor_advancement()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Summary
	print("=== Summary ===")
	if all_passed:
		print("✓ All upload batching tests passed!")
		quit(0)
	else:
		print("✗ Some upload batching tests failed")
		quit(1)

func test_max_events_limit() -> bool:
	var store := EventStore.new()
	
	# Create a temporary file with many events
	var temp_file_path := "user://test_events_batch.ndjson"
	var file := FileAccess.open(temp_file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create temp file")
		return false
	
	# Write 100 test events
	for i in range(100):
		var event := {
			"ts": Time.get_unix_time_from_system(),
			"session_id": "test",
			"event": "test.event",
			"seq": i,
			"ver": 1,
			"data": {"index": i}
		}
		file.store_line(JSON.stringify(event))
	file.close()
	
	# Read batch with max_events = 25
	var cursor := {"file_path": temp_file_path, "line_index": 0}
	var batch_result := store.read_batch(cursor, 25, 1000000)  # Large byte limit
	
	var events: Array = batch_result["events"]
	var next_cursor: Dictionary = batch_result["next_cursor"]
	var has_more: bool = batch_result["has_more"]
	
	# Should have exactly 25 events
	if events.size() != 25:
		push_error("Expected 25 events, got %d" % events.size())
		DirAccess.remove_absolute(temp_file_path)
		return false
	
	# Should have more events
	if not has_more:
		push_error("Should indicate more events available")
		DirAccess.remove_absolute(temp_file_path)
		return false
	
	# Cursor should advance
	if next_cursor["line_index"] != 25:
		push_error("Cursor should be at line 25, got %d" % next_cursor["line_index"])
		DirAccess.remove_absolute(temp_file_path)
		return false
	
	print("  ✓ Batch limited to %d events" % events.size())
	
	# Clean up
	DirAccess.remove_absolute(temp_file_path)
	return true

func test_max_bytes_limit() -> bool:
	var store := EventStore.new()
	
	# Create a temporary file with large events
	var temp_file_path := "user://test_bytes_batch.ndjson"
	var file := FileAccess.open(temp_file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create temp file")
		return false
	
	# Write events with large data
	var large_string := ""
	for i in range(500):
		large_string += "x"
	
	for i in range(100):
		var event := {
			"ts": Time.get_unix_time_from_system(),
			"session_id": "test",
			"event": "test.large_event",
			"seq": i,
			"ver": 1,
			"data": {"large_field": large_string, "index": i}
		}
		file.store_line(JSON.stringify(event))
	file.close()
	
	# Read batch with max_bytes = 5000 (should fit ~7-8 events with overhead)
	var cursor := {"file_path": temp_file_path, "line_index": 0}
	var batch_result := store.read_batch(cursor, 1000, 5000)  # Large event limit, small byte limit
	
	var events: Array = batch_result["events"]
	
	# Should have fewer than 10 events due to byte limit
	if events.size() >= 10:
		push_error("Byte limit not enforced, got %d events" % events.size())
		DirAccess.remove_absolute(temp_file_path)
		return false
	
	# Should have at least 1 event
	if events.size() < 1:
		push_error("Should have at least 1 event")
		DirAccess.remove_absolute(temp_file_path)
		return false
	
	print("  ✓ Byte limit enforced (%d events fit in 5000 bytes)" % events.size())
	
	# Clean up
	DirAccess.remove_absolute(temp_file_path)
	return true

func test_cursor_advancement() -> bool:
	var store := EventStore.new()
	
	# Create a temporary file
	var temp_file_path := "user://test_cursor.ndjson"
	var file := FileAccess.open(temp_file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to create temp file")
		return false
	
	# Write 30 events
	for i in range(30):
		var event := {
			"ts": Time.get_unix_time_from_system(),
			"session_id": "test",
			"event": "test.cursor",
			"seq": i,
			"ver": 1,
			"data": {"index": i}
		}
		file.store_line(JSON.stringify(event))
	file.close()
	
	# Read first batch (10 events)
	var cursor := {"file_path": temp_file_path, "line_index": 0}
	var batch1 := store.read_batch(cursor, 10, 1000000)
	
	# Read second batch (10 events) using cursor from first
	var batch2 := store.read_batch(batch1["next_cursor"], 10, 1000000)
	
	# Read third batch (10 events) using cursor from second
	var batch3 := store.read_batch(batch2["next_cursor"], 10, 1000000)
	
	# Verify we got all 30 events across 3 batches
	var total_events := batch1["events"].size() + batch2["events"].size() + batch3["events"].size()
	if total_events != 30:
		push_error("Expected 30 total events, got %d" % total_events)
		DirAccess.remove_absolute(temp_file_path)
		return false
	
	# Third batch should have no more events
	if batch3["has_more"]:
		push_error("Third batch should not have more events")
		DirAccess.remove_absolute(temp_file_path)
		return false
	
	print("  ✓ Cursor advanced correctly through 3 batches")
	
	# Clean up
	DirAccess.remove_absolute(temp_file_path)
	return true
