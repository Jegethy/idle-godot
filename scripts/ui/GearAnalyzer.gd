extends RefCounted
## GearAnalyzer: Utility for comparing gear alternatives
## 
## Computes DPS and idle rate differences between equipped and candidate items.

class_name GearAnalyzer

## Compare a candidate item against currently equipped item in the same slot
## Returns: Dictionary with comparison metrics
static func compare_items(candidate: ItemModel, slot: String) -> Dictionary:
	var result: Dictionary = {
		"can_compare": false,
		"idle_delta_pct": 0.0,
		"dps_delta_pct": 0.0,
		"attack_delta": 0.0,
		"defense_delta": 0.0,
		"crit_chance_delta": 0.0,
		"idle_rate_delta": 0.0,
		"is_improvement": false
	}
	
	if not candidate or candidate.slot != slot:
		return result
	
	# Get current equipped item in this slot
	var current_item: ItemModel = null
	if GameState.equipped_slots.has(slot):
		var instance_id: String = GameState.equipped_slots[slot]
		current_item = InventorySystem.get_item_by_instance_id(instance_id)
	
	# Build loadouts
	var current_loadout: Array[ItemModel] = []
	var candidate_loadout: Array[ItemModel] = []
	
	# Add all currently equipped items
	for equipped_slot in GameState.equipped_slots:
		var inst_id: String = GameState.equipped_slots[equipped_slot]
		var item := InventorySystem.get_item_by_instance_id(inst_id)
		if item:
			current_loadout.append(item)
			
			# For candidate loadout, substitute the slot with candidate
			if equipped_slot == slot:
				candidate_loadout.append(candidate)
			else:
				candidate_loadout.append(item)
	
	# If slot is empty, just add candidate
	if not current_item:
		candidate_loadout.append(candidate)
	
	# Calculate base stats
	var base_attack: float = GameState.player_stats.attack
	var base_defense: float = GameState.player_stats.defense
	var base_idle_rate: float = 1.0  # Base gold per second
	var essence: float = GameState.essence
	
	# Calculate DPS
	var current_dps := LoadoutSimulation.simulate_combat_dps(current_loadout, base_attack, essence)
	var candidate_dps := LoadoutSimulation.simulate_combat_dps(candidate_loadout, base_attack, essence)
	
	# Calculate idle rate
	var current_idle := LoadoutSimulation.simulate_idle_gain(current_loadout, base_idle_rate)
	var candidate_idle := LoadoutSimulation.simulate_idle_gain(candidate_loadout, base_idle_rate)
	
	# Calculate deltas
	if current_dps > 0.0:
		result["dps_delta_pct"] = ((candidate_dps - current_dps) / current_dps) * 100.0
	else:
		result["dps_delta_pct"] = 100.0 if candidate_dps > 0.0 else 0.0
	
	if current_idle > 0.0:
		result["idle_delta_pct"] = ((candidate_idle - current_idle) / current_idle) * 100.0
	else:
		result["idle_delta_pct"] = 100.0 if candidate_idle > 0.0 else 0.0
	
	# Calculate detailed stats using LoadoutSimulation
	var current_stats := LoadoutSimulation.calculate_loadout_stats(current_loadout, base_attack, base_defense, essence)
	var candidate_stats := LoadoutSimulation.calculate_loadout_stats(candidate_loadout, base_attack, base_defense, essence)
	
	result["attack_delta"] = candidate_stats["effective_attack"] - current_stats["effective_attack"]
	result["defense_delta"] = candidate_stats["effective_defense"] - current_stats["effective_defense"]
	result["crit_chance_delta"] = candidate_stats["crit_chance"] - current_stats["crit_chance"]
	result["idle_rate_delta"] = candidate_idle - current_idle
	
	# Determine if it's an improvement
	var threshold := BalanceConstants.ANALYZER_MIN_IMPROVEMENT_THRESHOLD * 100.0
	result["is_improvement"] = (
		result["dps_delta_pct"] > threshold or 
		result["idle_delta_pct"] > threshold
	)
	
	result["can_compare"] = true
	return result

## Get formatted comparison text
static func get_comparison_text(comparison: Dictionary) -> String:
if not comparison.get("can_compare", false):
return "Cannot compare items"

var lines: Array[String] = []

# DPS change
var dps_delta: float = comparison.get("dps_delta_pct", 0.0)
var dps_text := NumberFormatter.format_delta(100.0, 100.0 + dps_delta, 1)
lines.append("Combat DPS: %s" % dps_text)

# Idle rate change
var idle_delta: float = comparison.get("idle_delta_pct", 0.0)
var idle_text := NumberFormatter.format_delta(100.0, 100.0 + idle_delta, 1)
lines.append("Idle Rate: %s" % idle_text)

	# Attack change
	var attack_delta: float = comparison.get("attack_delta", 0.0)
	if abs(attack_delta) > 0.1:
		var sign_str := "+" if attack_delta > 0 else ""
		lines.append("Attack: %s%.1f" % [sign_str, attack_delta])
	
	# Defense change
	var defense_delta: float = comparison.get("defense_delta", 0.0)
	if abs(defense_delta) > 0.1:
		var sign_str := "+" if defense_delta > 0 else ""
		lines.append("Defense: %s%.1f" % [sign_str, defense_delta])
	
	# Crit chance change
	var crit_delta: float = comparison.get("crit_chance_delta", 0.0)
	if abs(crit_delta) > 0.001:
		var sign_str := "+" if crit_delta > 0 else ""
		lines.append("Crit Chance: %s%s" % [sign_str, NumberFormatter.format_percentage(crit_delta)])

# Recommendation
if comparison.get("is_improvement", false):
lines.append("")
lines.append("✓ Recommended upgrade")

return "\n".join(lines)
