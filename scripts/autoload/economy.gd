extends Node
## Economy: Resource income calculation and upgrade management
## 
## Handles tick-based resource generation, upgrade application,
## cost scaling, and prestige formulas.

# Signals
signal rates_updated()

const EXP_GROWTH := 1.15

# Cached per-second rates for UI queries
var per_second_rates: Dictionary = {}  # {resource_id: float}

func _ready() -> void:
	print("Economy initialized")

func calculate_income_per_second(resource: ResourceModel) -> float:
	return get_per_second_rate(resource.id)

func get_per_second_rate(resource_id: String) -> float:
	# Return cached rate if available
	if per_second_rates.has(resource_id):
		return per_second_rates[resource_id]
	
	# Otherwise compute it
	return compute_resource_rate(resource_id)

func compute_resource_rate(resource_id: String) -> float:
	if not GameState.resources.has(resource_id):
		return 0.0
	
	var resource: ResourceModel = GameState.resources[resource_id]
	if not resource.unlocked:
		return 0.0
	
	# Start with base rate
	var rate_adders: float = resource.base_rate
	var multiplier_factors: float = 1.0
	
	# Apply upgrade effects
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		
		# Skip upgrades that don't target this resource or have level 0
		if upgrade.target != resource_id or upgrade.level == 0:
			continue
		
		match upgrade.type:
			UpgradeModel.UpgradeType.RATE:
				# Additive: base_bonus * level
				rate_adders += upgrade.base_bonus * upgrade.level
			UpgradeModel.UpgradeType.MULTIPLIER:
				# Multiplicative: (1 + base_bonus * level)
				multiplier_factors *= (1.0 + upgrade.base_bonus * upgrade.level)
	
	# Apply item additive bonuses
	if GameState.idle_additive.has(resource_id):
		rate_adders += GameState.idle_additive[resource_id]
	
	# Apply meta upgrade additive bonuses
	rate_adders += GameState.meta_effects_cache.get("idle_rate_add", 0.0)
	
	# Calculate effective rate
	var effective_rate: float = rate_adders * multiplier_factors
	
	# Apply global player stat multiplier
	effective_rate *= GameState.player_stats.idle_rate_multiplier
	
	# Apply item idle multiplier
	effective_rate *= GameState.idle_multiplier_extra
	
	# Apply meta upgrade multiplier
	effective_rate *= (1.0 + GameState.meta_effects_cache.get("idle_rate_multiplier", 0.0))
	
	# Apply essence multiplier from prestige
	effective_rate *= PrestigeService.get_essence_multiplier()
	
	return effective_rate

func recalculate_all_rates() -> void:
	# Recalculate and cache all resource rates
	per_second_rates.clear()
	for resource_id in GameState.resources:
		per_second_rates[resource_id] = compute_resource_rate(resource_id)
	rates_updated.emit()

func apply_tick(delta: float) -> void:
	# Recalculate rates every tick
	recalculate_all_rates()
	
	# Apply resource generation for this tick
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		if resource.unlocked:
			var income: float = get_per_second_rate(resource_id) * delta
			GameState.add_resource_amount(resource_id, income)
			
			# Track lifetime_gold for prestige (only for gold, only positive)
			if resource_id == "gold" and income > 0:
				PrestigeService.update_lifetime_gold(income)

func purchase_upgrade(upgrade_id: String) -> bool:
	var upgrade: UpgradeModel = GameState.get_upgrade(upgrade_id)
	if not upgrade or not upgrade.unlocked:
		return false
	
	var cost: float = upgrade.get_current_cost()
	# Assume upgrades cost the primary resource (gold for now)
	# TODO: Support multi-resource costs
	if GameState.spend_resource("gold", cost):
		upgrade.level += 1
		# Note: upgrade_purchased signal moved to UpgradeService
		# Recalculate rates immediately after purchase
		recalculate_all_rates()
		return true
	
	return false

func calculate_prestige_essence(primary_resource_total: float) -> float:
	# essence_gain = floor( (total / threshold) ^ exponent )
	var ratio: float = primary_resource_total / Constants.PRESTIGE_THRESHOLD
	if ratio < 1.0:
		return 0.0
	return floor(pow(ratio, Constants.PRESTIGE_ESSENCE_EXPONENT))

func can_prestige() -> bool:
	# Check if player meets prestige requirements
	if GameState.resources.has("gold"):
		var gold_total: float = GameState.resources["gold"].amount
		return gold_total >= Constants.PRESTIGE_THRESHOLD
	return false

func perform_prestige() -> void:
	# TODO: Implement full prestige logic (deprecated - use PrestigeService)
	if can_prestige():
		var essence_gain: float = calculate_prestige_essence(GameState.resources["gold"].amount)
		GameState.essence += essence_gain
		GameState.reset_for_prestige()
		# Note: prestige_performed signal moved to PrestigeService
