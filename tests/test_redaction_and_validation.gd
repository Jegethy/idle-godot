## Test Redaction and Validation: Verify PII redaction and data validation
## 
## Tests that sensitive data is redacted and numeric values are sanitized.

extends Node

func _ready() -> void:
	print("=== Running Redaction and Validation Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Non-whitelisted strings are redacted
	all_passed = test_string_redaction() and all_passed
	
	# Test 2: Numeric values are clamped
	all_passed = test_numeric_sanitization() and all_passed
	
	# Test 3: NaN and Inf converted to null
	all_passed = test_nan_inf_handling() and all_passed
	
	# Test 4: PII detection
	all_passed = test_pii_detection() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All redaction and validation tests passed!")
	else:
		print("✗ Some redaction and validation tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_string_redaction() -> bool:
	print("Test: Non-whitelisted strings are redacted")
	
	# Create data with non-whitelisted string field
	var data := {
		"id": "allowed_string",  # Whitelisted
		"username": "john_doe",   # NOT whitelisted - should be redacted
		"email": "test@example.com"  # NOT whitelisted - should be redacted
	}
	
	var sanitized := Anonymizer.sanitize_event_data(data)
	
	# "id" should be preserved
	if sanitized.get("id", "") != "allowed_string":
		print("  ✗ Whitelisted field 'id' should be preserved")
		return false
	
	# "username" should be redacted
	if sanitized.get("username", "") != "[REDACTED]":
		print("  ✗ Non-whitelisted field 'username' should be redacted, got: %s" % sanitized.get("username", ""))
		return false
	
	# "email" should be redacted (also triggers PII detection)
	if sanitized.get("email", "") != "[REDACTED]":
		print("  ✗ Non-whitelisted field 'email' should be redacted")
		return false
	
	print("  ✓ String redaction working correctly")
	return true

func test_numeric_sanitization() -> bool:
	print("Test: Numeric values are clamped")
	
	# Test very large number
	var large_num := 1e20  # Exceeds MAX_NUMERIC_VALUE
	var sanitized := Anonymizer.sanitize_numeric(large_num)
	
	if sanitized != AnalyticsConstants.MAX_NUMERIC_VALUE:
		print("  ✗ Large number should be clamped to MAX_NUMERIC_VALUE")
		return false
	
	# Test very small (negative) number
	var small_num := -1e20  # Below MIN_NUMERIC_VALUE
	sanitized = Anonymizer.sanitize_numeric(small_num)
	
	if sanitized != AnalyticsConstants.MIN_NUMERIC_VALUE:
		print("  ✗ Small number should be clamped to MIN_NUMERIC_VALUE")
		return false
	
	# Test normal number
	var normal_num := 12345.67
	sanitized = Anonymizer.sanitize_numeric(normal_num)
	
	if sanitized != normal_num:
		print("  ✗ Normal number should not be modified")
		return false
	
	# Test integer conversion for whole numbers
	var whole_num := 100.0
	sanitized = Anonymizer.sanitize_numeric(whole_num)
	
	if not (sanitized is int):
		print("  ✗ Whole number should be converted to int")
		return false
	
	print("  ✓ Numeric sanitization working correctly")
	return true

func test_nan_inf_handling() -> bool:
	print("Test: NaN and Inf converted to null")
	
	# Test NaN
	var nan_value := NAN
	var sanitized := Anonymizer.sanitize_numeric(nan_value)
	
	if sanitized != null:
		print("  ✗ NaN should be converted to null, got: %s" % str(sanitized))
		return false
	
	# Test positive infinity
	var inf_value := INF
	sanitized = Anonymizer.sanitize_numeric(inf_value)
	
	if sanitized != null:
		print("  ✗ INF should be converted to null, got: %s" % str(sanitized))
		return false
	
	# Test negative infinity
	var neg_inf_value := -INF
	sanitized = Anonymizer.sanitize_numeric(neg_inf_value)
	
	if sanitized != null:
		print("  ✗ -INF should be converted to null, got: %s" % str(sanitized))
		return false
	
	# Test in event data context
	var data := {
		"normal": 123.0,
		"nan_field": NAN,
		"inf_field": INF
	}
	
	var sanitized_data := Anonymizer.sanitize_event_data(data)
	
	if sanitized_data.get("normal", null) != 123:
		print("  ✗ Normal value should be preserved")
		return false
	
	if sanitized_data.get("nan_field", "not_null") != null:
		print("  ✗ NaN field should be null")
		return false
	
	if sanitized_data.get("inf_field", "not_null") != null:
		print("  ✗ INF field should be null")
		return false
	
	print("  ✓ NaN and Inf handling working correctly")
	return true

func test_pii_detection() -> bool:
	print("Test: PII detection")
	
	# Test file paths (potential PII)
	var file_path := "/home/user/documents/secret.txt"
	if not Anonymizer.is_potentially_pii(file_path):
		print("  ✗ File path should be detected as PII")
		return false
	
	# Test email-like strings
	var email := "user@example.com"
	if not Anonymizer.is_potentially_pii(email):
		print("  ✗ Email should be detected as PII")
		return false
	
	# Test very long strings
	var long_string: String = "a".repeat(150)
	if not Anonymizer.is_potentially_pii(long_string):
		print("  ✗ Long string should be detected as PII")
		return false
	
	# Test normal game data (not PII)
	var normal_id := "upgrade_gold_boost_001"
	if Anonymizer.is_potentially_pii(normal_id):
		print("  ✗ Normal ID should not be detected as PII")
		return false
	
	# Test that whitelisted fields with PII are still redacted
	var data := {
		"id": "safe_id",  # Whitelisted, not PII
		"path": "/user/data/file.txt"  # Whitelisted but IS PII
	}
	
	# "path" is not in whitelist, so it should be redacted
	var sanitized := Anonymizer.sanitize_event_data(data)
	
	# Actually "path" is not whitelisted, so should be redacted
	if sanitized.get("path", "") != "[REDACTED]":
		print("  ✗ Non-whitelisted PII field should be redacted")
		return false
	
	print("  ✓ PII detection working correctly")
	return true
