extends RefCounted
## PlayerStats: Player combat and idle progression stats
## 
## Modified by equipped items and upgrades.

class_name PlayerStatsModel

var attack: float = 10.0
var defense: float = 5.0
var crit_chance: float = 0.05
var crit_multiplier: float = 2.0
var idle_rate_multiplier: float = 1.0
var combat_speed: float = 1.0

func _init() -> void:
	pass

func apply_modifier(stat: Constants.StatModifier, op: String, value: float) -> void:
	match stat:
		Constants.StatModifier.ATTACK:
			attack = _apply_operation(attack, op, value)
		Constants.StatModifier.DEFENSE:
			defense = _apply_operation(defense, op, value)
		Constants.StatModifier.CRIT_CHANCE:
			crit_chance = _apply_operation(crit_chance, op, value)
		Constants.StatModifier.CRIT_MULTIPLIER:
			crit_multiplier = _apply_operation(crit_multiplier, op, value)
		Constants.StatModifier.IDLE_RATE_MULTIPLIER:
			idle_rate_multiplier = _apply_operation(idle_rate_multiplier, op, value)
		Constants.StatModifier.COMBAT_SPEED:
			combat_speed = _apply_operation(combat_speed, op, value)

func _apply_operation(base: float, op: String, value: float) -> float:
	match op:
		"add":
			return base + value
		"multiply":
			return base * value
		"set":
			return value
		_:
			return base

func to_dict() -> Dictionary:
	return {
		"attack": attack,
		"defense": defense,
		"crit_chance": crit_chance,
		"crit_multiplier": crit_multiplier,
		"idle_rate_multiplier": idle_rate_multiplier,
		"combat_speed": combat_speed
	}

func from_dict(data: Dictionary) -> void:
	attack = data.get("attack", 10.0)
	defense = data.get("defense", 5.0)
	crit_chance = data.get("crit_chance", 0.05)
	crit_multiplier = data.get("crit_multiplier", 2.0)
	idle_rate_multiplier = data.get("idle_rate_multiplier", 1.0)
	combat_speed = data.get("combat_speed", 1.0)
