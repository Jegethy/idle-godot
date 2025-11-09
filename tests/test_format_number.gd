## Test Format Number: Tests number formatting utility
## 
## Validates short scale formatting (K, M, B, T) and edge cases.

extends Node

func _ready() -> void:
	print("=== Running Number Formatting Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Numbers below 1000
	all_passed = test_below_thousand() and all_passed
	
	# Test 2: Thousands (K)
	all_passed = test_thousands() and all_passed
	
	# Test 3: Millions (M)
	all_passed = test_millions() and all_passed
	
	# Test 4: Billions (B)
	all_passed = test_billions() and all_passed
	
	# Test 5: Trillions (T)
	all_passed = test_trillions() and all_passed
	
	# Test 6: Negative numbers
	all_passed = test_negative_numbers() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All number formatting tests passed!")
	else:
		print("✗ Some number formatting tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_below_thousand() -> bool:
	print("Test: Numbers below 1000")
	
	var tests := [
		{"value": 0.0, "expected": "0"},
		{"value": 5.0, "expected": "5"},
		{"value": 42.0, "expected": "42"},
		{"value": 999.0, "expected": "999"},
		{"value": 123.45, "expected": "123.45"}
	]
	
	for test in tests:
		var result := NumberFormatter.format_short(test["value"])
		if result != test["expected"]:
			print("  ✗ Failed for %.2f: expected '%s', got '%s'" % [test["value"], test["expected"], result])
			return false
	
	print("  ✓ Numbers below 1000 formatted correctly")
	return true

func test_thousands() -> bool:
	print("\nTest: Thousands (K)")
	
	var tests := [
		{"value": 1_000.0, "expected": "1.00K"},
		{"value": 1_250.0, "expected": "1.25K"},
		{"value": 12_500.0, "expected": "12.50K"},
		{"value": 999_999.0, "expected": "1000.00K"}
	]
	
	for test in tests:
		var result := NumberFormatter.format_short(test["value"])
		if result != test["expected"]:
			print("  ✗ Failed for %.0f: expected '%s', got '%s'" % [test["value"], test["expected"], result])
			return false
	
	print("  ✓ Thousands formatted correctly")
	return true

func test_millions() -> bool:
	print("\nTest: Millions (M)")
	
	var tests := [
		{"value": 1_000_000.0, "expected": "1.00M"},
		{"value": 5_670_000.0, "expected": "5.67M"},
		{"value": 12_500_000.0, "expected": "12.50M"},
		{"value": 999_999_999.0, "expected": "1000.00M"}
	]
	
	for test in tests:
		var result := NumberFormatter.format_short(test["value"])
		if result != test["expected"]:
			print("  ✗ Failed for %.0f: expected '%s', got '%s'" % [test["value"], test["expected"], result])
			return false
	
	print("  ✓ Millions formatted correctly")
	return true

func test_billions() -> bool:
	print("\nTest: Billions (B)")
	
	var tests := [
		{"value": 1_000_000_000.0, "expected": "1.00B"},
		{"value": 3_450_000_000.0, "expected": "3.45B"},
		{"value": 25_000_000_000.0, "expected": "25.00B"}
	]
	
	for test in tests:
		var result := NumberFormatter.format_short(test["value"])
		if result != test["expected"]:
			print("  ✗ Failed for %.0f: expected '%s', got '%s'" % [test["value"], test["expected"], result])
			return false
	
	print("  ✓ Billions formatted correctly")
	return true

func test_trillions() -> bool:
	print("\nTest: Trillions (T)")
	
	var tests := [
		{"value": 1_000_000_000_000.0, "expected": "1.00T"},
		{"value": 1_230_000_000_000.0, "expected": "1.23T"},
		{"value": 5_670_000_000_000.0, "expected": "5.67T"}
	]
	
	for test in tests:
		var result := NumberFormatter.format_short(test["value"])
		if result != test["expected"]:
			print("  ✗ Failed for %.0f: expected '%s', got '%s'" % [test["value"], test["expected"], result])
			return false
	
	print("  ✓ Trillions formatted correctly")
	return true

func test_negative_numbers() -> bool:
	print("\nTest: Negative numbers")
	
	var tests := [
		{"value": -5.0, "expected": "-5"},
		{"value": -1_250.0, "expected": "-1.25K"},
		{"value": -5_670_000.0, "expected": "-5.67M"}
	]
	
	for test in tests:
		var result := NumberFormatter.format_short(test["value"])
		if result != test["expected"]:
			print("  ✗ Failed for %.2f: expected '%s', got '%s'" % [test["value"], test["expected"], result])
			return false
	
	print("  ✓ Negative numbers formatted correctly")
	return true
