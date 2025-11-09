extends Node
## CombatService: Combat simulation and wave management
## 
## Manages wave-based combat with deterministic simulation,
## player vs enemy battles, and reward distribution.

# Signals
signal combat_started(wave_index: int, seed: int)
signal combat_event(event: Dictionary)
signal combat_finished(result: Dictionary)

# Combat state
var combat_active: bool = false
var current_wave_index: int = 0
var current_seed: int = 0
var current_enemies: Array[Dictionary] = []
var enemies_defeated: Array[Dictionary] = []

# Player combat state
var player_hp: float = 0.0
var player_max_hp: float = 0.0

# Simulation state
var elapsed_time: float = 0.0
var total_damage_dealt: float = 0.0
var total_damage_taken: float = 0.0
var tick_count: int = 0

# Attack timers (per enemy)
var enemy_attack_timers: Array[float] = []
var player_attack_timer: float = 0.0

func _ready() -> void:
	print("CombatService initialized")

## Start a new wave
func start_wave(wave_index: int, seed: int = -1) -> void:
	if combat_active:
		push_warning("Combat already active, cannot start new wave")
		return
	
	# Use provided seed or generate one
	if seed == -1:
		seed = Time.get_ticks_msec()
	
	current_wave_index = wave_index
	current_seed = seed
	
	# Set RNG seed for deterministic simulation
	var rng_service := get_node("/root/RNGService") as RNGServiceClass
	rng_service.set_seed(seed)
	
	# Generate wave enemies
	current_enemies = _generate_wave_enemies(wave_index)
	enemies_defeated.clear()
	
	# Initialize player combat stats
	_initialize_player_stats()
	
	# Reset timers and counters
	elapsed_time = 0.0
	total_damage_dealt = 0.0
	total_damage_taken = 0.0
	tick_count = 0
	
	# Initialize attack timers
	player_attack_timer = 0.0
	enemy_attack_timers.clear()
	for i in range(current_enemies.size()):
		enemy_attack_timers.append(0.0)
	
	combat_active = true
	combat_started.emit(wave_index, seed)
	
	print("Wave %d started with seed %d (%d enemies)" % [wave_index, seed, current_enemies.size()])

## Simulate one combat tick (0.5s by default)
func simulate_tick() -> bool:
	if not combat_active:
		return false
	
	var delta := BalanceConstants.COMBAT_TICK_SECONDS
	elapsed_time += delta
	tick_count += 1
	
	# Safety check: max ticks
	if tick_count >= BalanceConstants.MAX_SIM_TICKS:
		_end_combat_defeat("Combat exceeded maximum ticks")
		return false
	
	# Get player stats
	var player_stats := _get_player_combat_stats()
	
	# Process player attacks
	player_attack_timer += delta
	var player_attack_interval := 1.0 / player_stats.combat_speed
	
	while player_attack_timer >= player_attack_interval and current_enemies.size() > 0:
		player_attack_timer -= player_attack_interval
		_player_attack(player_stats)
	
	# Process enemy attacks
	for i in range(current_enemies.size()):
		var enemy := current_enemies[i]
		enemy_attack_timers[i] += delta
		
		var enemy_speed := enemy.get("combat_speed", 1.0)
		var enemy_attack_interval := 1.0 / enemy_speed
		
		while enemy_attack_timers[i] >= enemy_attack_interval:
			enemy_attack_timers[i] -= enemy_attack_interval
			_enemy_attack(enemy, player_stats)
	
	# Check win/loss conditions
	if player_hp <= 0.0:
		_end_combat_defeat("Player HP reached zero")
		return false
	
	if current_enemies.is_empty():
		_end_combat_victory()
		return false
	
	return true

## Fast simulate entire wave (auto-resolve)
func fast_simulate_wave(wave_index: int, seed: int = -1) -> Dictionary:
	start_wave(wave_index, seed)
	
	if not combat_active:
		return _create_summary(false, "Failed to start combat")
	
	# Simulate ticks until combat ends
	while combat_active and tick_count < BalanceConstants.MAX_SIM_TICKS:
		simulate_tick()
	
	# If still active, force defeat
	if combat_active:
		_end_combat_defeat("Fast simulation timeout")
	
	return _create_summary(enemies_defeated.size() > 0, "")

## Generate enemies for a wave
func _generate_wave_enemies(wave_index: int) -> Array[Dictionary]:
	var enemies: Array[Dictionary] = []
	
	var composition := EnemyDatabase.get_wave_composition()
	var base_count: int = composition.get("base_enemy_count", 3)
	var count_growth: float = composition.get("enemy_count_growth_per_wave", 0.2)
	var elite_every_n: int = composition.get("elite_every_n", 5)
	var boss_every_m: int = composition.get("boss_every_m", 10)
	
	# Calculate enemy count
	var enemy_count := int(base_count + wave_index * count_growth)
	enemy_count = max(enemy_count, 1)
	
	# Check if this is a boss wave
	if wave_index > 0 and wave_index % boss_every_m == 0:
		# Boss wave: single boss enemy
		var boss := EnemyDatabase.get_scaled_enemy("boss_core", wave_index)
		if not boss.is_empty():
			boss = EnemyDatabase.apply_boss_multipliers(boss)
			boss["combat_speed"] = 1.0
			enemies.append(boss)
		return enemies
	
	# Regular wave with possible elite
	var rotation := EnemyDatabase.get_enemy_rotation()
	var is_elite_wave := wave_index > 0 and wave_index % elite_every_n == 0
	
	for i in range(enemy_count):
		var enemy_id: String = rotation[i % rotation.size()]
		var enemy := EnemyDatabase.get_scaled_enemy(enemy_id, wave_index)
		
		if enemy.is_empty():
			continue
		
		# Make last enemy elite if this is an elite wave
		if is_elite_wave and i == enemy_count - 1:
			enemy = EnemyDatabase.apply_elite_multipliers(enemy)
		
		enemy["combat_speed"] = 1.0
		enemies.append(enemy)
	
	return enemies

