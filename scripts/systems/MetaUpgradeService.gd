extends Node
## MetaUpgradeService: Manages permanent meta upgrades purchased with essence
## 
## Handles upgrade definitions, leveling, prerequisite validation,
## effect aggregation, respec logic, and integration with game systems.

class_name MetaUpgradeService

# Signals
signal meta_upgrade_leveled(id: StringName, new_level: int)
signal meta_upgrades_respecced(refunded_essence: float)
signal meta_effects_updated()
signal essence_changed(total_essence: float)  # Emitted when essence changes due to meta upgrades
signal roi_dashboard_updated()

# Upgrade definitions loaded from JSON
var definitions: Dictionary = {}  # {id: MetaUpgrade}

# Aggregated effects cache: {effect_type: total_value}
var effect_aggregate: Dictionary = {}

func _ready() -> void:
	_load_definitions()
	print("MetaUpgradeService initialized with %d upgrade definitions" % definitions.size())

## Load upgrade definitions from JSON
func _load_definitions() -> void:
	var file_path := "res://data/meta_upgrades.json"
	if not FileAccess.file_exists(file_path):
		push_error("Meta upgrades data file not found: %s" % file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open meta upgrades data file")
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse meta upgrades JSON: %s" % json.get_error_message())
		return
	
	var data = json.data
	if not data is Array:
		push_error("Meta upgrades JSON should be an array")
		return
	
	# Load each upgrade definition
	for upgrade_data in data:
		if not upgrade_data is Dictionary:
			continue
		
		var upgrade := MetaUpgrade.new()
		upgrade.from_dict(upgrade_data)
		
		# Validate cost curve
		if not _validate_cost_curve(upgrade):
			push_warning("Invalid cost curve for upgrade %s" % upgrade.id)
		
		definitions[upgrade.id] = upgrade
	
	print("Loaded %d meta upgrade definitions" % definitions.size())

## Validate cost curve has required fields
func _validate_cost_curve(upgrade: MetaUpgrade) -> bool:
	match upgrade.cost_curve:
		"EXPONENTIAL":
			return upgrade.growth > 1.0
		"LINEAR":
			return upgrade.base_cost > 0.0
		"POLY":
			return upgrade.poly_coeffs.size() >= 2
		_:
			return false

## Get upgrade definition by ID
func get_upgrade(upgrade_id: String) -> MetaUpgrade:
	return definitions.get(upgrade_id, null)

## Check if player can level up an upgrade
func can_level(upgrade_id: String) -> bool:
	if not definitions.has(upgrade_id):
		return false
	
	var upgrade: MetaUpgrade = definitions[upgrade_id]
	
	# Check if maxed
	if upgrade.is_maxed():
		return false
	
	# Check prerequisites
	if not prerequisites_satisfied(upgrade_id):
		return false
	
	# Check essence cost
	var cost := upgrade.get_next_cost()
	if GameState.essence < cost:
		return false
	
	return true

## Level up an upgrade (spend essence and increment level)
func level_up(upgrade_id: String) -> bool:
	if not can_level(upgrade_id):
		return false
	
	var upgrade: MetaUpgrade = definitions[upgrade_id]
	var cost := upgrade.get_next_cost()
	
	# Spend essence
	GameState.essence -= cost
	GameState.essence_spent += cost
	
	# Increment level in both definition and save state
	upgrade.current_level += 1
	if not GameState.meta_upgrades.has(upgrade_id):
		GameState.meta_upgrades[upgrade_id] = 0
	GameState.meta_upgrades[upgrade_id] = upgrade.current_level
	
	# Recompute effects
	recompute_meta_effects()
	
	# Emit signals
	meta_upgrade_leveled.emit(upgrade_id, upgrade.current_level)
	essence_changed.emit(GameState.essence)
	
	print("Leveled up %s to level %d (cost: %.1f essence)" % [upgrade.name, upgrade.current_level, cost])
	
	return true

## Check if all prerequisites are satisfied
func prerequisites_satisfied(upgrade_id: String) -> bool:
	if not definitions.has(upgrade_id):
		return false
	
	var upgrade: MetaUpgrade = definitions[upgrade_id]
	
	# Check total prestiges requirement
	if GameState.total_prestiges < upgrade.requires_total_prestiges:
		return false
	
	# Check each prerequisite
	for prereq in upgrade.prerequisites:
		var parts := (prereq as String).split(":")
		if parts.size() != 2:
			continue
		
		var prereq_id := parts[0]
		var required_level := int(parts[1])
		
		# Check if prerequisite upgrade exists and has required level
		if not definitions.has(prereq_id):
			return false
		
		var current_level := GameState.meta_upgrades.get(prereq_id, 0)
		if current_level < required_level:
			return false
	
	return true

## Recompute aggregated effects from all meta upgrades
func recompute_meta_effects() -> void:
	effect_aggregate.clear()
	
	# Sum up effects from all upgrades
	for upgrade_id in definitions:
		var upgrade: MetaUpgrade = definitions[upgrade_id]
		var level := GameState.meta_upgrades.get(upgrade_id, 0)
		
		if level > 0:
			var effect := upgrade.cumulative_effect(level)
			var effect_type := upgrade.effect_type
			
			if not effect_aggregate.has(effect_type):
				effect_aggregate[effect_type] = 0.0
			
			effect_aggregate[effect_type] += effect
	
	# Update game state cache
	GameState.meta_effects_cache = effect_aggregate.duplicate()
	
	# Emit signal
	meta_effects_updated.emit()

## Respec all meta upgrades (partial refund)
func respec_all() -> Dictionary:
	# Check cooldown
	var now := Time.get_unix_time_from_system()
	var cooldown_remaining := BalanceConstants.META_RESPEC_COOLDOWN_SEC - (now - GameState.last_respec_time)
	
	if cooldown_remaining > 0:
		push_warning("Respec on cooldown: %d seconds remaining" % int(cooldown_remaining))
		return {"success": false, "cooldown_remaining": cooldown_remaining}
	
	# Calculate total spent
	var total_spent := compute_total_spent_all()
	
	# Calculate refund
	var refund := total_spent * BalanceConstants.META_REFUND_RATE
	
	# Refund essence
	GameState.essence += refund
	GameState.essence_spent -= total_spent  # Reset spent counter
	
	# Reset all levels
	for upgrade_id in definitions:
		definitions[upgrade_id].current_level = 0
	GameState.meta_upgrades.clear()
	
	# Update respec tracking
	GameState.respec_tokens += 1
	GameState.last_respec_time = now
	
	# Recompute effects (will clear since all levels are 0)
	recompute_meta_effects()
	
	# Emit signals
	meta_upgrades_respecced.emit(refund)
	essence_changed.emit(GameState.essence)
	
	print("Respecced all meta upgrades: refunded %.1f essence (%.0f%% of %.1f spent)" % [refund, BalanceConstants.META_REFUND_RATE * 100, total_spent])
	
	return {
		"success": true,
		"refunded": refund,
		"total_spent": total_spent
	}

## Compute total essence spent on all upgrades
func compute_total_spent_all() -> float:
	var total := 0.0
	
	for upgrade_id in definitions:
		total += compute_total_spent(upgrade_id)
	
	return total

## Compute total essence spent on a specific upgrade
func compute_total_spent(upgrade_id: String) -> float:
	if not definitions.has(upgrade_id):
		return 0.0
	
	var upgrade: MetaUpgrade = definitions[upgrade_id]
	var level := GameState.meta_upgrades.get(upgrade_id, 0)
	
	var total := 0.0
	for i in range(level):
		total += upgrade.cost(i)
	
	return total

## Get effect value for next level of an upgrade
func get_next_level_effect(upgrade_id: String) -> float:
	if not definitions.has(upgrade_id):
		return 0.0
	
	var upgrade: MetaUpgrade = definitions[upgrade_id]
	return upgrade.get_next_level_effect()

## Calculate ROI score for an upgrade (higher = better investment)
func compute_roi(upgrade_id: String, current_idle_rate: float = 1.0) -> float:
	if not definitions.has(upgrade_id):
		return 0.0
	
	var upgrade: MetaUpgrade = definitions[upgrade_id]
	
	if upgrade.is_maxed():
		return 0.0
	
	var next_cost := upgrade.get_next_cost()
	if next_cost <= 0.0 or next_cost == INF:
		return 0.0
	
	var effect := upgrade.get_next_level_effect()
	
	# ROI formula depends on effect type
	var roi := 0.0
	match upgrade.effect_type:
		"idle_rate_multiplier":
			# Multiplier effects scale with current rate
			roi = (effect * current_idle_rate) / next_cost
		"idle_rate_add":
			# Additive effects are flat
			roi = effect / next_cost
		"essence_gain_multiplier":
			# High value for essence multipliers
			roi = (effect * 10.0) / next_cost
		"combat_attack_mult", "combat_defense_mult":
			# Combat multipliers have moderate value
			roi = (effect * 5.0) / next_cost
		"combat_crit_chance_add":
			# Crit chance is valuable
			roi = (effect * 20.0) / next_cost
		"combat_crit_multiplier_add":
			# Crit multiplier is very valuable
			roi = (effect * 10.0) / next_cost
		"drop_rate_multiplier":
			# Drop rate is moderately valuable
			roi = (effect * 3.0) / next_cost
		"offline_gain_multiplier":
			# Offline gains are valuable
			roi = (effect * 8.0) / next_cost
		_:
			# Default: simple effect/cost ratio
			roi = effect / next_cost
	
	return roi

## Sync upgrade levels from GameState to definitions
func sync_levels_from_game_state() -> void:
	for upgrade_id in definitions:
		var level := GameState.meta_upgrades.get(upgrade_id, 0)
		definitions[upgrade_id].current_level = level
	
	# Recompute effects after sync
	recompute_meta_effects()
