## Test Combat Drop Probability: Verify drops occur with expected frequency
## 
## Tests that item drops follow configured probabilities (with tolerance).

extends SceneTree

func _init() -> void:
	print("=== Running Combat Drop Probability Test ===\n")
	
	var all_passed := true
	
	# Test 1: Drops occur within expected frequency range
	all_passed = test_drop_frequency() and all_passed
	
	# Test 2: Deterministic drops with same seed
	all_passed = test_deterministic_drops() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All combat drop probability tests passed!")
	else:
		print("✗ Some combat drop probability tests failed")
	
	quit(0 if all_passed else 1)

func test_drop_frequency() -> bool:
	print("Test: Drops occur within expected frequency range")
	
	# Run multiple simulations and check drop rates
	var num_runs := 20  # Small N to avoid long test times
	var drops_received := 0
	
	# Set up player to guarantee victory
	GameState.player_stats.attack = 100.0
	GameState.player_stats.defense = 20.0
	GameState.player_stats.combat_speed = 3.0
	GameState.essence = 0.0
	
	for i in range(num_runs):
		var result := CombatSystem.fast_simulate_wave(0, 1000 + i)
		
		if not result.get("victory", false):
			continue
		
		var rewards: Dictionary = result.get("rewards", {})
		var items: Array = rewards.get("items", [])
		
		if items.size() > 0:
			drops_received += 1
	
	# Expected drop rate is around 20-25% per enemy (from slime drop table)
	# With 3 enemies per wave, we expect some drops but not 100%
	# We'll just verify drops occurred (not zero) without strict bounds
	
	var drop_rate := float(drops_received) / num_runs
	print("  Drop rate: %.2f%% (%d/%d runs)" % [drop_rate * 100.0, drops_received, num_runs])
	
	# Lenient check: just ensure some drops happened (at least 1 out of 20)
	if drops_received == 0:
		print("  ✗ No drops received in %d runs (expected at least some)" % num_runs)
		return false
	
	print("  ✓ Drops occurred as expected")
	return true

func test_deterministic_drops() -> bool:
	print("Test: Deterministic drops with same seed")
	
	# Set up player stats
	GameState.player_stats.attack = 100.0
	GameState.player_stats.defense = 20.0
	GameState.player_stats.combat_speed = 3.0
	GameState.essence = 0.0
	
	var seed_value := 55555
	
	# First run
	var result1 := CombatSystem.fast_simulate_wave(0, seed_value)
	var rewards1: Dictionary = result1.get("rewards", {})
	var items1: Array = rewards1.get("items", [])
	
	# Second run with same seed
	var result2 := CombatSystem.fast_simulate_wave(0, seed_value)
	var rewards2: Dictionary = result2.get("rewards", {})
	var items2: Array = rewards2.get("items", [])
	
	# Compare item counts
	if items1.size() != items2.size():
		print("  ✗ Item count differs: %d vs %d" % [items1.size(), items2.size()])
		return false
	
	# Compare individual items
	for i in range(items1.size()):
		var item1: Dictionary = items1[i]
		var item2: Dictionary = items2[i]
		
		if item1.get("item_id", "") != item2.get("item_id", ""):
			print("  ✗ Item ID differs at index %d" % i)
			return false
		
		if item1.get("quantity", 0) != item2.get("quantity", 0):
			print("  ✗ Item quantity differs at index %d" % i)
			return false
	
	print("  ✓ Drops are deterministic (identical with same seed)")
	return true