## Initialize player combat stats
func _initialize_player_stats() -> void:
	var stats := _get_player_combat_stats()
	player_max_hp = BalanceConstants.BASE_PLAYER_HP * stats.essence_combat_bonus
	player_hp = player_max_hp

## Get player combat stats with essence bonuses
func _get_player_combat_stats() -> Dictionary:
	var essence := GameState.essence
	var essence_combat_bonus := 1.0 + BalanceConstants.COMBAT_ESSENCE_MULTIPLIER * sqrt(essence)
	
	# Apply meta upgrade combat modifiers
	var meta_attack_mult: float = 1.0 + float(GameState.meta_effects_cache.get(&"combat_attack_mult", 0.0))
	var meta_defense_mult: float = 1.0 + float(GameState.meta_effects_cache.get(&"combat_defense_mult", 0.0))
	var meta_crit_chance_add: float = float(GameState.meta_effects_cache.get(&"combat_crit_chance_add", 0.0))
	var meta_crit_mult_add: float = float(GameState.meta_effects_cache.get(&"combat_crit_multiplier_add", 0.0))
	var meta_speed_add: float = float(GameState.meta_effects_cache.get(&"combat_speed_add", 0.0))
	
	return {
		"attack": GameState.player_stats.attack * essence_combat_bonus * meta_attack_mult,
		"defense": GameState.player_stats.defense * essence_combat_bonus * meta_defense_mult,
		"crit_chance": GameState.player_stats.crit_chance + meta_crit_chance_add,
		"crit_multiplier": GameState.player_stats.crit_multiplier + meta_crit_mult_add,
		"combat_speed": GameState.player_stats.combat_speed + meta_speed_add,
		"essence_combat_bonus": essence_combat_bonus
	}

## Player attacks the first enemy
func _player_attack(player_stats: Dictionary) -> void:
	if current_enemies.is_empty():
		return
	
	var enemy := current_enemies[0]
	var base_damage := max(1.0, player_stats.attack - enemy.get("defense", 0.0))
	var rng_service := get_node("/root/RNGService") as RNGServiceClass
	var is_crit := rng_service.chance(player_stats.crit_chance)
	var damage := base_damage
	
	if is_crit:
		damage *= player_stats.crit_multiplier
	
	# Apply damage
	enemy["hp"] = enemy.get("hp", 0.0) - damage
	total_damage_dealt += damage
	
	# Log event
	var event := {
		"t": elapsed_time,
		"type": "hit",
		"attacker": "player",
		"target": enemy.get("name", "Enemy"),
		"damage": damage,
		"crit": is_crit,
		"enemy_hp_after": enemy.get("hp", 0.0)
	}
	combat_event.emit(event)
	
	# Check if enemy defeated
	if enemy.get("hp", 0.0) <= 0.0:
		_enemy_defeated(enemy)

## Enemy attacks the player
func _enemy_attack(enemy: Dictionary, player_stats: Dictionary) -> void:
	var base_damage := max(1.0, enemy.get("attack", 0.0) - player_stats.defense)
	var damage := base_damage
	
	# Apply damage
	player_hp -= damage
	total_damage_taken += damage
	
	# Log event
	var event := {
		"t": elapsed_time,
		"type": "hit",
		"attacker": enemy.get("name", "Enemy"),
		"target": "player",
		"damage": damage,
		"crit": false,
		"player_hp_after": player_hp
	}
	combat_event.emit(event)

## Handle enemy defeat
func _enemy_defeated(enemy: Dictionary) -> void:
	enemies_defeated.append(enemy)
	
	# Remove from active enemies
	var idx := current_enemies.find(enemy)
	if idx >= 0:
		current_enemies.remove_at(idx)
		enemy_attack_timers.remove_at(idx)
	
	# Update stats
	GameState.lifetime_enemies_defeated += 1
	
	# Log event
	var event := {
		"t": elapsed_time,
		"type": "defeated",
		"enemy": enemy.get("name", "Enemy")
	}
	combat_event.emit(event)

## End combat with victory
func _end_combat_victory() -> void:
	# Calculate rewards
	# Compute rewards using DropService (pass wave index for affix scaling)
	var drop_service := get_node("/root/DropService") as DropServiceClass
	var rng_service := get_node("/root/RNGService") as RNGServiceClass
	var rewards := drop_service.compute_rewards(enemies_defeated, rng_service, current_wave_index)
	
	# Apply rewards
	drop_service.apply_rewards(rewards)
	
	# Update wave progress
	GameState.current_wave = max(GameState.current_wave, current_wave_index + 1)
	
	# Create result summary
	var result := _create_summary(true, "")
	result["rewards"] = rewards
	
	combat_active = false
	combat_finished.emit(result)
	
	print("Combat victory! Wave %d completed" % current_wave_index)

## End combat with defeat
func _end_combat_defeat(reason: String) -> void:
	var result := _create_summary(false, reason)
	
	combat_active = false
	combat_finished.emit(result)
	
	print("Combat defeat: %s" % reason)

## Create result summary
func _create_summary(victory: bool, failure_reason: String) -> Dictionary:
	var dps := 0.0
	if elapsed_time > 0.0:
		dps = total_damage_dealt / elapsed_time
	
	return {
		"wave_index": current_wave_index,
		"seed": current_seed,
		"time": elapsed_time,
		"enemies_defeated": enemies_defeated.size(),
		"damage_dealt": total_damage_dealt,
		"damage_taken": total_damage_taken,
		"dps": dps,
		"victory": victory,
		"failure_reason": failure_reason
	}

