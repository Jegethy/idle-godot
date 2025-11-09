extends Node
## EnemyDatabase: Load and manage enemy definitions
## 
## Loads enemy data from JSON and provides scaled enemies based on wave index.

class_name EnemyDatabase

var enemies: Dictionary = {}  # {id: Dictionary} - base enemy definitions
var wave_config: Dictionary = {}

func _ready() -> void:
	load_enemies()
	load_wave_config()
	print("EnemyDatabase initialized with %d enemies" % enemies.size())

## Load enemy definitions from data file
func load_enemies() -> void:
	var file_path := "res://data/enemies.json"
	if not FileAccess.file_exists(file_path):
		push_error("Enemies data file not found: %s" % file_path)
		_create_fallback_enemies()
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open enemies data file")
		_create_fallback_enemies()
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse enemies JSON: %s" % json.get_error_message())
		_create_fallback_enemies()
		return
	
	var data: Dictionary = json.data
	if not data.has("enemies"):
		push_error("Enemies JSON missing 'enemies' array")
		_create_fallback_enemies()
		return
	
	var enemies_array: Array = data["enemies"]
	for enemy_data in enemies_array:
		if not enemy_data is Dictionary:
			continue
		var enemy_id: String = enemy_data.get("id", "")
		if enemy_id.is_empty():
			continue
		enemies[enemy_id] = enemy_data
	
	print("Loaded %d enemy definitions" % enemies.size())

## Load wave configuration from data file
func load_wave_config() -> void:
	var file_path := "res://data/wave_config.json"
	if not FileAccess.file_exists(file_path):
		push_error("Wave config file not found: %s" % file_path)
		_create_fallback_wave_config()
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open wave config file")
		_create_fallback_wave_config()
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse wave config JSON: %s" % json.get_error_message())
		_create_fallback_wave_config()
		return
	
	wave_config = json.data
	print("Loaded wave configuration")

## Get a scaled enemy based on wave index
## Returns a Dictionary with computed stats
func get_scaled_enemy(enemy_id: String, wave_index: int) -> Dictionary:
	if not enemies.has(enemy_id):
		push_error("Enemy ID not found: %s" % enemy_id)
		return {}
	
	var base_enemy: Dictionary = enemies[enemy_id]
	var scaling := wave_config.get("wave_scaling", {})
	
	var hp_growth := scaling.get("hp_growth_factor", 1.15)
	var attack_growth := scaling.get("attack_growth_factor", 1.10)
	var defense_growth := scaling.get("defense_growth_factor", 1.08)
	var gold_mult := scaling.get("gold_reward_multiplier_per_wave", 1.05)
	
	var scaled_enemy := {
		"id": enemy_id,
		"name": base_enemy.get("name", "Unknown"),
		"hp": base_enemy.get("base_hp", 100.0) * pow(hp_growth, wave_index),
		"max_hp": base_enemy.get("base_hp", 100.0) * pow(hp_growth, wave_index),
		"attack": base_enemy.get("base_attack", 10.0) * pow(attack_growth, wave_index),
		"defense": base_enemy.get("base_defense", 5.0) * pow(defense_growth, wave_index),
		"gold_reward": base_enemy.get("base_gold_reward", 10.0) * pow(gold_mult, wave_index),
		"rarity_factor": base_enemy.get("rarity_factor", 1.0),
		"drop_table": base_enemy.get("drop_table", [])
	}
	
	return scaled_enemy

## Apply elite multipliers to an enemy
func apply_elite_multipliers(enemy: Dictionary) -> Dictionary:
	var elite_enemy := enemy.duplicate(true)
	elite_enemy["hp"] *= BalanceConstants.ELITE_HP_MULTIPLIER
	elite_enemy["max_hp"] *= BalanceConstants.ELITE_HP_MULTIPLIER
	elite_enemy["attack"] *= BalanceConstants.ELITE_ATTACK_MULTIPLIER
	elite_enemy["name"] = "Elite " + elite_enemy["name"]
	elite_enemy["is_elite"] = true
	return elite_enemy

## Apply boss multipliers to an enemy (or use boss_core)
func apply_boss_multipliers(enemy: Dictionary) -> Dictionary:
	var boss_enemy := enemy.duplicate(true)
	boss_enemy["hp"] *= BalanceConstants.BOSS_HP_MULTIPLIER
	boss_enemy["max_hp"] *= BalanceConstants.BOSS_HP_MULTIPLIER
	boss_enemy["attack"] *= BalanceConstants.BOSS_ATTACK_MULTIPLIER
	boss_enemy["name"] = "Boss " + boss_enemy["name"]
	boss_enemy["is_boss"] = true
	return boss_enemy

## Get enemy rotation list from config
func get_enemy_rotation() -> Array:
	return wave_config.get("enemy_rotation", ["slime"])

## Get wave composition settings
func get_wave_composition() -> Dictionary:
	return wave_config.get("wave_composition", {})

func _create_fallback_enemies() -> void:
	enemies["slime"] = {
		"id": "slime",
		"name": "Slime",
		"base_hp": 50.0,
		"base_attack": 5.0,
		"base_defense": 2.0,
		"base_gold_reward": 10.0,
		"rarity_factor": 1.0,
		"drop_table": []
	}
	print("Created fallback enemies")

func _create_fallback_wave_config() -> void:
	wave_config = {
		"wave_scaling": {
			"hp_growth_factor": 1.15,
			"attack_growth_factor": 1.10,
			"defense_growth_factor": 1.08,
			"gold_reward_multiplier_per_wave": 1.05
		},
		"wave_composition": {
			"base_enemy_count": 3,
			"enemy_count_growth_per_wave": 0.2,
			"elite_every_n": 5,
			"boss_every_m": 10
		},
		"enemy_rotation": ["slime"]
	}
	print("Created fallback wave config")
