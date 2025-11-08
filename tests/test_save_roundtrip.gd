## Test Save Roundtrip: Test save and load preserves state
## 
## Validates that saving and loading preserves resource amounts.

extends SceneTree

const TOLERANCE := 0.01  # Float comparison tolerance

func _init() -> void:
	print("=== Running Save Roundtrip Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Save and load preserves gold amount
	all_passed = test_save_load_preserves_gold() and all_passed
	
	# Test 2: Save and load preserves upgrade levels
	all_passed = test_save_load_preserves_upgrades() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All save roundtrip tests passed!")
	else:
		print("✗ Some save roundtrip tests failed")
	
	quit(0 if all_passed else 1)

func test_save_load_preserves_gold() -> bool:
	print("Test: Save/load preserves gold amount")
	
	# Set gold to a known value
	var test_amount := 1234.56
	if GameState.resources.has("gold"):
		GameState.resources["gold"].amount = test_amount
	else:
		print("  ✗ Gold resource not found in GameState")
		return false
	
	# Save the game
	var save_success := SaveSystem.save_game()
	if not save_success:
		print("  ✗ Failed to save game")
		return false
	
	# Modify gold to a different value
	GameState.resources["gold"].amount = 9999.99
	
	# Load the game
	var load_success := SaveSystem.load_game()
	if not load_success:
		print("  ✗ Failed to load game")
		return false
	
	# Check if gold amount was restored
	var loaded_amount := GameState.resources["gold"].amount
	
	# Account for offline progression by checking if it's close to original
	# (In a real scenario, offline progression would add to the amount,
	# but for this test we're checking basic save/load without time passing)
	if abs(loaded_amount - test_amount) > TOLERANCE:
		print("  ✗ Gold amount not preserved (expected %.2f, got %.2f)" % [test_amount, loaded_amount])
		return false
	
	print("  ✓ Gold amount preserved (%.2f)" % loaded_amount)
	return true

func test_save_load_preserves_upgrades() -> bool:
	print("\nTest: Save/load preserves upgrade levels")
	
	# Find an upgrade to test
	var test_upgrade_id := ""
	for upgrade_id in GameState.upgrades:
		test_upgrade_id = upgrade_id
		break
	
	if test_upgrade_id == "":
		print("  ✗ No upgrades found in GameState")
		return false
	
	# Set upgrade to a known level
	var test_level := 5
	GameState.upgrades[test_upgrade_id].level = test_level
	
	# Save the game
	var save_success := SaveSystem.save_game()
	if not save_success:
		print("  ✗ Failed to save game")
		return false
	
	# Modify upgrade to a different level
	GameState.upgrades[test_upgrade_id].level = 99
	
	# Load the game
	var load_success := SaveSystem.load_game()
	if not load_success:
		print("  ✗ Failed to load game")
		return false
	
	# Check if upgrade level was restored
	var loaded_level := GameState.upgrades[test_upgrade_id].level
	if loaded_level != test_level:
		print("  ✗ Upgrade level not preserved (expected %d, got %d)" % [test_level, loaded_level])
		return false
	
	print("  ✓ Upgrade level preserved (%s at level %d)" % [test_upgrade_id, loaded_level])
	return true
