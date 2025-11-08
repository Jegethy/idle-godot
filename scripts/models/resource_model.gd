extends RefCounted
## Resource: Represents a game resource (e.g., gold, wood, mana)
## 
## Tracks amount, base generation rate, and modifiers.

class_name ResourceModel

var id: String = ""
var display_name: String = ""
var amount: float = 0.0
var base_rate: float = 0.0
var modifiers: Array[float] = []
var unlocked: bool = false

func _init(p_id: String = "", p_display_name: String = "", p_base_rate: float = 0.0, p_unlocked: bool = true) -> void:
	id = p_id
	display_name = p_display_name
	base_rate = p_base_rate
	unlocked = p_unlocked

func get_total_rate() -> float:
	var total: float = base_rate
	for modifier in modifiers:
		total += modifier
	return total

func add_modifier(value: float) -> void:
	modifiers.append(value)

func clear_modifiers() -> void:
	modifiers.clear()

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"amount": amount,
		"base_rate": base_rate,
		"unlocked": unlocked
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	amount = data.get("amount", 0.0)
	base_rate = data.get("base_rate", 0.0)
	unlocked = data.get("unlocked", false)
