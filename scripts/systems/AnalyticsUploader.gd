extends Node
## AnalyticsUploader: Timer-based cloud upload for analytics events
## 
## Batches events from EventStore and uploads them to a configured endpoint
## with exponential backoff on failures. Tracks cursor position for idempotency.

class_name AnalyticsUploader

# Upload configuration (loaded from settings)
var enabled: bool = false
var endpoint_url: String = ""
var api_key: String = ""
var api_secret: String = ""
var upload_interval_sec: int = UploadConstants.DEFAULT_UPLOAD_INTERVAL_SEC
var max_batch_events: int = UploadConstants.DEFAULT_MAX_BATCH_EVENTS
var max_batch_bytes: int = UploadConstants.DEFAULT_MAX_BATCH_BYTES
var disk_cap_bytes: int = UploadConstants.DEFAULT_DISK_CAP_BYTES

# Backoff configuration
var backoff_base_sec: float = UploadConstants.BACKOFF_BASE_SEC
var backoff_factor: float = UploadConstants.BACKOFF_FACTOR
var backoff_max_sec: float = UploadConstants.BACKOFF_MAX_SEC
var backoff_jitter_ratio: float = UploadConstants.BACKOFF_JITTER_RATIO

# State
var upload_timer: Timer = null
var http_transport: HttpTransport = null
var event_store: EventStore = null
var cursor: Dictionary = {}
var consecutive_failures: int = 0
var backoff_remaining_sec: float = 0.0
var is_paused: bool = false
var last_upload_time: float = 0.0
var last_upload_status: String = "Never"
var queued_events_estimate: int = 0

# Project and session tracking
var project_id: String = ""
var session_id: String = ""

# Signals
signal upload_success(events_sent: int)
signal upload_failure(error_message: String)
signal backoff_changed(remaining_sec: float)

func _ready() -> void:
	# Create upload timer
	upload_timer = Timer.new()
	upload_timer.wait_time = upload_interval_sec
	upload_timer.timeout.connect(_on_upload_timer_timeout)
	upload_timer.autostart = false
	add_child(upload_timer)
	
	print("AnalyticsUploader initialized")

## Initialize with settings and event store
func initialize(settings: Dictionary, store: EventStore, proj_id: String, sess_id: String) -> void:
	# Load settings
	enabled = settings.get("cloud_upload_enabled", false)
	endpoint_url = settings.get("endpoint_url", "")
	api_key = settings.get("api_key", "")
	api_secret = settings.get("api_secret", "")
	
	# Try OS environment for secret if not in settings
	if api_secret.is_empty():
		api_secret = OS.get_environment("ANALYTICS_API_SECRET")
	
	upload_interval_sec = settings.get("upload_interval_sec", UploadConstants.DEFAULT_UPLOAD_INTERVAL_SEC)
	max_batch_events = settings.get("max_batch_events", UploadConstants.DEFAULT_MAX_BATCH_EVENTS)
	max_batch_bytes = settings.get("max_batch_bytes", UploadConstants.DEFAULT_MAX_BATCH_BYTES)
	disk_cap_bytes = settings.get("disk_cap_bytes", UploadConstants.DEFAULT_DISK_CAP_BYTES)
	
	backoff_base_sec = settings.get("backoff_base_sec", UploadConstants.BACKOFF_BASE_SEC)
	backoff_factor = settings.get("backoff_factor", UploadConstants.BACKOFF_FACTOR)
	backoff_max_sec = settings.get("backoff_max_sec", UploadConstants.BACKOFF_MAX_SEC)
	backoff_jitter_ratio = settings.get("backoff_jitter_ratio", UploadConstants.BACKOFF_JITTER_RATIO)
	
	# Set project and session IDs
	project_id = proj_id
	session_id = sess_id
	
	# Store reference to event store
	event_store = store
	
	# Load cursor from file
	if event_store:
		cursor = event_store.load_cursor()
	
	# Create HTTP transport
	http_transport = HttpTransport.new(endpoint_url, api_key, api_secret)
	
	# Start timer if enabled
	if enabled and not endpoint_url.is_empty():
		start()

## Start the upload timer
func start() -> void:
	if upload_timer and not is_paused:
		upload_timer.wait_time = upload_interval_sec
		upload_timer.start()
		print("AnalyticsUploader: Started (interval: %d sec)" % upload_interval_sec)

## Stop the upload timer
func stop() -> void:
	if upload_timer:
		upload_timer.stop()
		print("AnalyticsUploader: Stopped")

## Pause uploads
func pause() -> void:
	is_paused = true
	stop()
	print("AnalyticsUploader: Paused")

## Resume uploads
func resume() -> void:
	is_paused = false
	if enabled and not endpoint_url.is_empty():
		start()
		print("AnalyticsUploader: Resumed")

## Trigger immediate upload (ignores interval, respects enabled flag)
func upload_now() -> void:
	if not enabled:
		push_warning("AnalyticsUploader: Upload disabled")
		return
	
	if endpoint_url.is_empty():
		push_warning("AnalyticsUploader: No endpoint URL configured")
		return
	
	_perform_upload()

