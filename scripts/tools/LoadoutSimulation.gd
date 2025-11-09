extends RefCounted
## LoadoutSimulation: Balancing tool for evaluating item loadouts
## 
## Provides DPS and idle rate calculations for given item combinations.

class_name LoadoutSimulation

## Simulate idle gain rate with a given loadout
## loadout: Array of ItemModel
## base_rate: Base idle rate before modifiers
## Returns: Effective idle rate per second
static func simulate_idle_gain(loadout: Array, base_rate: float) -> float:
	var idle_additive := 0.0
	var idle_multiplier := 1.0
	
	for item in loadout:
		if not item is ItemModel:
			continue
		
		# Use compute_total_effects to include affixes
		var total_effects := item.compute_total_effects()
		for effect in total_effects:
			var effect_type: String = effect.get("type", "")
			var value: float = effect.get("value", 0.0)
			
			match effect_type:
				Constants.EffectType.IDLE_RATE_ADD:
					idle_additive += value
				Constants.EffectType.IDLE_RATE_MULTIPLIER:
					idle_multiplier += value
	
	# Apply caps
	idle_multiplier = minf(idle_multiplier, BalanceConstants.ITEM_IDLE_MULT_CAP)
	
	# Calculate effective rate: (base + additive) * multiplier
	var effective_rate := (base_rate + idle_additive) * idle_multiplier
	return effective_rate

## Simulate combat DPS with a given loadout
## loadout: Array of ItemModel
## base_attack: Base attack before modifiers
## essence: Current essence for bonus calculation
## Returns: Approximate DPS (damage per second)
static func simulate_combat_dps(loadout: Array, base_attack: float, essence: float = 0.0) -> float:
	var attack_add := 0.0
	var attack_mult := 1.0
	var crit_chance := BalanceConstants.PLAYER_BASE_CRIT_CHANCE
	var crit_multiplier := BalanceConstants.PLAYER_BASE_CRIT_MULTIPLIER
	var speed_add := 0.0
	
	for item in loadout:
		if not item is ItemModel:
			continue
		
		# Use compute_total_effects to include affixes
		var total_effects := item.compute_total_effects()
		for effect in total_effects:
			var effect_type: String = effect.get("type", "")
			var value: float = effect.get("value", 0.0)
			
			match effect_type:
				Constants.EffectType.COMBAT_ATTACK_ADD:
					attack_add += value
				Constants.EffectType.COMBAT_ATTACK_MULT:
					attack_mult += value
				Constants.EffectType.COMBAT_CRIT_CHANCE_ADD:
					crit_chance += value
				Constants.EffectType.COMBAT_CRIT_MULTIPLIER_ADD:
					crit_multiplier += value
				Constants.EffectType.COMBAT_SPEED_ADD:
					speed_add += value
	
	# Apply caps
	attack_mult = minf(attack_mult, BalanceConstants.ITEM_ATTACK_MULT_CAP)
	crit_chance = clampf(crit_chance, 0.0, 1.0)
	
	# Apply essence bonus
	var essence_bonus := 1.0 + (BalanceConstants.COMBAT_ESSENCE_MULTIPLIER * sqrt(essence))
	
	# Calculate effective attack
	var effective_attack := (base_attack + attack_add) * attack_mult * essence_bonus
	
	# Calculate attacks per second
	var base_speed := 1.0
	var attacks_per_second := (base_speed + speed_add)
	
	# Calculate expected damage per hit (accounting for crit)
	# Expected damage = base_damage * (1 - crit_chance) + (base_damage * crit_mult) * crit_chance
	# = base_damage * (1 - crit_chance + crit_mult * crit_chance)
	# = base_damage * (1 + (crit_mult - 1) * crit_chance)
	var crit_factor := 1.0 + (crit_multiplier - 1.0) * crit_chance
	var expected_damage_per_hit := effective_attack * crit_factor
	
	# DPS = expected damage per hit * attacks per second
	var dps := expected_damage_per_hit * attacks_per_second
	return dps

## Calculate total effective stats for a loadout
## Returns: Dictionary with all computed stats
static func calculate_loadout_stats(loadout: Array, base_attack: float = 10.0, base_defense: float = 5.0, essence: float = 0.0) -> Dictionary:
	var stats := {
		"attack_add": 0.0,
		"attack_mult": 1.0,
		"defense_add": 0.0,
		"defense_mult": 1.0,
		"crit_chance": BalanceConstants.PLAYER_BASE_CRIT_CHANCE,
		"crit_multiplier": BalanceConstants.PLAYER_BASE_CRIT_MULTIPLIER,
		"speed_add": 0.0,
		"idle_add": 0.0,
		"idle_mult": 1.0
	}
	
	for item in loadout:
		if not item is ItemModel:
			continue
		
		# Use compute_total_effects to include affixes
		var total_effects := item.compute_total_effects()
		for effect in total_effects:
			var effect_type: String = effect.get("type", "")
			var value: float = effect.get("value", 0.0)
			
			match effect_type:
				Constants.EffectType.COMBAT_ATTACK_ADD:
					stats["attack_add"] += value
				Constants.EffectType.COMBAT_ATTACK_MULT:
					stats["attack_mult"] += value
				Constants.EffectType.COMBAT_DEFENSE_ADD:
					stats["defense_add"] += value
				Constants.EffectType.COMBAT_DEFENSE_MULT:
					stats["defense_mult"] += value
				Constants.EffectType.COMBAT_CRIT_CHANCE_ADD:
					stats["crit_chance"] += value
				Constants.EffectType.COMBAT_CRIT_MULTIPLIER_ADD:
					stats["crit_multiplier"] += value
				Constants.EffectType.COMBAT_SPEED_ADD:
					stats["speed_add"] += value
				Constants.EffectType.IDLE_RATE_ADD:
					stats["idle_add"] += value
				Constants.EffectType.IDLE_RATE_MULTIPLIER:
					stats["idle_mult"] += value
	
	# Apply caps
	stats["attack_mult"] = minf(stats["attack_mult"], BalanceConstants.ITEM_ATTACK_MULT_CAP)
	stats["idle_mult"] = minf(stats["idle_mult"], BalanceConstants.ITEM_IDLE_MULT_CAP)
	stats["crit_chance"] = clampf(stats["crit_chance"], 0.0, 1.0)
	
	# Calculate effective values
	var essence_bonus := 1.0 + (BalanceConstants.COMBAT_ESSENCE_MULTIPLIER * sqrt(essence))
	stats["effective_attack"] = (base_attack + stats["attack_add"]) * stats["attack_mult"] * essence_bonus
	stats["effective_defense"] = (base_defense + stats["defense_add"]) * stats["defense_mult"] * essence_bonus
	stats["effective_speed"] = 1.0 + stats["speed_add"]
	
	return stats
