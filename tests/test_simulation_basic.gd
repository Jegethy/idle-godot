## Test Simulation Basic: Test prestige simulation tool
## 
## Validates that PrestigeSimulation produces deterministic results.

extends Node

func _ready() -> void:
	print("=== Running Prestige Simulation Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Simple simulation with fixed rate
	all_passed = test_simple_simulation() and all_passed
	
	# Test 2: Simulation with zero rate
	all_passed = test_zero_rate_simulation() and all_passed
	
	# Test 3: Deterministic output
	all_passed = test_deterministic_output() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All simulation tests passed!")
	else:
		print("✗ Some simulation tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_simple_simulation() -> bool:
	print("Test: Simple simulation with fixed rate")
	
	# Simulate 300 seconds with 10 gold/sec starting from 1000 gold
	var result := PrestigeSimulation.simulate(300, 1000.0, 10.0)
	
	var final_gold: float = result.get("final_gold", -1.0)
	var lifetime_increment: float = result.get("lifetime_gold_increment", -1.0)
	
	# Expected: 1000 + (10 * 300) = 1000 + 3000 = 4000
	var expected_final: float = 4000.0
	var expected_increment: float = 3000.0
	
	if not is_equal_approx(final_gold, expected_final):
		print("  ✗ Final gold mismatch (expected %.0f, got %.0f)" % [expected_final, final_gold])
		return false
	
	if not is_equal_approx(lifetime_increment, expected_increment):
		print("  ✗ Lifetime increment mismatch (expected %.0f, got %.0f)" % [expected_increment, lifetime_increment])
		return false
	
	print("  ✓ Simulation correct: 1000 + (10/sec × 300sec) = %.0f" % final_gold)
	return true

func test_zero_rate_simulation() -> bool:
	print("\nTest: Simulation with zero rate")
	
	# Simulate 100 seconds with 0 gold/sec starting from 500 gold
	var result := PrestigeSimulation.simulate(100, 500.0, 0.0)
	
	var final_gold: float = result.get("final_gold", -1.0)
	var lifetime_increment: float = result.get("lifetime_gold_increment", -1.0)
	
	# Expected: no change
	if not is_equal_approx(final_gold, 500.0):
		print("  ✗ Final gold changed with zero rate (got %.0f)" % final_gold)
		return false
	
	if not is_equal_approx(lifetime_increment, 0.0):
		print("  ✗ Lifetime increment non-zero with zero rate (got %.0f)" % lifetime_increment)
		return false
	
	print("  ✓ Zero rate produces no change")
	return true

func test_deterministic_output() -> bool:
	print("\nTest: Deterministic output for same inputs")
	
	# Run simulation twice with same parameters
	var result1 := PrestigeSimulation.simulate(120, 2000.0, 25.0)
	var result2 := PrestigeSimulation.simulate(120, 2000.0, 25.0)
	
	var final1: float = result1.get("final_gold", -1.0)
	var final2: float = result2.get("final_gold", -1.0)
	
	var essence1: int = result1.get("preview_essence_gain", -1)
	var essence2: int = result2.get("preview_essence_gain", -1)
	
	if not is_equal_approx(final1, final2):
		print("  ✗ Non-deterministic final gold (%.0f vs %.0f)" % [final1, final2])
		return false
	
	if essence1 != essence2:
		print("  ✗ Non-deterministic essence gain (%d vs %d)" % [essence1, essence2])
		return false
	
	print("  ✓ Simulation is deterministic")
	return true