## Upload timer callback
func _on_upload_timer_timeout() -> void:
	# Check if still enabled and not paused
	if not enabled or is_paused or endpoint_url.is_empty():
		return
	
	# Check backoff
	if backoff_remaining_sec > 0.0:
		var delta := upload_interval_sec
		backoff_remaining_sec = maxf(0.0, backoff_remaining_sec - delta)
		backoff_changed.emit(backoff_remaining_sec)
		return
	
	# Perform upload
	_perform_upload()

## Perform the actual upload
func _perform_upload() -> void:
	if not event_store:
		return
	
	# Enforce disk cap before upload
	event_store.enforce_disk_cap(disk_cap_bytes)
	
	# Read next batch from cursor
	var batch_result := event_store.read_batch(cursor, max_batch_events, max_batch_bytes)
	var events: Array = batch_result["events"]
	var next_cursor: Dictionary = batch_result["next_cursor"]
	var has_more: bool = batch_result["has_more"]
	
	# Update queued events estimate
	queued_events_estimate = events.size()
	
	# Skip if no events
	if events.is_empty():
		print("AnalyticsUploader: No events to upload")
		last_upload_status = "No events"
		return
	
	# Build envelope
	var envelope := _build_envelope(events)
	
	# Send via HTTP transport
	var success := http_transport.send_batch(envelope)
	
	last_upload_time = Time.get_unix_time_from_system()
	
	if success:
		# Success: advance cursor and reset backoff
		cursor = next_cursor
		event_store.save_cursor(cursor)
		consecutive_failures = 0
		backoff_remaining_sec = 0.0
		last_upload_status = "OK"
		
		# If no more events in current file, mark it as done
		if not has_more and cursor.has("file_path"):
			event_store.mark_file_done(cursor["file_path"])
		
		upload_success.emit(events.size())
		print("AnalyticsUploader: Successfully uploaded %d events" % events.size())
	else:
		# Failure: apply backoff
		consecutive_failures += 1
		backoff_remaining_sec = _calculate_backoff()
		last_upload_status = "Failed"
		
		upload_failure.emit("HTTP request failed")
		backoff_changed.emit(backoff_remaining_sec)
		push_warning("AnalyticsUploader: Upload failed (attempt %d), backing off for %.1f sec" % [consecutive_failures, backoff_remaining_sec])

## Build envelope for batch upload
func _build_envelope(events: Array) -> Dictionary:
	var envelope := {
		"project_id": project_id,
		"session_id": session_id,
		"sent_at": Time.get_unix_time_from_system(),
		"ver": UploadConstants.ENVELOPE_VERSION,
		"events": events
	}
	
	return envelope

## Calculate exponential backoff with jitter
func _calculate_backoff() -> float:
	var base_delay := backoff_base_sec * pow(backoff_factor, consecutive_failures - 1)
	var capped_delay := minf(base_delay, backoff_max_sec)
	
	# Add jitter (±jitter_ratio)
	var jitter := randf_range(-backoff_jitter_ratio, backoff_jitter_ratio)
	var final_delay := capped_delay * (1.0 + jitter)
	
	return maxf(0.0, final_delay)

## Get status for UI display
func get_status() -> Dictionary:
	var status_text := "Disabled"
	if enabled:
		if is_paused:
			status_text = "Paused"
		elif backoff_remaining_sec > 0:
			status_text = "Backing off (%.0fs)" % backoff_remaining_sec
		else:
			status_text = "Enabled"
	
	var last_time_str := "Never"
	if last_upload_time > 0:
		var time_dict := Time.get_datetime_dict_from_unix_time(int(last_upload_time))
		last_time_str = "%02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]
	
	return {
		"enabled": enabled,
		"paused": is_paused,
		"status": status_text,
		"last_upload": last_upload_status,
		"last_time": last_time_str,
		"queued_events": queued_events_estimate,
		"backoff_sec": backoff_remaining_sec
	}

## Clear backlog (delete cursor, optionally mark current file as orphan)
func clear_backlog(mark_orphan: bool = true) -> void:
	if event_store:
		# Delete cursor
		var cursor_path := event_store.telemetry_dir + "upload.cursor"
		if FileAccess.file_exists(cursor_path):
			DirAccess.remove_absolute(cursor_path)
		
		# Optionally mark current file as orphan
		if mark_orphan and cursor.has("file_path"):
			var file_path: String = cursor["file_path"]
			if FileAccess.file_exists(file_path):
				var orphan_path := file_path + UploadConstants.ORPHAN_FILE_SUFFIX
				var dir := DirAccess.open(event_store.telemetry_dir)
				if dir:
					dir.rename(file_path.get_file(), orphan_path.get_file())
		
		# Reset cursor
		cursor = {}
		consecutive_failures = 0
		backoff_remaining_sec = 0.0
		
		print("AnalyticsUploader: Backlog cleared")

## Test connection with empty batch (ping)
func test_connection() -> bool:
	if endpoint_url.is_empty():
		push_warning("AnalyticsUploader: No endpoint URL configured")
		return false
	
	# Build empty envelope
	var envelope := _build_envelope([])
	
	# Send via HTTP transport
	var success := http_transport.send_batch(envelope)
	
	if success:
		print("AnalyticsUploader: Connection test successful")
	else:
		push_warning("AnalyticsUploader: Connection test failed")
	
	return success
