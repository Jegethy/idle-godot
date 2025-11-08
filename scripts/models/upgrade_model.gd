extends RefCounted
## Upgrade: Represents a purchasable upgrade that improves game progression
## 
## Can modify resource rates, player stats, or unlock new features.

class_name UpgradeModel

var id: String = ""
var display_name: String = ""
var description: String = ""
var target: String = ""  # resource_id or stat name
var level: int = 0
var base_cost: float = 10.0
var cost_scaling_type: Constants.CostScalingType = Constants.CostScalingType.EXPONENTIAL
var cost_growth_factor: float = 1.15
var effect_value: float = 1.0  # Effect per level
var unlocked: bool = false
var unlocked_condition: String = ""  # TODO: Define condition system

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_target: String = "",
	p_base_cost: float = 10.0,
	p_unlocked: bool = true
) -> void:
	id = p_id
	display_name = p_display_name
	target = p_target
	base_cost = p_base_cost
	unlocked = p_unlocked

func get_current_cost() -> float:
	match cost_scaling_type:
		Constants.CostScalingType.EXPONENTIAL:
			return base_cost * pow(cost_growth_factor, level)
		Constants.CostScalingType.QUADRATIC:
			return base_cost * (1.0 + level + level * level * 0.1)
		Constants.CostScalingType.LINEAR:
			return base_cost * (1.0 + level * 0.5)
		_:
			return base_cost

func to_dict() -> Dictionary:
	return {
		"id": id,
		"level": level,
		"unlocked": unlocked
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	level = data.get("level", 0)
	unlocked = data.get("unlocked", false)
