extends Node
## TimeService: Tick/update loop and offline progression
## 
## Manages the game's time-based updates and calculates
## offline progression when the player returns.

var last_tick_time: float = 0.0
var accumulated_time: float = 0.0

func _ready() -> void:
	last_tick_time = Time.get_unix_time_from_system()
	print("TimeService initialized")

func _process(delta: float) -> void:
	accumulated_time += delta
	
	# Tick at configured rate
	if accumulated_time >= Constants.IDLE_TICK_RATE:
		_tick(accumulated_time)
		accumulated_time = 0.0

func _tick(delta: float) -> void:
	# Perform game tick
	Economy.apply_tick(delta)
	last_tick_time = Time.get_unix_time_from_system()

func apply_offline_progression(now: float, economy: Node, game_state: Node) -> void:
	# Get last saved time from SaveSystem
	var last_saved := SaveSystem.last_saved_time
	if last_saved == 0.0:
		# No previous save or first run, no offline progression
		return
	
	# Calculate delta with clock skew protection
	var delta_seconds: float = now - last_saved
	if delta_seconds < 0:
		# Clock skew detected, reset to now
		push_warning("Clock skew detected (negative delta). Resetting last_saved_time.")
		delta_seconds = 0.0
	
	# Apply hard cap
	delta_seconds = clamp(delta_seconds, 0, Constants.OFFLINE_HARD_CAP_SEC)
	
	# Apply meta upgrade offline gain multiplier
	var offline_mult := 1.0 + game_state.meta_effects_cache.get("offline_gain_multiplier", 0.0)
	
	if delta_seconds > 0:
		# Recompute rates using current upgrades (already loaded)
		economy.recalculate_all_rates()
		
		# Apply offline gains for each resource
		for resource_id in game_state.resources:
			var resource: ResourceModel = game_state.resources[resource_id]
			if resource.unlocked:
				var per_second_rate: float = economy.get_per_second_rate(resource_id)
				var gain: float = per_second_rate * delta_seconds * offline_mult
				game_state.add_resource_amount(resource_id, gain)
				
				# Track lifetime_gold for prestige (only for gold, only positive)
				if resource_id == "gold" and gain > 0:
					PrestigeService.update_lifetime_gold(gain)
		
		var hours: float = delta_seconds / 3600.0
		print("Applied offline progression for %.2f hours (capped at %.1f hours)" % [hours, Constants.OFFLINE_HARD_CAP_SEC / 3600.0])

func calculate_offline_progression(last_saved_time: float) -> Dictionary:
	var current_time: float = Time.get_unix_time_from_system()
	var delta_seconds: float = current_time - last_saved_time
	
	# Cap offline time
	delta_seconds = min(delta_seconds, Constants.MAX_OFFLINE_SECONDS)
	
	# Calculate what would have been earned
	var offline_gains: Dictionary = {}
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		if resource.unlocked:
			var income: float = Economy.calculate_income_per_second(resource) * delta_seconds
			# Apply diminishing returns for very long offline times
			if delta_seconds > 3600.0:  # More than 1 hour
				var diminish_factor: float = 1.0 - (delta_seconds - 3600.0) / Constants.MAX_OFFLINE_SECONDS * 0.3
				income *= max(0.7, diminish_factor)
			offline_gains[resource_id] = income
	
	return {
		"delta_seconds": delta_seconds,
		"gains": offline_gains
	}

func apply_offline_gains(offline_data: Dictionary) -> void:
	var gains: Dictionary = offline_data.get("gains", {})
	for resource_id in gains:
		GameState.add_resource_amount(resource_id, gains[resource_id])
	
	var hours: float = offline_data.get("delta_seconds", 0.0) / 3600.0
	print("Applied offline gains for %.2f hours" % hours)
