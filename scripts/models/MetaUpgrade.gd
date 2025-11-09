extends RefCounted
## MetaUpgrade: Permanent meta progression upgrade model
## 
## Represents a single meta upgrade purchasable with essence.
## Supports tiered progression, cost curves, and effect stacking.

class_name MetaUpgrade

# Upgrade identification
var id: String = ""
var name: String = ""
var category: String = ""

# Progression
var max_level: int = 0
var current_level: int = 0

# Cost calculation
var base_cost: float = 0.0
var cost_curve: String = "EXPONENTIAL"  # EXPONENTIAL | LINEAR | POLY
var growth: float = 1.15
var poly_coeffs: Array[float] = []

# Effect
var effect_type: String = ""
var effect_per_level: float = 0.0

# Prerequisites
var prerequisites: Array[String] = []  # Format: "id:level"
var requires_total_prestiges: int = 0

func _init(
	p_id: String = "",
	p_name: String = "",
	p_category: String = "",
	p_max_level: int = 0,
	p_base_cost: float = 0.0,
	p_cost_curve: String = "EXPONENTIAL",
	p_effect_type: String = "",
	p_effect_per_level: float = 0.0
) -> void:
	id = p_id
	name = p_name
	category = p_category
	max_level = p_max_level
	base_cost = p_base_cost
	cost_curve = p_cost_curve
	effect_type = p_effect_type
	effect_per_level = p_effect_per_level

## Calculate cost for the next level (level_to_buy = current_level + 1)
func cost(level: int) -> float:
	if level >= max_level:
		return INF
	
	match cost_curve:
		"EXPONENTIAL":
			return base_cost * pow(growth, level)
		"LINEAR":
			# Linear growth: base_cost + (base_cost * 0.25 * level)
			return base_cost * (1.0 + 0.25 * level)
		"POLY":
			# Polynomial: coeffs[0] + coeffs[1] * level
			if poly_coeffs.size() >= 2:
				return poly_coeffs[0] + poly_coeffs[1] * level
			else:
				# Fallback to linear
				return base_cost * (1.0 + 0.25 * level)
		_:
			# Default to exponential
			return base_cost * pow(growth, level)

## Get cost for next level from current_level
func get_next_cost() -> float:
	return cost(current_level)

## Calculate cumulative effect at given level
func cumulative_effect(level: int) -> float:
	return level * effect_per_level

## Get current cumulative effect
func get_current_effect() -> float:
	return cumulative_effect(current_level)

## Get effect gained from next level
func get_next_level_effect() -> float:
	return effect_per_level

## Check if at max level
func is_maxed() -> bool:
	return current_level >= max_level

## Serialize to dictionary
func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"category": category,
		"max_level": max_level,
		"current_level": current_level,
		"base_cost": base_cost,
		"cost_curve": cost_curve,
		"growth": growth,
		"poly_coeffs": poly_coeffs,
		"effect_type": effect_type,
		"effect_per_level": effect_per_level,
		"prerequisites": prerequisites,
		"requires_total_prestiges": requires_total_prestiges
	}

## Deserialize from dictionary
func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	name = data.get("name", "")
	category = data.get("category", "")
	max_level = data.get("max_level", 0)
	current_level = data.get("current_level", 0)
	base_cost = data.get("base_cost", 0.0)
	cost_curve = data.get("cost_curve", "EXPONENTIAL")
	growth = data.get("growth", 1.15)
	
	# Handle poly_coeffs (may be Array or PackedFloat32Array)
	var coeffs_raw = data.get("poly_coeffs", [])
	poly_coeffs.clear()
	if coeffs_raw is Array:
		for val in coeffs_raw:
			poly_coeffs.append(float(val))
	
	effect_type = data.get("effect_type", "")
	effect_per_level = data.get("effect_per_level", 0.0)
	
	# Handle prerequisites
	var prereqs_raw = data.get("prerequisites", [])
	prerequisites.clear()
	if prereqs_raw is Array:
		for val in prereqs_raw:
			prerequisites.append(str(val))
	
	requires_total_prestiges = data.get("requires_total_prestiges", 0)
