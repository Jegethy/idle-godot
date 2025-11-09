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
	
	var start_idx: int = max(0, ring_buffer.size() - count)
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

## Read a batch of events from file with cursor tracking
## Returns {events: Array, next_cursor: Dictionary, has_more: bool}
func read_batch(cursor: Dictionary, max_events: int, max_bytes: int) -> Dictionary:
	var events: Array = []
	var total_bytes := 0
	var file_path: String = cursor.get("file_path", current_file_path)
	var line_index: int = cursor.get("line_index", 0)
	
	# Check if file exists
	if not FileAccess.file_exists(file_path):
		# Try current file
		if file_path != current_file_path and FileAccess.file_exists(current_file_path):
			file_path = current_file_path
			line_index = 0
		else:
			return {"events": [], "next_cursor": cursor, "has_more": false}
	
	# Open file for reading
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open event file for reading: %s" % file_path)
		return {"events": [], "next_cursor": cursor, "has_more": false}
	
	# Skip to cursor position
	var current_line := 0
	while current_line < line_index and not file.eof_reached():
		file.get_line()
		current_line += 1
	
	# Read events up to limits
	while not file.eof_reached() and events.size() < max_events and total_bytes < max_bytes:
		var line := file.get_line().strip_edges()
		if line.is_empty():
			current_line += 1
			continue
		
		# Parse JSON
		var json := JSON.new()
		var err := json.parse(line)
		if err != OK:
			push_warning("Failed to parse event JSON at line %d" % current_line)
			current_line += 1
			continue
		
		var event = json.data
		if not event is Dictionary:
			current_line += 1
			continue
		
		# Add to batch
		events.append(event)
		total_bytes += line.length()
		current_line += 1
	
	file.close()
	
	# Build next cursor
	var next_cursor := {
		"file_path": file_path,
		"line_index": current_line
	}
	
	var has_more := not file.eof_reached()
	
	return {
		"events": events,
		"next_cursor": next_cursor,
		"has_more": has_more
	}

## Save cursor to file
func save_cursor(cursor: Dictionary) -> bool:
	var cursor_path := telemetry_dir + "upload.cursor"
	var file := FileAccess.open(cursor_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save cursor file")
		return false
	
	file.store_string(JSON.stringify(cursor, "\t"))
	file.close()
	return true

## Load cursor from file
func load_cursor() -> Dictionary:
	var cursor_path := telemetry_dir + "upload.cursor"
	if not FileAccess.file_exists(cursor_path):
		return {}
	
	var file := FileAccess.open(cursor_path, FileAccess.READ)
	if not file:
		return {}
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		return {}
	
	var cursor = json.data
	if cursor is Dictionary:
		return cursor
	
	return {}

## Mark current file as done (fully uploaded)
func mark_file_done(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return false
	
	# Rename to .done
	var done_path := file_path + UploadConstants.DONE_FILE_SUFFIX
	var dir := DirAccess.open(telemetry_dir)
	if not dir:
		return false
	
	# Remove existing .done file if present
	if FileAccess.file_exists(done_path):
		dir.remove(done_path.get_file())
	
	# Rename
	var err := dir.rename(file_path.get_file(), done_path.get_file())
	return err == OK

## Enforce disk cap by removing oldest .done files
func enforce_disk_cap(cap_bytes: int) -> void:
	var dir := DirAccess.open(telemetry_dir)
	if not dir:
		return
	
	# Collect all files with sizes and timestamps
	var files: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir():
			var full_path := telemetry_dir + file_name
			var size := FileAccess.get_file_as_string(full_path).length()
			var modified := FileAccess.get_modified_time(full_path)
			files.append({
				"name": file_name,
				"path": full_path,
				"size": size,
				"modified": modified,
				"is_done": file_name.ends_with(UploadConstants.DONE_FILE_SUFFIX)
			})
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Calculate total size
	var total_size := 0
	for file_info in files:
		total_size += file_info["size"]
	
	# If under cap, nothing to do
	if total_size <= cap_bytes:
		return
	
	# Sort by modified time (oldest first)
	files.sort_custom(func(a, b): return a["modified"] < b["modified"])
	
	# Remove oldest .done files first
	for file_info in files:
		if total_size <= cap_bytes:
			break
		
		if file_info["is_done"]:
			var err := dir.remove(file_info["name"])
			if err == OK:
				total_size -= file_info["size"]
				print("Removed old analytics file: %s (freed %d bytes)" % [file_info["name"], file_info["size"]])
	
	# If still over cap, remove oldest active files (with warning)
	if total_size > cap_bytes:
		for file_info in files:
			if total_size <= cap_bytes:
				break
			
			if not file_info["is_done"]:
				var err := dir.remove(file_info["name"])
				if err == OK:
					total_size -= file_info["size"]
					push_warning("Disk cap exceeded: removed active analytics file %s" % file_info["name"])
