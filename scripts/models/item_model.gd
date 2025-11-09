extends RefCounted
## Item: Represents an inventory item with stats and effects
## 
## Items can be equipped to modify player stats or used as consumables.

class_name ItemModel

var id: String = ""
var display_name: String = ""
var description: String = ""
var rarity: String = "common"  # Use string for JSON compatibility
var slot: String = "weapon"  # Use string for JSON compatibility
var effects: Array[Dictionary] = []  # [{type: String, value: float}]
var stackable: bool = false
var quantity: int = 1
var instance_id: String = ""  # Unique identifier for this instance

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_rarity: String = "common",
	p_slot: String = "weapon"
) -> void:
	id = p_id
	display_name = p_display_name
	rarity = p_rarity
	slot = p_slot
	instance_id = UUID.generate()

func add_effect(effect_type: String, value: float) -> void:
	effects.append({
		"type": effect_type,
		"value": value
	})

func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"description": description,
		"rarity": rarity,
		"slot": slot,
		"effects": effects,
		"stackable": stackable,
		"quantity": quantity,
		"instance_id": instance_id
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	description = data.get("description", "")
	rarity = data.get("rarity", "common")
	slot = data.get("slot", "weapon")
	effects = data.get("effects", [])
	stackable = data.get("stackable", false)
	quantity = data.get("quantity", 1)
	instance_id = data.get("instance_id", UUID.generate())
