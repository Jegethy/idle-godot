extends Node
## AnalyticsService: Opt-in analytics and telemetry system
## 
## Captures gameplay events with privacy-first design:
## - Opt-in only (default OFF)
## - No PII (Personal Identifiable Information)
## - Local storage only (no network by default)
## - Data minimization with sampling/throttling
## - User-controlled deletion

# Settings
var enabled: bool = false
var project_id: String = AnalyticsConstants.PROJECT_ID
var session_id: String = ""
var session_sample_rate: float = 1.0
var event_sample_overrides: Dictionary = {}
var throttle_windows: Dictionary = {}
var ring_buffer_size: int = AnalyticsConstants.RING_BUFFER_SIZE

# Components
var event_store: EventStore = null
var transport: Transport = null
var uploader: AnalyticsUploader = null

# Session state
var session_start_time: float = 0.0
var event_sequence: int = 0
var events_this_session: int = 0
var events_dropped: int = 0

# Throttle tracking
var last_event_times: Dictionary = {}  # {event_name: timestamp}

# Signals
signal analytics_enabled_changed(is_enabled: bool)
signal event_emitted(event_name: String)

func _ready() -> void:
	# Initialize components
	event_store = EventStore.new()
	transport = NoopTransport.new()
	uploader = AnalyticsUploader.new()
	add_child(uploader)
	
	# Load settings
	_load_settings()
	
	# Start session if enabled
	if enabled:
		_start_session()
	
	# Initialize uploader with settings
	uploader.initialize(_get_upload_settings(), event_store, project_id, session_id)
	
	print("AnalyticsService initialized (enabled: %s)" % enabled)

## Load settings from file
func _load_settings() -> void:
	var settings_path := AnalyticsConstants.SETTINGS_FILE
	
	# Ensure directory exists
	var dir_path := settings_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	
	# Check if settings file exists
	if not FileAccess.file_exists(settings_path):
		# Create default settings
		_save_default_settings()
		return
	
	# Load settings
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if not file:
		push_error("Failed to open analytics settings file")
		_apply_default_settings()
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		push_error("Failed to parse analytics settings: %s" % json.get_error_message())
		_apply_default_settings()
		return
	
	var settings = json.data
	if not settings is Dictionary:
		_apply_default_settings()
		return
	
	# Apply settings
	enabled = settings.get("enabled", AnalyticsConstants.DEFAULT_ENABLED)
	project_id = settings.get("project_id", AnalyticsConstants.PROJECT_ID)
	session_sample_rate = settings.get("session_sample_rate", AnalyticsConstants.DEFAULT_SESSION_SAMPLE_RATE)
	event_sample_overrides = settings.get("event_sample_overrides", {})
	throttle_windows = settings.get("throttle", AnalyticsConstants.DEFAULT_THROTTLE)
	ring_buffer_size = settings.get("ring_buffer_size", AnalyticsConstants.RING_BUFFER_SIZE)
	
	# Update event store buffer size
	if event_store:
		event_store.ring_buffer_max_size = ring_buffer_size

## Save default settings to file
func _save_default_settings() -> void:
	_apply_default_settings()
	save_settings()

## Apply default settings
func _apply_default_settings() -> void:
	enabled = AnalyticsConstants.DEFAULT_ENABLED
	project_id = AnalyticsConstants.PROJECT_ID
	session_sample_rate = AnalyticsConstants.DEFAULT_SESSION_SAMPLE_RATE
	event_sample_overrides = AnalyticsConstants.DEFAULT_EVENT_SAMPLE_OVERRIDES
	throttle_windows = AnalyticsConstants.DEFAULT_THROTTLE
	ring_buffer_size = AnalyticsConstants.RING_BUFFER_SIZE

