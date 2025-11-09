extends Node
## PrestigeService: Manages prestige mechanics and essence currency
## 
## Handles prestige validation, essence gain calculation,
## prestige reset flow, and essence multiplier application.

# Signals
signal prestige_performed(gained: int, total_essence: float, total_prestiges: int)
signal essence_changed(total_essence: float)

func _ready() -> void:
	print("PrestigeService initialized")

## Check if player can prestige (meets requirements)
func can_prestige() -> bool:
	# Check if player meets any of the prestige requirements
	var has_lifetime_gold: bool = false
	var has_current_gold: bool = false
	
	# Check lifetime_gold requirement
	has_lifetime_gold = GameState.lifetime_gold >= BalanceConstants.PRESTIGE_REQUIRED_LIFETIME_GOLD
	
	# Check current gold requirement
	if GameState.resources.has("gold"):
		has_current_gold = GameState.resources["gold"].amount >= BalanceConstants.PRESTIGE_CURRENT_GOLD_REQUIREMENT
	
	# Must also have positive essence gain
	return (has_lifetime_gold or has_current_gold) and preview_essence_gain() > 0

## Preview how much essence would be gained if prestiging now
func preview_essence_gain() -> int:
	var lifetime_gold: float = GameState.lifetime_gold
	
	# Fallback: use current gold if lifetime_gold is 0
	if lifetime_gold == 0.0 and GameState.resources.has("gold"):
		lifetime_gold = GameState.resources["gold"].amount
	
	return _calculate_essence_gain(lifetime_gold)

## Calculate essence gain from lifetime gold using formula with soft cap
func _calculate_essence_gain(lifetime_gold: float) -> int:
	if lifetime_gold < BalanceConstants.GOLD_DENOMINATOR:
		return 0
	
	# Base formula: essence_gain = floor((lifetime_gold / GOLD_DENOMINATOR) ^ ESSENCE_EXPONENT)
	var ratio: float = lifetime_gold / BalanceConstants.GOLD_DENOMINATOR
	var raw_essence: float = pow(ratio, BalanceConstants.ESSENCE_EXPONENT)
	
	# Apply soft cap for very high lifetime_gold
	if lifetime_gold > BalanceConstants.SOFT_CAP_BASE:
		var post_cap_factor: float = pow(
			BalanceConstants.SOFT_CAP_BASE / lifetime_gold,
			BalanceConstants.SOFT_CAP_EXPONENT
		)
		raw_essence *= post_cap_factor
	
	# Apply meta upgrade essence gain multiplier
	raw_essence *= (1.0 + float(GameState.meta_effects_cache.get(&"essence_gain_multiplier", 0.0)))
	
	# Floor and clamp to non-negative
	var final_essence: int = int(floor(raw_essence))
	return max(0, final_essence)

## Perform prestige: reset progress and grant essence
func perform_prestige() -> Dictionary:
	if not can_prestige():
		push_warning("Cannot prestige: requirements not met")
		return {"success": false, "gained": 0, "total_essence": 0.0, "total_prestiges": 0}
	
	# Calculate essence gain
	var gained: int = preview_essence_gain()
	
	# Add to essence
	GameState.essence += float(gained)
	
	# Increment total_prestiges
	GameState.total_prestiges += 1
	
	# Store values before reset for return
	var new_essence_total: float = GameState.essence
	var total_prestiges: int = GameState.total_prestiges
	
	# Perform reset
	_reset_for_prestige()
	
	# Recalculate rates with new essence multiplier
	Economy.recalculate_all_rates()
	
	# Save immediately
	SaveSystem.save()
	
	# Emit signals
	prestige_performed.emit(gained, new_essence_total, total_prestiges)
	essence_changed.emit(new_essence_total)
	
	print("Prestige performed! Gained %d essence (total: %.0f, prestiges: %d)" % [gained, new_essence_total, total_prestiges])
	
	return {
		"success": true,
		"gained": gained,
		"total_essence": new_essence_total,
		"total_prestiges": total_prestiges
	}

## Reset game state for prestige (keep essence, lifetime_gold, and meta progress)
func _reset_for_prestige() -> void:
	# Reset gold to 0
	if GameState.resources.has("gold"):
		GameState.resources["gold"].amount = 0.0
	
	# Reset all upgrades to level 0
	for upgrade_id in GameState.upgrades:
		GameState.upgrades[upgrade_id].level = 0
	
	# Clear items
	GameState.items.clear()
	
	# Reset player stats to baseline (preserve essence-derived multipliers)
	GameState.player_stats = PlayerStatsModel.new()
	
	# Essence, lifetime_gold, and total_prestiges are NOT reset
	
	# Update last_saved_time
	SaveSystem.last_saved_time = Time.get_unix_time_from_system()

## Update lifetime_gold when gold is gained (called from Economy)
func update_lifetime_gold(delta_gold: float) -> void:
	if delta_gold <= 0:
		return
	
	GameState.lifetime_gold += delta_gold

## Calculate current essence multiplier for idle rates
func get_essence_multiplier() -> float:
	var essence: float = GameState.essence
	if essence <= 0:
		return 1.0
	
	# Multiplier = 1 + ESSENCE_BASE_MULTIPLIER * sqrt(essence)
	var bonus: float = BalanceConstants.ESSENCE_BASE_MULTIPLIER * sqrt(essence)
	return 1.0 + bonus

## Get formatted essence multiplier for display (e.g., "+5.2%")
func get_essence_multiplier_display() -> String:
	var multiplier: float = get_essence_multiplier()
	var percent_bonus: float = (multiplier - 1.0) * 100.0
	if percent_bonus < 0.01:
		return "+0.0%"
	return "+%.1f%%" % percent_bonus
