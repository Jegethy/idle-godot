extends RefCounted
## MetaProjection: Calculate expected returns and payback times for meta upgrades
## 
## Provides simulation tools for projection and ROI analysis.

class_name MetaProjection

## Project new idle rate after applying a delta multiplier
static func project_idle_gain(delta_multiplier: float, current_idle_rate: float) -> float:
	return current_idle_rate * (1.0 + delta_multiplier)

## Estimate payback time in seconds for an upgrade investment
## Returns INF if delta_rate <= 0
static func estimate_payback(cost: float, current_idle_rate: float, delta_rate: float) -> float:
	if delta_rate <= 0.0:
		return INF
	
	# Payback time = cost / additional_rate_per_second
	return cost / delta_rate

## Rank upgrades by ROI (highest first)
## upgrades_list: Array of upgrade IDs
## current_idle_rate: Current idle production rate for calculations
## Returns: Array of {id: String, roi: float, name: String} sorted by ROI descending
static func rank_upgrades_by_roi(upgrades_list: Array, current_idle_rate: float, meta_service: MetaUpgradeService) -> Array:
	var ranked := []
	
	for upgrade_id in upgrades_list:
		var upgrade := meta_service.get_upgrade(upgrade_id)
		if not upgrade:
			continue
		
		var roi := meta_service.compute_roi(upgrade_id, current_idle_rate)
		ranked.append({
			"id": upgrade_id,
			"roi": roi,
			"name": upgrade.name,
			"category": upgrade.category
		})
	
	# Sort by ROI descending
	ranked.sort_custom(func(a, b): return a["roi"] > b["roi"])
	
	return ranked

## Calculate expected payback time for a specific upgrade
## Returns dictionary with payback_seconds and is_finite
static func calculate_payback_for_upgrade(
	upgrade: MetaUpgrade,
	current_idle_rate: float
) -> Dictionary:
	if not upgrade or upgrade.is_maxed():
		return {"payback_seconds": INF, "is_finite": false}
	
	var cost := upgrade.get_next_cost()
	var effect := upgrade.get_next_level_effect()
	
	# Calculate delta rate based on effect type
	var delta_rate := 0.0
	match upgrade.effect_type:
		"idle_rate_multiplier":
			# Multiplier: delta = current_rate * effect
			delta_rate = current_idle_rate * effect
		"idle_rate_add":
			# Additive: delta = effect
			delta_rate = effect
		_:
			# Non-idle effects don't have direct payback
			return {"payback_seconds": INF, "is_finite": false}
	
	var payback := estimate_payback(cost, current_idle_rate, delta_rate)
	
	return {
		"payback_seconds": payback,
		"is_finite": payback < INF
	}
