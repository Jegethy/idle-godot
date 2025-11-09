extends RefCounted
## EventStore: Local file-based event queue with ring buffer
## 
## Manages buffered NDJSON event storage with atomic writes,
## daily rotation, and in-memory ring buffer for UI display.

class_name EventStore

# In-memory ring buffer for recent events
var ring_buffer: Array = []
var ring_buffer_max_size: int = AnalyticsConstants.RING_BUFFER_SIZE

# File storage
var telemetry_dir: String = AnalyticsConstants.TELEMETRY_DIR
var current_file_path: String = ""
var events_written_today: int = 0

# Signals
signal event_stored(event: Dictionary)
signal buffer_updated()

func _init() -> void:
	_ensure_telemetry_dir()
	_update_current_file_path()

## Ensure telemetry directory exists
func _ensure_telemetry_dir() -> void:
	if not DirAccess.dir_exists_absolute(telemetry_dir):
		var err := DirAccess.make_dir_recursive_absolute(telemetry_dir)
		if err != OK:
			push_error("Failed to create telemetry directory: %d" % err)

## Update current file path based on date
func _update_current_file_path() -> void:
	var date := Time.get_datetime_dict_from_system()
	var date_str := "%04d%02d%02d" % [date.year, date.month, date.day]
	current_file_path = telemetry_dir + AnalyticsConstants.EVENT_FILE_PREFIX + date_str + AnalyticsConstants.EVENT_FILE_EXTENSION

## Append event to ring buffer
func add_to_ring_buffer(event: Dictionary) -> void:
	ring_buffer.append(event)
	
	# Trim buffer if exceeds max size
	while ring_buffer.size() > ring_buffer_max_size:
		ring_buffer.pop_front()
	
	buffer_updated.emit()

## Store event to file (atomic write)
func store_event(event: Dictionary) -> bool:
	# Update file path in case date changed
	_update_current_file_path()
	
	# Convert event to JSON line
	var json_line := JSON.stringify(event) + "\n"
	
	# Atomic write using temp file + rename
	var temp_path := current_file_path + ".tmp"
	
	# Append to existing file or create new
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open temp file for writing: %s" % temp_path)
		return false
	
	# If main file exists, copy its contents first
	if FileAccess.file_exists(current_file_path):
		var existing := FileAccess.open(current_file_path, FileAccess.READ)
		if existing:
			file.store_string(existing.get_as_text())
			existing.close()
	
	# Append new event
	file.store_string(json_line)
	file.close()
	
	# Atomic rename
	var dir := DirAccess.open(telemetry_dir)
	if dir:
		# Remove existing if it exists
		if FileAccess.file_exists(current_file_path):
			dir.remove(current_file_path.get_file())
		
		# Rename temp to final
		var err := dir.rename(temp_path.get_file(), current_file_path.get_file())
		if err != OK:
			push_error("Failed to rename temp file: %d" % err)
			return false
	
	events_written_today += 1
	event_stored.emit(event)
	return true

## Store multiple events in batch
func store_batch(events: Array) -> int:
	var success_count := 0
	
	for event in events:
		if event is Dictionary:
			if store_event(event):
				success_count += 1
	
	return success_count

## Get recent events from ring buffer
func get_recent_events(count: int = -1) -> Array:
	if count < 0 or count > ring_buffer.size():
		return ring_buffer.duplicate()
	
	var start_idx := max(0, ring_buffer.size() - count)
	return ring_buffer.slice(start_idx)

## Export events to NDJSON file
func export_to_ndjson(output_path: String, filter_prefix: String = "", max_rows: int = -1) -> bool:
	var exported_count := 0
	
	var output_file := FileAccess.open(output_path, FileAccess.WRITE)
	if not output_file:
		push_error("Failed to open output file: %s" % output_path)
		return false
	
	# Export from ring buffer (most recent)
	for event in ring_buffer:
		if max_rows > 0 and exported_count >= max_rows:
			break
		
		# Apply prefix filter
		if not filter_prefix.is_empty():
			if not event.get("event", "").begins_with(filter_prefix):
				continue
		
		var json_line := JSON.stringify(event) + "\n"
		output_file.store_string(json_line)
		exported_count += 1
	
	output_file.close()
	print("Exported %d events to %s" % [exported_count, output_path])
	return true

