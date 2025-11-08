extends RefCounted
## Item: Represents an inventory item with stats and effects
## 
## Items can be equipped to modify player stats or used as consumables.

class_name ItemModel

var id: String = ""
var display_name: String = ""
var description: String = ""
var rarity: Constants.ItemRarity = Constants.ItemRarity.COMMON
var slot: Constants.ItemSlot = Constants.ItemSlot.WEAPON
var effects: Array[Dictionary] = []  # [{stat: StatModifier, op: String, value: float}]
var stackable: bool = false
var quantity: int = 1

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_rarity: Constants.ItemRarity = Constants.ItemRarity.COMMON,
	p_slot: Constants.ItemSlot = Constants.ItemSlot.WEAPON
) -> void:
	id = p_id
	display_name = p_display_name
	rarity = p_rarity
	slot = p_slot

func add_effect(stat: Constants.StatModifier, op: String, value: float) -> void:
	effects.append({
		"stat": stat,
		"op": op,
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
		"quantity": quantity
	}

func from_dict(data: Dictionary) -> void:
	id = data.get("id", "")
	display_name = data.get("display_name", "")
	description = data.get("description", "")
	rarity = data.get("rarity", Constants.ItemRarity.COMMON)
	slot = data.get("slot", Constants.ItemSlot.WEAPON)
	effects = data.get("effects", [])
	stackable = data.get("stackable", false)
	quantity = data.get("quantity", 1)
