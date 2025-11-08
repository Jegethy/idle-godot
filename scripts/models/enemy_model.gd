extends RefCounted
## Enemy: Represents a combat enemy with stats and drop tables
## 
## Used in combat system to spawn waves and generate rewards.

class_name EnemyModel

var id: String = ""
var display_name: String = ""
var hp: float = 100.0
var attack: float = 10.0
var defense: float = 5.0
var reward_table: Array[Dictionary] = []  # [{item_id: String, chance: float}]
var difficulty_tier: int = 1

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_hp: float = 100.0,
	p_attack: float = 10.0,
	p_defense: float = 5.0,
	p_tier: int = 1
) -> void:
	id = p_id
	display_name = p_display_name
	hp = p_hp
	attack = p_attack
	defense = p_defense
	difficulty_tier = p_tier

func add_reward(item_id: String, chance: float) -> void:
	reward_table.append({
		"item_id": item_id,
		"chance": chance
	})

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"hp": hp,
		"attack": attack,
		"defense": defense,
		"reward_table": reward_table,
		"difficulty_tier": difficulty_tier
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	hp = data.get("hp", 100.0)
	attack = data.get("attack", 10.0)
	defense = data.get("defense", 5.0)
	reward_table = data.get("reward_table", [])
	difficulty_tier = data.get("difficulty_tier", 1)
