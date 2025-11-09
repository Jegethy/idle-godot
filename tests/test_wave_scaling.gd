## Test Wave Scaling: Verify enemy stats scale correctly with wave index
## 
## Tests that enemy HP, attack, defense, and gold rewards scale according to formulas.

extends SceneTree

func _init() -> void:
	print("=== Running Wave Scaling Tests ===\n")
	
	var all_passed := true
	
	# Test 1: HP scales with growth factor
	all_passed = test_hp_scaling() and all_passed
	
	# Test 2: Attack scales with growth factor
	all_passed = test_attack_scaling() and all_passed
	
	# Test 3: Gold reward scales correctly
	all_passed = test_gold_scaling() and all_passed
	
	# Test 4: Elite multipliers apply correctly
	all_passed = test_elite_multipliers() and all_passed
	
	# Test 5: Boss multipliers apply correctly
	all_passed = test_boss_multipliers() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All wave scaling tests passed!")
	else:
		print("✗ Some wave scaling tests failed")
	
	quit(0 if all_passed else 1)

func test_hp_scaling() -> bool:
	print("Test: HP scales with growth factor")
	
	var enemy_id := "slime"
	var wave_0 := EnemyDatabase.get_scaled_enemy(enemy_id, 0)
	var wave_5 := EnemyDatabase.get_scaled_enemy(enemy_id, 5)
	
	var base_hp := wave_0.get("hp", 0.0)
	var scaled_hp := wave_5.get("hp", 0.0)
	
	# Get scaling factor from config
	var hp_growth := 1.15  # From wave_config.json
	var expected_hp := base_hp * pow(hp_growth, 5)
	
	var tolerance := expected_hp * 0.01  # 1% tolerance
	if abs(scaled_hp - expected_hp) > tolerance:
		print("  ✗ HP scaling incorrect: expected %.2f, got %.2f" % [expected_hp, scaled_hp])
		return false
	
	print("  ✓ HP scales correctly (base: %.2f, wave 5: %.2f)" % [base_hp, scaled_hp])
	return true

func test_attack_scaling() -> bool:
	print("Test: Attack scales with growth factor")
	
	var enemy_id := "goblin"
	var wave_0 := EnemyDatabase.get_scaled_enemy(enemy_id, 0)
	var wave_3 := EnemyDatabase.get_scaled_enemy(enemy_id, 3)
	
	var base_attack := wave_0.get("attack", 0.0)
	var scaled_attack := wave_3.get("attack", 0.0)
	
	var attack_growth := 1.10
	var expected_attack := base_attack * pow(attack_growth, 3)
	
	var tolerance := expected_attack * 0.01
	if abs(scaled_attack - expected_attack) > tolerance:
		print("  ✗ Attack scaling incorrect: expected %.2f, got %.2f" % [expected_attack, scaled_attack])
		return false
	
	print("  ✓ Attack scales correctly (base: %.2f, wave 3: %.2f)" % [base_attack, scaled_attack])
	return true

func test_gold_scaling() -> bool:
	print("Test: Gold reward scales correctly")
	
	var enemy_id := "skeleton"
	var wave_0 := EnemyDatabase.get_scaled_enemy(enemy_id, 0)
	var wave_10 := EnemyDatabase.get_scaled_enemy(enemy_id, 10)
	
	var base_gold := wave_0.get("gold_reward", 0.0)
	var scaled_gold := wave_10.get("gold_reward", 0.0)
	
	var gold_mult := 1.05
	var expected_gold := base_gold * pow(gold_mult, 10)
	
	var tolerance := expected_gold * 0.01
	if abs(scaled_gold - expected_gold) > tolerance:
		print("  ✗ Gold scaling incorrect: expected %.2f, got %.2f" % [expected_gold, scaled_gold])
		return false
	
	print("  ✓ Gold reward scales correctly (base: %.2f, wave 10: %.2f)" % [base_gold, scaled_gold])
	return true

func test_elite_multipliers() -> bool:
	print("Test: Elite multipliers apply correctly")
	
	var base_enemy := EnemyDatabase.get_scaled_enemy("slime", 1)
	var elite_enemy := EnemyDatabase.apply_elite_multipliers(base_enemy)
	
	var base_hp := base_enemy.get("hp", 0.0)
	var elite_hp := elite_enemy.get("hp", 0.0)
	var expected_hp := base_hp * BalanceConstants.ELITE_HP_MULTIPLIER
	
	if abs(elite_hp - expected_hp) > 0.1:
		print("  ✗ Elite HP multiplier incorrect: expected %.2f, got %.2f" % [expected_hp, elite_hp])
		return false
	
	var base_attack := base_enemy.get("attack", 0.0)
	var elite_attack := elite_enemy.get("attack", 0.0)
	var expected_attack := base_attack * BalanceConstants.ELITE_ATTACK_MULTIPLIER
	
	if abs(elite_attack - expected_attack) > 0.1:
		print("  ✗ Elite attack multiplier incorrect: expected %.2f, got %.2f" % [expected_attack, elite_attack])
		return false
	
	print("  ✓ Elite multipliers apply correctly (HP: %.2fx, Attack: %.2fx)" % [BalanceConstants.ELITE_HP_MULTIPLIER, BalanceConstants.ELITE_ATTACK_MULTIPLIER])
	return true

func test_boss_multipliers() -> bool:
	print("Test: Boss multipliers apply correctly")
	
	var base_enemy := EnemyDatabase.get_scaled_enemy("boss_core", 5)
	var boss_enemy := EnemyDatabase.apply_boss_multipliers(base_enemy)
	
	var base_hp := base_enemy.get("hp", 0.0)
	var boss_hp := boss_enemy.get("hp", 0.0)
	var expected_hp := base_hp * BalanceConstants.BOSS_HP_MULTIPLIER
	
	if abs(boss_hp - expected_hp) > 0.1:
		print("  ✗ Boss HP multiplier incorrect: expected %.2f, got %.2f" % [expected_hp, boss_hp])
		return false
	
	var base_attack := base_enemy.get("attack", 0.0)
	var boss_attack := boss_enemy.get("attack", 0.0)
	var expected_attack := base_attack * BalanceConstants.BOSS_ATTACK_MULTIPLIER
	
	if abs(boss_attack - expected_attack) > 0.1:
		print("  ✗ Boss attack multiplier incorrect: expected %.2f, got %.2f" % [expected_attack, boss_attack])
		return false
	
	print("  ✓ Boss multipliers apply correctly (HP: %.2fx, Attack: %.2fx)" % [BalanceConstants.BOSS_HP_MULTIPLIER, BalanceConstants.BOSS_ATTACK_MULTIPLIER])
	return true
