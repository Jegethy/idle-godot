## Test Meta Cost Curves: Verify cost calculation formulas
## 
## Tests exponential, linear, and polynomial cost curves.

extends Node

func _ready() -> void:
	print("=== Running Meta Cost Curves Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Exponential cost curve
	all_passed = test_exponential_cost_curve() and all_passed
	
	# Test 2: Linear cost curve
	all_passed = test_linear_cost_curve() and all_passed
	
	# Test 3: Polynomial cost curve
	all_passed = test_polynomial_cost_curve() and all_passed
	
	# Test 4: Cost at max level returns INF
	all_passed = test_cost_at_max_level() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All meta cost curves tests passed!")
	else:
		print("✗ Some meta cost curves tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_exponential_cost_curve() -> bool:
	print("Test: Exponential cost curve calculation")
	
	# Create upgrade with exponential curve: base=10, growth=1.18
	var upgrade := MetaUpgrade.new()
	upgrade.base_cost = 10.0
	upgrade.cost_curve = "EXPONENTIAL"
	upgrade.growth = 1.18
	upgrade.max_level = 50
	
	# Test cost at level 0 (first purchase)
	# cost(0) = 10 * 1.18^0 = 10 * 1 = 10
	var cost_0 := upgrade.cost(0)
	if not is_equal_approx(cost_0, 10.0):
		print("  ✗ Expected cost(0) = 10.0, got %.2f" % cost_0)
		return false
	
	# Test cost at level 1
	# cost(1) = 10 * 1.18^1 = 11.8
	var cost_1 := upgrade.cost(1)
	if not is_equal_approx(cost_1, 11.8):
		print("  ✗ Expected cost(1) = 11.8, got %.2f" % cost_1)
		return false
	
	# Test cost at level 10
	# cost(10) = 10 * 1.18^10 ≈ 52.34
	var cost_10 := upgrade.cost(10)
	var expected_10 := 10.0 * pow(1.18, 10)
	if not is_equal_approx(cost_10, expected_10):
		print("  ✗ Expected cost(10) ≈ %.2f, got %.2f" % [expected_10, cost_10])
		return false
	
	print("  ✓ Exponential cost curve correct")
	return true

func test_linear_cost_curve() -> bool:
	print("\nTest: Linear cost curve calculation")
	
	# Create upgrade with linear curve: base=35
	# Linear: base_cost * (1 + 0.25 * level)
	var upgrade := MetaUpgrade.new()
	upgrade.base_cost = 35.0
	upgrade.cost_curve = "LINEAR"
	upgrade.max_level = 25
	
	# Test cost at level 0
	# cost(0) = 35 * (1 + 0.25 * 0) = 35
	var cost_0 := upgrade.cost(0)
	if not is_equal_approx(cost_0, 35.0):
		print("  ✗ Expected cost(0) = 35.0, got %.2f" % cost_0)
		return false
	
	# Test cost at level 4
	# cost(4) = 35 * (1 + 0.25 * 4) = 35 * 2 = 70
	var cost_4 := upgrade.cost(4)
	if not is_equal_approx(cost_4, 70.0):
		print("  ✗ Expected cost(4) = 70.0, got %.2f" % cost_4)
		return false
	
	# Test cost at level 20
	# cost(20) = 35 * (1 + 0.25 * 20) = 35 * 6 = 210
	var cost_20 := upgrade.cost(20)
	if not is_equal_approx(cost_20, 210.0):
		print("  ✗ Expected cost(20) = 210.0, got %.2f" % cost_20)
		return false
	
	print("  ✓ Linear cost curve correct")
	return true

func test_polynomial_cost_curve() -> bool:
	print("\nTest: Polynomial cost curve calculation")
	
	# Create upgrade with polynomial curve: [40, 6.0]
	# Poly: coeffs[0] + coeffs[1] * level = 40 + 6 * level
	var upgrade := MetaUpgrade.new()
	upgrade.base_cost = 40.0
	upgrade.cost_curve = "POLY"
	upgrade.poly_coeffs = [40.0, 6.0]
	upgrade.max_level = 20
	
	# Test cost at level 0
	# cost(0) = 40 + 6 * 0 = 40
	var cost_0 := upgrade.cost(0)
	if not is_equal_approx(cost_0, 40.0):
		print("  ✗ Expected cost(0) = 40.0, got %.2f" % cost_0)
		return false
	
	# Test cost at level 5
	# cost(5) = 40 + 6 * 5 = 70
	var cost_5 := upgrade.cost(5)
	if not is_equal_approx(cost_5, 70.0):
		print("  ✗ Expected cost(5) = 70.0, got %.2f" % cost_5)
		return false
	
	# Test cost at level 10
	# cost(10) = 40 + 6 * 10 = 100
	var cost_10 := upgrade.cost(10)
	if not is_equal_approx(cost_10, 100.0):
		print("  ✗ Expected cost(10) = 100.0, got %.2f" % cost_10)
		return false
	
	print("  ✓ Polynomial cost curve correct")
	return true

func test_cost_at_max_level() -> bool:
	print("\nTest: Cost at max level returns INF")
	
	var upgrade := MetaUpgrade.new()
	upgrade.base_cost = 10.0
	upgrade.cost_curve = "EXPONENTIAL"
	upgrade.growth = 1.18
	upgrade.max_level = 50
	
	# Test cost at max level
	var cost_max := upgrade.cost(50)
	if cost_max != INF:
		print("  ✗ Expected cost(50) = INF, got %.2f" % cost_max)
		return false
	
	# Test cost beyond max level
	var cost_beyond := upgrade.cost(51)
	if cost_beyond != INF:
		print("  ✗ Expected cost(51) = INF, got %.2f" % cost_beyond)
		return false
	
	print("  ✓ Cost at max level returns INF")
	return true