## Export events to CSV file (flattened)
func export_to_csv(output_path: String, filter_prefix: String = "", max_rows: int = -1) -> bool:
	var exported_count := 0
	
	var output_file := FileAccess.open(output_path, FileAccess.WRITE)
	if not output_file:
		push_error("Failed to open output file: %s" % output_path)
		return false
	
	# Collect all unique keys for CSV header
	var all_keys := {}
	for event in ring_buffer:
		if not filter_prefix.is_empty():
			if not event.get("event", "").begins_with(filter_prefix):
				continue
		
		# Add standard keys
		for key in ["ts", "session_id", "event", "seq", "ver"]:
			all_keys[key] = true
		
		# Add meta keys
		if event.has("meta") and event.meta is Dictionary:
			for meta_key in event.meta:
				all_keys["meta." + meta_key] = true
		
		# Add data keys
		if event.has("data") and event.data is Dictionary:
			for data_key in event.data:
				all_keys["data." + data_key] = true
	
	# Write CSV header
	var header_keys := all_keys.keys()
	header_keys.sort()
	output_file.store_csv_line(header_keys)
	
	# Write rows
	for event in ring_buffer:
		if max_rows > 0 and exported_count >= max_rows:
			break
		
		# Apply prefix filter
		if not filter_prefix.is_empty():
			if not event.get("event", "").begins_with(filter_prefix):
				continue
		
		# Build row values
		var row := []
		for key in header_keys:
			var value = _get_nested_value(event, key)
			row.append(str(value) if value != null else "")
		
		output_file.store_csv_line(row)
		exported_count += 1
	
	output_file.close()
	print("Exported %d events to CSV: %s" % [exported_count, output_path])
	return true

## Get nested dictionary value by dotted key path
func _get_nested_value(dict: Dictionary, key_path: String) -> Variant:
	if not "." in key_path:
		return dict.get(key_path, null)
	
	var parts := key_path.split(".", false, 1)
	var first := parts[0]
	var rest := parts[1] if parts.size() > 1 else ""
	
	if not dict.has(first):
		return null
	
	if rest.is_empty():
		return dict[first]
	
	if dict[first] is Dictionary:
		return _get_nested_value(dict[first], rest)
	
	return null

## Import events from NDJSON file
func import_from_ndjson(input_path: String) -> Dictionary:
	var input_file := FileAccess.open(input_path, FileAccess.READ)
	if not input_file:
		push_error("Failed to open input file: %s" % input_path)
		return {"success": false, "imported": 0, "skipped": 0}
	
	var imported := 0
	var skipped := 0
	
	while not input_file.eof_reached():
		var line := input_file.get_line().strip_edges()
		if line.is_empty():
			continue
		
		# Parse JSON
		var json := JSON.new()
		var err := json.parse(line)
		if err != OK:
			skipped += 1
			continue
		
		var event = json.data
		if not event is Dictionary:
			skipped += 1
			continue
		
		# Validate event structure
		if not Anonymizer.validate_event(event):
			skipped += 1
			continue
		
		# Store event
		if store_event(event):
			add_to_ring_buffer(event)
			imported += 1
		else:
			skipped += 1
	
	input_file.close()
	print("Imported %d events, skipped %d" % [imported, skipped])
	return {"success": true, "imported": imported, "skipped": skipped}

## Delete all analytics data
func delete_all_data() -> bool:
	# Clear ring buffer
	ring_buffer.clear()
	buffer_updated.emit()
	
	# Delete all event files
	var dir := DirAccess.open(telemetry_dir)
	if not dir:
		push_error("Failed to open telemetry directory")
		return false
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	var deleted_count := 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(AnalyticsConstants.EVENT_FILE_EXTENSION):
			var err := dir.remove(file_name)
			if err == OK:
				deleted_count += 1
			else:
				push_warning("Failed to delete file: %s (error %d)" % [file_name, err])
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	print("Deleted %d analytics data files" % deleted_count)
	events_written_today = 0
	return true

## Get total count of events in ring buffer
func get_event_count() -> int:
	return ring_buffer.size()
