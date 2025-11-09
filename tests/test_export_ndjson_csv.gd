## Test Export/Import: Verify NDJSON and CSV export/import functionality
## 
## Tests that events can be exported and imported correctly.

extends Node

func _ready() -> void:
	print("=== Running Export/Import Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Export to NDJSON
	all_passed = test_export_ndjson() and all_passed
	
	# Test 2: Export to CSV
	all_passed = test_export_csv() and all_passed
	
	# Test 3: Import from NDJSON
	all_passed = test_import_ndjson() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All export/import tests passed!")
	else:
		print("✗ Some export/import tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_export_ndjson() -> bool:
	print("Test: Export to NDJSON")
	
	# Create EventStore with test events
	var store := EventStore.new()
	
	# Add test events
	for i in range(3):
		var event := {
			"ts": Time.get_unix_time_from_system() + i,
			"session_id": "test-session",
			"event": "test.event%d" % i,
			"ver": 1,
			"seq": i,
			"data": {"value": i * 10},
			"meta": {"wave": i}
		}
		store.add_to_ring_buffer(event)
	
	# Export to NDJSON
	var output_path := "user://test_export.ndjson"
	var success := store.export_to_ndjson(output_path)
	
	if not success:
		print("  ✗ Failed to export to NDJSON")
		return false
	
	# Verify file exists
	if not FileAccess.file_exists(output_path):
		print("  ✗ Export file not created")
		return false
	
	# Read and verify content
	var file := FileAccess.open(output_path, FileAccess.READ)
	if not file:
		print("  ✗ Failed to open exported file")
		return false
	
	var line_count := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.is_empty():
			line_count += 1
			
			# Parse JSON
			var json := JSON.new()
			var err := json.parse(line)
			if err != OK:
				print("  ✗ Invalid JSON in export: %s" % line)
				file.close()
				return false
	
	file.close()
	
	if line_count != 3:
		print("  ✗ Expected 3 lines in export, got %d" % line_count)
		return false
	
	# Clean up
	DirAccess.remove_absolute(output_path)
	
	print("  ✓ NDJSON export working correctly")
	return true

func test_export_csv() -> bool:
	print("Test: Export to CSV")
	
	# Create EventStore with test events
	var store := EventStore.new()
	
	# Add test events
	for i in range(3):
		var event := {
			"ts": Time.get_unix_time_from_system() + i,
			"session_id": "test-session",
			"event": "test.csv%d" % i,
			"ver": 1,
			"seq": i,
			"data": {"value": i * 10, "name": "item%d" % i},
			"meta": {"wave": i, "gold": 100.0 * i}
		}
		store.add_to_ring_buffer(event)
	
	# Export to CSV
	var output_path := "user://test_export.csv"
	var success := store.export_to_csv(output_path)
	
	if not success:
		print("  ✗ Failed to export to CSV")
		return false
	
	# Verify file exists
	if not FileAccess.file_exists(output_path):
		print("  ✗ CSV export file not created")
		return false
	
	# Read and verify content
	var file := FileAccess.open(output_path, FileAccess.READ)
	if not file:
		print("  ✗ Failed to open CSV export file")
		return false
	
	# Read header
	var header := file.get_csv_line()
	if header.is_empty():
		print("  ✗ CSV header is empty")
		file.close()
		return false
	
	# Should have columns like: ts, session_id, event, seq, ver, data.*, meta.*
	var has_ts := "ts" in header
	var has_event := "event" in header
	var has_data_value := "data.value" in header
	var has_meta_wave := "meta.wave" in header
	
	if not (has_ts and has_event and has_data_value and has_meta_wave):
		print("  ✗ CSV header missing expected columns")
		print("    Header: %s" % str(header))
		file.close()
		return false
	
	# Count data rows
	var row_count := 0
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.is_empty() or (row.size() == 1 and row[0].is_empty()):
			continue
		row_count += 1
	
	file.close()
	
	if row_count != 3:
		print("  ✗ Expected 3 data rows in CSV, got %d" % row_count)
		return false
	
	# Clean up
	DirAccess.remove_absolute(output_path)
	
	print("  ✓ CSV export working correctly")
	return true

func test_import_ndjson() -> bool:
	print("Test: Import from NDJSON")
	
	# Create test NDJSON file
	var import_path := "user://test_import.ndjson"
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	if not file:
		print("  ✗ Failed to create test import file")
		return false
	
	# Write test events
	for i in range(3):
		var event := {
			"ts": Time.get_unix_time_from_system() + i,
			"session_id": "import-test",
			"event": "imported.event%d" % i,
			"ver": 1,
			"seq": i,
			"data": {"imported": true, "index": i}
		}
		file.store_line(JSON.stringify(event))
	
	file.close()
	
	# Import using EventStore
	var store := EventStore.new()
	var result := store.import_from_ndjson(import_path)
	
	if not result.get("success", false):
		print("  ✗ Import failed")
		return false
	
	var imported_count: int = int(result.get("imported", 0))
	if imported_count != 3:
		print("  ✗ Expected 3 imported events, got %d" % imported_count)
		return false
	
	# Verify events are in ring buffer
	if store.ring_buffer.size() != 3:
		print("  ✗ Expected 3 events in ring buffer, got %d" % store.ring_buffer.size())
		return false
	
	# Verify event data
	var first_event = store.ring_buffer[0]
	if first_event.get("event", "") != "imported.event0":
		print("  ✗ Imported event data incorrect")
		return false
	
	if not first_event.get("data", {}).get("imported", false):
		print("  ✗ Imported event data missing expected field")
		return false
	
	# Clean up
	DirAccess.remove_absolute(import_path)
	
	print("  ✓ NDJSON import working correctly")
	return true
