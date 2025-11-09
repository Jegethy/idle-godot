## Test Essence Multiplier: Validate essence multiplier calculations
## 
## Tests that essence correctly increases idle rate multiplier.

extends Node

func _ready() -> void:
	print("=== Running Essence Multiplier Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Zero essence gives 1.0x multiplier
	all_passed = test_zero_essence_multiplier() and all_passed
	
	# Test 2: 25 essence gives expected multiplier
	all_passed = test_25_essence_multiplier() and all_passed
	
	# Test 3: 100 essence gives expected multiplier
	all_passed = test_100_essence_multiplier() and all_passed
	
	# Test 4: Multiplier display format
	all_passed = test_multiplier_display_format() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All essence multiplier tests passed!")
	else:
		print("✗ Some essence multiplier tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_zero_essence_multiplier() -> bool:
	print("Test: Zero essence gives 1.0x multiplier")
	
	# Setup: Zero essence
	GameState.essence = 0.0
	
	var multiplier: float = PrestigeService.get_essence_multiplier()
	
	if not is_equal_approx(multiplier, 1.0):
		print("  ✗ Expected 1.0x, got %.3fx" % multiplier)
		return false
	
	print("  ✓ 0 essence → 1.0x multiplier")
	return true

func test_25_essence_multiplier() -> bool:
	print("\nTest: 25 essence gives expected multiplier")
	
	# Setup: 25 essence
	GameState.essence = 25.0
	
	# Expected: 1 + 0.02 * sqrt(25) = 1 + 0.02 * 5 = 1 + 0.1 = 1.1
	var expected: float = 1.0 + BalanceConstants.ESSENCE_BASE_MULTIPLIER * sqrt(25.0)
	var multiplier: float = PrestigeService.get_essence_multiplier()
	
	var tolerance: float = 0.001
	if absf(multiplier - expected) > tolerance:
		print("  ✗ Expected %.3fx, got %.3fx" % [expected, multiplier])
		return false
	
	print("  ✓ 25 essence → %.3fx multiplier" % multiplier)
	return true

func test_100_essence_multiplier() -> bool:
	print("\nTest: 100 essence gives expected multiplier")
	
	# Setup: 100 essence
	GameState.essence = 100.0
	
	# Expected: 1 + 0.02 * sqrt(100) = 1 + 0.02 * 10 = 1 + 0.2 = 1.2
	var expected: float = 1.0 + BalanceConstants.ESSENCE_BASE_MULTIPLIER * sqrt(100.0)
	var multiplier: float = PrestigeService.get_essence_multiplier()
	
	var tolerance: float = 0.001
	if absf(multiplier - expected) > tolerance:
		print("  ✗ Expected %.3fx, got %.3fx" % [expected, multiplier])
		return false
	
	print("  ✓ 100 essence → %.3fx multiplier" % multiplier)
	return true

func test_multiplier_display_format() -> bool:
	print("\nTest: Multiplier display format")
	
	# Test various essence values
	var test_cases := [
		{"essence": 0.0, "expected_pattern": "+0.0%"},
		{"essence": 25.0, "expected_pattern": "+10.0%"},
		{"essence": 100.0, "expected_pattern": "+20.0%"}
	]
	
	for test_case in test_cases:
		GameState.essence = test_case["essence"]
		var display: String = PrestigeService.get_essence_multiplier_display()
		var expected: String = test_case["expected_pattern"]
		
		if display != expected:
			print("  ✗ For %.0f essence, expected '%s', got '%s'" % [test_case["essence"], expected, display])
			return false
	
	print("  ✓ Multiplier display format correct")
	return true
