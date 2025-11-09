extends Node
## CombatSimulation: Tool for simulating and analyzing combat waves
## 
## Provides helper functions for combat balancing and testing.

class_name CombatSimulation

## Simulate a wave and return summary
static func simulate_wave(wave_index: int, seed: int, fast: bool = true) -> Dictionary:
	if fast:
		return CombatSystem.fast_simulate_wave(wave_index, seed)
	else:
		# Interactive mode: start wave and manually tick
		CombatSystem.start_wave(wave_index, seed)
		
		while CombatSystem.combat_active:
			CombatSystem.simulate_tick()
		
		# Get the result from the last combat_finished signal
		# For now, create a basic summary
		return {
			"wave_index": wave_index,
			"seed": seed,
			"victory": false,
			"note": "Interactive simulation completed"
		}

## Run multiple simulations for statistics
static func simulate_multiple_waves(wave_index: int, num_runs: int, base_seed: int = 12345) -> Dictionary:
	var victories := 0
	var total_time := 0.0
	var total_dps := 0.0
	var total_gold := 0.0
	
	for i in range(num_runs):
		var seed := base_seed + i
		var result := simulate_wave(wave_index, seed, true)
		
		if result.get("victory", false):
			victories += 1
		
		total_time += result.get("time", 0.0)
		total_dps += result.get("dps", 0.0)
		
		var rewards: Dictionary = result.get("rewards", {})
		total_gold += rewards.get("gold", 0.0)
	
	return {
		"num_runs": num_runs,
		"victories": victories,
		"win_rate": float(victories) / num_runs,
		"avg_time": total_time / num_runs,
		"avg_dps": total_dps / num_runs,
		"avg_gold": total_gold / num_runs
	}

## Analyze enemy scaling across waves
static func analyze_wave_scaling(start_wave: int, end_wave: int) -> Array[Dictionary]:
	var analysis: Array[Dictionary] = []
	
	for wave_idx in range(start_wave, end_wave + 1):
		var enemies := CombatSystem._generate_wave_enemies(wave_idx)
		
		var total_hp := 0.0
		var total_attack := 0.0
		var enemy_count := enemies.size()
		
		for enemy in enemies:
			total_hp += enemy.get("max_hp", 0.0)
			total_attack += enemy.get("attack", 0.0)
		
		analysis.append({
			"wave": wave_idx,
			"enemy_count": enemy_count,
			"total_hp": total_hp,
			"avg_hp": total_hp / enemy_count if enemy_count > 0 else 0.0,
			"avg_attack": total_attack / enemy_count if enemy_count > 0 else 0.0
		})
	
	return analysis