## Save current settings to file
func save_settings() -> bool:
	var settings := {
		"enabled": enabled,
		"project_id": project_id,
		"session_sample_rate": session_sample_rate,
		"event_sample_overrides": event_sample_overrides,
		"throttle": throttle_windows,
		"ring_buffer_size": ring_buffer_size,
		"file_rotation_daily": AnalyticsConstants.FILE_ROTATION_DAILY
	}
	
	var settings_path := AnalyticsConstants.SETTINGS_FILE
	var file := FileAccess.open(settings_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save analytics settings")
		return false
	
	file.store_string(JSON.stringify(settings, "\t"))
	file.close()
	return true

## Enable or disable analytics
func set_enabled(is_enabled: bool) -> void:
	if enabled == is_enabled:
		return
	
	enabled = is_enabled
	
	if enabled:
		_start_session()
	else:
		_end_session()
	
	save_settings()
	analytics_enabled_changed.emit(enabled)

## Start analytics session
func _start_session() -> void:
	session_id = Anonymizer.generate_session_id()
	session_start_time = Time.get_unix_time_from_system()
	event_sequence = 0
	events_this_session = 0
	events_dropped = 0
	last_event_times.clear()
	
	# Emit session start event
	emit_event("session.start", {
		"session_id": session_id,
		"version": ProjectSettings.get_setting("application/config/version", "unknown")
	})

## End analytics session
func _end_session() -> void:
	if session_id.is_empty():
		return
	
	var duration := Time.get_unix_time_from_system() - session_start_time
	
	# Emit session end event
	emit_event("session.end", {
		"session_id": session_id,
		"duration": duration,
		"events_recorded": events_this_session,
		"events_dropped": events_dropped
	})
	
	session_id = ""

## Emit an analytics event
func emit_event(event_name: String, data: Dictionary, skip_throttle: bool = false) -> bool:
	# Check if analytics is enabled
	if not enabled:
		return false
	
	# Check session sampling
	if not _should_sample_session():
		events_dropped += 1
		return false
	
	# Check event-specific sampling
	if not _should_sample_event(event_name):
		events_dropped += 1
		return false
	
	# Check throttling
	if not skip_throttle and not _should_emit_throttled(event_name):
		events_dropped += 1
		return false
	
	# Build event
	var event := _build_event(event_name, data)
	
	# Validate and sanitize
	event["data"] = Anonymizer.sanitize_event_data(event["data"])
	
	if not Anonymizer.validate_event(event):
		push_warning("Invalid event dropped: %s" % event_name)
		events_dropped += 1
		return false
	
	# Store event
	event_store.add_to_ring_buffer(event)
	
	# Batch write to file
	if events_this_session % AnalyticsConstants.BATCH_FLUSH_SIZE == 0:
		event_store.store_event(event)
	else:
		# Async write for performance
		event_store.store_event.call_deferred(event)
	
	# Update counters
	events_this_session += 1
	event_sequence += 1
	
	# Update throttle tracking
	last_event_times[event_name] = Time.get_unix_time_from_system()
	
	event_emitted.emit(event_name)
	return true

## Build event dictionary
func _build_event(event_name: String, data: Dictionary) -> Dictionary:
	var event := {
		"ts": Time.get_unix_time_from_system(),
		"session_id": session_id,
		"event": event_name,
		"ver": AnalyticsConstants.SCHEMA_VERSION,
		"seq": event_sequence,
		"data": data,
		"meta": _build_meta_context()
	}
	
	return event

## Build enriched metadata context
func _build_meta_context() -> Dictionary:
	var meta := {}
	
	# Add current wave
	if GameState:
		meta["wave"] = GameState.current_wave
		
		# Add gold
		if GameState.resources.has("gold"):
			meta["gold"] = GameState.resources["gold"].amount
		
		# Add essence
		meta["essence"] = GameState.essence
	
	# Add FPS (lightweight performance metric)
	meta["fps"] = Engine.get_frames_per_second()
	
	return meta

## Check if session should be sampled
func _should_sample_session() -> bool:
	# For simplicity, always sample (controlled by enabled flag)
	# Could implement probabilistic sampling here
	return session_sample_rate >= 1.0 or randf() < session_sample_rate

## Check if specific event type should be sampled
func _should_sample_event(event_name: String) -> bool:
	var sample_rate := event_sample_overrides.get(event_name, 1.0)
	return sample_rate >= 1.0 or randf() < sample_rate

## Check if event should be emitted based on throttle rules
func _should_emit_throttled(event_name: String) -> bool:
	if not throttle_windows.has(event_name):
		return true
	
	var throttle_window := throttle_windows[event_name]
	var last_time := last_event_times.get(event_name, 0.0)
	var current_time := Time.get_unix_time_from_system()
	
	return (current_time - last_time) >= throttle_window

## Get recent events for UI
func get_recent_events(count: int = -1) -> Array:
	if not event_store:
		return []
	return event_store.get_recent_events(count)

## Get session statistics
func get_session_stats() -> Dictionary:
	var duration := 0.0
	if session_start_time > 0:
		duration = Time.get_unix_time_from_system() - session_start_time
	
	var events_per_sec := 0.0
	if duration > 0:
		events_per_sec = events_this_session / duration
	
	return {
		"session_id": session_id,
		"duration": duration,
		"events_recorded": events_this_session,
		"events_dropped": events_dropped,
		"events_per_sec": events_per_sec,
		"total_in_buffer": event_store.get_event_count() if event_store else 0
	}

## Export events to NDJSON
func export_ndjson(output_path: String, filter_prefix: String = "", max_rows: int = -1) -> bool:
	if not event_store:
		return false
	return event_store.export_to_ndjson(output_path, filter_prefix, max_rows)

## Export events to CSV
func export_csv(output_path: String, filter_prefix: String = "", max_rows: int = -1) -> bool:
	if not event_store:
		return false
	return event_store.export_to_csv(output_path, filter_prefix, max_rows)

## Import events from NDJSON
func import_ndjson(input_path: String) -> Dictionary:
	if not event_store:
		return {"success": false, "imported": 0, "skipped": 0}
	return event_store.import_from_ndjson(input_path)

## Delete all analytics data
func delete_all_data() -> bool:
	if not event_store:
		return false
	
	# Reset session counters
	events_this_session = 0
	events_dropped = 0
	event_sequence = 0
	
	return event_store.delete_all_data()

## Clean up on exit
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if enabled:
			_end_session()

## Get upload settings as a dictionary for uploader
func _get_upload_settings() -> Dictionary:
	return {
		"cloud_upload_enabled": false,  # Will be loaded from file
		"endpoint_url": "",
		"api_key": "",
		"api_secret": "",
		"upload_interval_sec": UploadConstants.DEFAULT_UPLOAD_INTERVAL_SEC,
		"max_batch_events": UploadConstants.DEFAULT_MAX_BATCH_EVENTS,
		"max_batch_bytes": UploadConstants.DEFAULT_MAX_BATCH_BYTES,
		"disk_cap_bytes": UploadConstants.DEFAULT_DISK_CAP_BYTES,
		"backoff_base_sec": UploadConstants.BACKOFF_BASE_SEC,
		"backoff_factor": UploadConstants.BACKOFF_FACTOR,
		"backoff_max_sec": UploadConstants.BACKOFF_MAX_SEC,
		"backoff_jitter_ratio": UploadConstants.BACKOFF_JITTER_RATIO
	}

## Load upload settings from file (called after _load_settings)
func load_upload_settings() -> Dictionary:
	var settings_path := AnalyticsConstants.SETTINGS_FILE
	
	if not FileAccess.file_exists(settings_path):
		return _get_upload_settings()
	
	var file := FileAccess.open(settings_path, FileAccess.READ)
	if not file:
		return _get_upload_settings()
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		return _get_upload_settings()
	
	var settings = json.data
	if not settings is Dictionary:
		return _get_upload_settings()
	
	# Extract upload-related settings
	var upload_settings := _get_upload_settings()
	upload_settings["cloud_upload_enabled"] = settings.get("cloud_upload_enabled", false)
	upload_settings["endpoint_url"] = settings.get("endpoint_url", "")
	upload_settings["api_key"] = settings.get("api_key", "")
	upload_settings["api_secret"] = settings.get("api_secret", "")
	upload_settings["upload_interval_sec"] = settings.get("upload_interval_sec", UploadConstants.DEFAULT_UPLOAD_INTERVAL_SEC)
	upload_settings["max_batch_events"] = settings.get("max_batch_events", UploadConstants.DEFAULT_MAX_BATCH_EVENTS)
	upload_settings["max_batch_bytes"] = settings.get("max_batch_bytes", UploadConstants.DEFAULT_MAX_BATCH_BYTES)
	upload_settings["disk_cap_bytes"] = settings.get("disk_cap_bytes", UploadConstants.DEFAULT_DISK_CAP_BYTES)
	upload_settings["backoff_base_sec"] = settings.get("backoff_base_sec", UploadConstants.BACKOFF_BASE_SEC)
	upload_settings["backoff_factor"] = settings.get("backoff_factor", UploadConstants.BACKOFF_FACTOR)
	upload_settings["backoff_max_sec"] = settings.get("backoff_max_sec", UploadConstants.BACKOFF_MAX_SEC)
	upload_settings["backoff_jitter_ratio"] = settings.get("backoff_jitter_ratio", UploadConstants.BACKOFF_JITTER_RATIO)
	
	return upload_settings

## Reload uploader settings and reinitialize
func reload_uploader() -> void:
	if uploader:
		var upload_settings := load_upload_settings()
		uploader.initialize(upload_settings, event_store, project_id, session_id)
