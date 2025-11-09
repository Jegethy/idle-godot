extends RefCounted
## TelemetryExporter: Utility wrapper for analytics export/import operations
## 
## Provides high-level API for exporting and importing telemetry data.

class_name TelemetryExporter

## Export analytics data to NDJSON format
static func export_to_ndjson(analytics: Node, output_path: String, options: Dictionary = {}) -> bool:
	if not analytics or not analytics.has_method("export_ndjson"):
		push_error("AnalyticsService not available")
		return false
	
	var filter_prefix: String = String(options.get("filter_prefix", ""))
	var max_rows: int = int(options.get("max_rows", -1))
	
	return analytics.export_ndjson(output_path, filter_prefix, max_rows)

## Export analytics data to CSV format
static func export_to_csv(analytics: Node, output_path: String, options: Dictionary = {}) -> bool:
	if not analytics or not analytics.has_method("export_csv"):
		push_error("AnalyticsService not available")
		return false
	
	var filter_prefix: String = String(options.get("filter_prefix", ""))
	var max_rows: int = int(options.get("max_rows", -1))
	
	return analytics.export_csv(output_path, filter_prefix, max_rows)

## Import analytics data from NDJSON format
static func import_from_ndjson(analytics: Node, input_path: String) -> Dictionary:
	if not analytics or not analytics.has_method("import_ndjson"):
		push_error("AnalyticsService not available")
		return {"success": false, "imported": 0, "skipped": 0}
	
	return analytics.import_ndjson(input_path)

## Delete all analytics data
static func delete_all(analytics: Node) -> bool:
	if not analytics or not analytics.has_method("delete_all_data"):
		push_error("AnalyticsService not available")
		return false
	
	return analytics.delete_all_data()

## Get default export path for user directory
static func get_default_export_path(format: String = "ndjson") -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var filename := "analytics_export_%s.%s" % [timestamp, format]
	return "user://exports/" + filename

## Ensure export directory exists
static func ensure_export_dir() -> bool:
	var export_dir := "user://exports/"
	if not DirAccess.dir_exists_absolute(export_dir):
		var err := DirAccess.make_dir_recursive_absolute(export_dir)
		if err != OK:
			push_error("Failed to create export directory: %d" % err)
			return false
	return true
