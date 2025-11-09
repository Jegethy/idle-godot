extends RefCounted
## Anonymizer: Data redaction and validation helpers
## 
## Ensures no PII is captured and numeric values are sanitized.

class_name Anonymizer

## Redact/sanitize event data dictionary
## Removes non-whitelisted strings and clamps numeric values
static func sanitize_event_data(data: Dictionary) -> Dictionary:
	var sanitized := {}
	
	for key in data:
		var value = data[key]
		sanitized[key] = sanitize_value(value, key)
	
	return sanitized

## Sanitize a single value based on its type
static func sanitize_value(value: Variant, field_name: String = "") -> Variant:
	if value == null:
		return null
	
	# Handle different types
	if value is String:
		return sanitize_string(value, field_name)
	elif value is float or value is int:
		return sanitize_numeric(value)
	elif value is bool:
		return value
	elif value is Array:
		return sanitize_array(value, field_name)
	elif value is Dictionary:
		return sanitize_event_data(value)
	else:
		# Unknown type - convert to string and sanitize
		return sanitize_string(str(value), field_name)

## Sanitize string values - only allow whitelisted fields
static func sanitize_string(value: String, field_name: String) -> Variant:
	# Check if this field is whitelisted for string data
	if is_whitelisted_string_field(field_name):
		# Still validate: no file paths, no special chars indicating PII
		if is_potentially_pii(value):
			return "[REDACTED]"
		return value
	else:
		# Non-whitelisted string field - redact
		return "[REDACTED]"

## Check if a field name is whitelisted for string data
static func is_whitelisted_string_field(field_name: String) -> bool:
	return field_name in AnalyticsConstants.WHITELISTED_STRING_FIELDS

## Check if a string value might contain PII
static func is_potentially_pii(value: String) -> bool:
	# Detect file paths
	if "/" in value or "\\" in value:
		return true
	
	# Detect email-like patterns
	if "@" in value and "." in value:
		return true
	
	# Detect very long strings (likely not game data)
	if value.length() > 100:
		return true
	
	return false

## Sanitize numeric values - clamp to reasonable range, handle NaN/Inf
static func sanitize_numeric(value: Variant) -> Variant:
	var num: float = float(value)
	
	# Convert NaN and Inf to null
	if is_nan(num) or is_inf(num):
		return null
	
	# Clamp to reasonable range
	num = clampf(num, AnalyticsConstants.MIN_NUMERIC_VALUE, AnalyticsConstants.MAX_NUMERIC_VALUE)
	
	# Return as int if it's a whole number, otherwise float
	if is_equal_approx(num, floor(num)):
		return int(num)
	
	return num

## Sanitize array values recursively
static func sanitize_array(arr: Array, field_name: String) -> Array:
	var sanitized := []
	for item in arr:
		sanitized.append(sanitize_value(item, field_name))
	return sanitized

## Generate a random session ID (UUID v4 style)
static func generate_session_id() -> String:
	var random := RandomNumberGenerator.new()
	random.randomize()
	
	# Generate UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
	var uuid := ""
	for i in range(32):
		if i == 8 or i == 12 or i == 16 or i == 20:
			uuid += "-"
		
		var hex: int
		if i == 12:
			# Version 4
			hex = 4
		elif i == 16:
			# Variant bits (10xx)
			hex = random.randi_range(8, 11)
		else:
			hex = random.randi_range(0, 15)
		
		uuid += "%x" % hex
	
	return uuid

## Validate event structure
## Returns true if event has required fields and valid structure
static func validate_event(event: Dictionary) -> bool:
	# Required fields
	if not event.has("ts"):
		return false
	if not event.has("session_id"):
		return false
	if not event.has("event"):
		return false
	if not event.has("data"):
		return false
	
	# Type validation
	if not event["data"] is Dictionary:
		return false
	
	# Timestamp should be numeric
	if not (event["ts"] is float or event["ts"] is int):
		return false
	
	# Event name should be string
	if not event["event"] is String:
		return false
	
	# Session ID should be string
	if not event["session_id"] is String:
		return false
	
	return true
