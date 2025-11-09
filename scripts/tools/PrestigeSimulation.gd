extends RefCounted
## PrestigeSimulation: Tool for simulating resource growth with prestige
## 
## Used for balancing and testing prestige formulas.

class_name PrestigeSimulation

## Simulate resource growth over a period of time
## Returns final gold, lifetime_gold increment, and preview essence gain
static func simulate(
	duration_seconds: int,
	starting_gold: float,
	rate_per_sec: float,
	formula_constants: Dictionary = {}
) -> Dictionary:
	# Use provided constants or defaults
	var gold_denom: float = formula_constants.get("gold_denominator", BalanceConstants.GOLD_DENOMINATOR)
	var essence_exp: float = formula_constants.get("essence_exponent", BalanceConstants.ESSENCE_EXPONENT)
	var soft_cap_base: float = formula_constants.get("soft_cap_base", BalanceConstants.SOFT_CAP_BASE)
	var soft_cap_exp: float = formula_constants.get("soft_cap_exponent", BalanceConstants.SOFT_CAP_EXPONENT)
	
	# Calculate final gold after duration
	var gold_gained: float = rate_per_sec * float(duration_seconds)
	var final_gold: float = starting_gold + gold_gained
	
	# Lifetime gold increments by the same amount
	var lifetime_gold_increment: float = gold_gained
	
	# Calculate essence gain if prestiging now
	var total_lifetime: float = starting_gold + lifetime_gold_increment
	var preview_essence: int = _calculate_essence(
		total_lifetime,
		gold_denom,
		essence_exp,
		soft_cap_base,
		soft_cap_exp
	)
	
	return {
		"final_gold": final_gold,
		"lifetime_gold_increment": lifetime_gold_increment,
		"preview_essence_gain": preview_essence,
		"duration_seconds": duration_seconds,
		"rate_per_sec": rate_per_sec
	}

## Calculate essence gain using the formula
static func _calculate_essence(
	lifetime_gold: float,
	gold_denom: float,
	essence_exp: float,
	soft_cap_base: float,
	soft_cap_exp: float
) -> int:
	if lifetime_gold < gold_denom:
		return 0
	
	var ratio: float = lifetime_gold / gold_denom
	var raw_essence: float = pow(ratio, essence_exp)
	
	# Apply soft cap
	if lifetime_gold > soft_cap_base:
		var post_cap_factor: float = pow(soft_cap_base / lifetime_gold, soft_cap_exp)
		raw_essence *= post_cap_factor
	
	return int(floor(max(0.0, raw_essence)))
