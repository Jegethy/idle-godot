extends PanelContainer
## AnalyticsPanel: UI for analytics/telemetry control and visualization
## 
## Displays recent events, session stats, and provides export/import controls.

# UI References
@onready var enabled_checkbox: CheckBox = %EnabledCheckBox
@onready var session_id_label: Label = %SessionIdLabel
@onready var events_label: Label = %EventsLabel
@onready var drops_label: Label = %DropsLabel
@onready var events_per_sec_label: Label = %EventsPerSecLabel
@onready var event_list: ItemList = %EventList
@onready var export_ndjson_button: Button = %ExportNDJSONButton
@onready var export_csv_button: Button = %ExportCSVButton
@onready var import_button: Button = %ImportButton
@onready var delete_all_button: Button = %DeleteAllButton
@onready var copy_session_button: Button = %CopySessionButton

# Update timer
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 1.0  # Update UI every second

func _ready() -> void:
	# Connect UI signals
	if enabled_checkbox:
		enabled_checkbox.toggled.connect(_on_enabled_toggled)
	
	if export_ndjson_button:
		export_ndjson_button.pressed.connect(_on_export_ndjson_pressed)
	
	if export_csv_button:
		export_csv_button.pressed.connect(_on_export_csv_pressed)
	
	if import_button:
		import_button.pressed.connect(_on_import_pressed)
	
	if delete_all_button:
		delete_all_button.pressed.connect(_on_delete_all_pressed)
	
	if copy_session_button:
		copy_session_button.pressed.connect(_on_copy_session_pressed)
	
	# Connect to AnalyticsService signals
	if AnalyticsService:
		AnalyticsService.analytics_enabled_changed.connect(_on_analytics_enabled_changed)
		AnalyticsService.event_emitted.connect(_on_event_emitted)
	
	# Initial update
	_update_ui()

func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_ui()

## Update UI with current analytics state
func _update_ui() -> void:
	if not AnalyticsService:
		return
	
	# Update enabled checkbox
	if enabled_checkbox:
		enabled_checkbox.button_pressed = AnalyticsService.enabled
	
	# Get session stats
	var stats := AnalyticsService.get_session_stats()
	
	# Update session ID
	if session_id_label:
		var session_id := stats.get("session_id", "N/A")
		session_id_label.text = "Session: %s" % (session_id if not session_id.is_empty() else "N/A")
	
	# Update counters
	if events_label:
		events_label.text = "Events: %d" % stats.get("events_recorded", 0)
	
	if drops_label:
		drops_label.text = "Dropped: %d" % stats.get("events_dropped", 0)
	
	if events_per_sec_label:
		var eps := stats.get("events_per_sec", 0.0)
		events_per_sec_label.text = "Events/sec: %.2f" % eps
	
	# Update event list (only when events change to avoid flickering)
	_update_event_list()

## Update event list display
func _update_event_list() -> void:
	if not event_list:
		return
	
	var recent_events := AnalyticsService.get_recent_events(50)  # Last 50 events
	
	# Only update if count changed
	if event_list.item_count != recent_events.size():
		event_list.clear()
		
		for event in recent_events:
			var event_name := event.get("event", "unknown")
			var ts := event.get("ts", 0.0)
			var time_str := Time.get_datetime_string_from_unix_time(int(ts))
			
			# Get event highlights
			var highlight := _get_event_highlight(event)
			
			var display_text := "%s | %s %s" % [time_str.substr(11, 8), event_name, highlight]
			event_list.add_item(display_text)
		
		# Auto-scroll to bottom
		if event_list.item_count > 0:
			event_list.ensure_current_is_visible()

## Get highlight info for event (e.g., gold delta, wave number)
func _get_event_highlight(event: Dictionary) -> String:
	var data = event.get("data", {})
	var event_name := event.get("event", "")
	
	match event_name:
		"economy.resource_changed":
			return "(Δ%.0f)" % data.get("delta", 0.0)
		"combat.finished":
			var victory := data.get("victory", false)
			var wave := data.get("wave", 0)
			return "(W%d %s)" % [wave, "✓" if victory else "✗"]
		"prestige.performed":
			return "(+%d essence)" % data.get("gained", 0)
		"upgrade.purchased":
			return "(L%d)" % data.get("level", 0)
		_:
			return ""

## Enable/disable analytics
func _on_enabled_toggled(is_enabled: bool) -> void:
	if AnalyticsService:
		AnalyticsService.set_enabled(is_enabled)

## Export to NDJSON
func _on_export_ndjson_pressed() -> void:
	TelemetryExporter.ensure_export_dir()
	var output_path := TelemetryExporter.get_default_export_path("ndjson")
	
	if AnalyticsService:
		var success := AnalyticsService.export_ndjson(output_path)
		if success:
			print("Exported analytics to: %s" % output_path)
			_show_notification("Exported to %s" % output_path.get_file())
		else:
			_show_notification("Export failed!")

## Export to CSV
func _on_export_csv_pressed() -> void:
	TelemetryExporter.ensure_export_dir()
	var output_path := TelemetryExporter.get_default_export_path("csv")
	
	if AnalyticsService:
		var success := AnalyticsService.export_csv(output_path)
		if success:
			print("Exported analytics to: %s" % output_path)
			_show_notification("Exported to %s" % output_path.get_file())
		else:
			_show_notification("Export failed!")

## Import from NDJSON
func _on_import_pressed() -> void:
	# For now, just show a message since we don't have file picker UI
	_show_notification("Import: Place NDJSON file in user://imports/")
	
	# Try to import from a default location
	var import_path := "user://imports/analytics_import.ndjson"
	if FileAccess.file_exists(import_path):
		var result := AnalyticsService.import_ndjson(import_path)
		if result.get("success", false):
			_show_notification("Imported %d events" % result.get("imported", 0))
		else:
			_show_notification("Import failed!")

## Delete all analytics data
func _on_delete_all_pressed() -> void:
	if AnalyticsService:
		var success := AnalyticsService.delete_all_data()
		if success:
			_show_notification("All analytics data deleted")
			_update_ui()
		else:
			_show_notification("Delete failed!")

## Copy session ID to clipboard
func _on_copy_session_pressed() -> void:
	if AnalyticsService:
		var session_id := AnalyticsService.session_id
		if not session_id.is_empty():
			DisplayServer.clipboard_set(session_id)
			_show_notification("Session ID copied!")
		else:
			_show_notification("No active session")

## Show a temporary notification (simple implementation)
func _show_notification(message: String) -> void:
	print("Analytics: %s" % message)
	# Could add a toast notification here

## Handle analytics enabled state change
func _on_analytics_enabled_changed(is_enabled: bool) -> void:
	_update_ui()

## Handle new event emitted
func _on_event_emitted(event_name: String) -> void:
	# Event list will be updated on next frame
	pass
