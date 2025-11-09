## Test Combat Simple Win: Verify player can defeat a simple wave
## 
## Tests basic combat mechanics and victory condition.

extends Node

func _ready() -> void:
	print("=== Running Combat Simple Win Test ===\n")
	
	var all_passed := true
	
	# Test 1: Player wins against weak enemies
	all_passed = test_simple_victory() and all_passed
	
	# Test 2: Gold reward is added correctly
	all_passed = test_gold_reward() and all_passed
	
	# Test 3: Lifetime enemies defeated increments
	all_passed = test_lifetime_enemies() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All combat simple win tests passed!")
	else:
		print("✗ Some combat simple win tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_simple_victory() -> bool:
	print("Test: Player wins against weak enemies")
	
	# Set up player with strong stats
	GameState.player_stats.attack = 50.0
	GameState.player_stats.defense = 10.0
	GameState.player_stats.combat_speed = 2.0
	GameState.essence = 0.0
	
	# Simulate wave 0 (weakest enemies)
	var result := CombatSystem.fast_simulate_wave(0, 12345)
	
	if not result.get("victory", false):
		print("  ✗ Player failed to win against wave 0")
		print("  Reason: %s" % result.get("failure_reason", "Unknown"))
		return false
	
	var time_elapsed: float = result.get("time", 0.0)
	var enemies_defeated: int = result.get("enemies_defeated", 0)
	
	print("  ✓ Player won! Time: %.2fs, Enemies: %d" % [time_elapsed, enemies_defeated])
	return true

func test_gold_reward() -> bool:
	print("Test: Gold reward is added correctly")
	
	# Record starting gold
	var starting_gold := GameState.resources["gold"].amount
	
	# Set up player stats
	GameState.player_stats.attack = 50.0
	GameState.player_stats.defense = 10.0
	GameState.player_stats.combat_speed = 2.0
	GameState.essence = 0.0
	
	# Simulate wave
	var result := CombatSystem.fast_simulate_wave(0, 12345)
	
	if not result.get("victory", false):
		print("  ✗ Player didn't win, can't test rewards")
		return false
	
	# Check gold increased
	var ending_gold := GameState.resources["gold"].amount
	var gold_gained := ending_gold - starting_gold
	
	var rewards: Dictionary = result.get("rewards", {})
	var expected_gold: float = rewards.get("gold", 0.0)
	
	if abs(gold_gained - expected_gold) > 0.1:
		print("  ✗ Gold gained mismatch: expected %.2f, got %.2f" % [expected_gold, gold_gained])
		return false
	
	print("  ✓ Gold reward correct: +%.2f" % gold_gained)
	return true

func test_lifetime_enemies() -> bool:
	print("Test: Lifetime enemies defeated increments")
	
	# Record starting count
	var starting_count := GameState.lifetime_enemies_defeated
	
	# Set up player stats
	GameState.player_stats.attack = 50.0
	GameState.player_stats.defense = 10.0
	GameState.player_stats.combat_speed = 2.0
	GameState.essence = 0.0
	
	# Simulate wave
	var result := CombatSystem.fast_simulate_wave(0, 12345)
	
	if not result.get("victory", false):
		print("  ✗ Player didn't win, can't test enemy count")
		return false
	
	var ending_count := GameState.lifetime_enemies_defeated
	var enemies_defeated: int = result.get("enemies_defeated", 0)
	var count_increase := ending_count - starting_count
	
	if count_increase != enemies_defeated:
		print("  ✗ Lifetime count mismatch: expected +%d, got +%d" % [enemies_defeated, count_increase])
		return false
	
	print("  ✓ Lifetime enemies defeated incremented: +%d" % count_increase)
	return true
