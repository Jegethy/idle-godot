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

# Affix system (PR8)
var base_id: String = ""  # Original template id (before affixes)
var affixes: Array[Dictionary] = []  # [{id: String, category: String, rolled_effects: [{type: String, value: float}]}]
var reroll_count: int = 0  # Number of times affixes have been rerolled

# Cached computed effects (invalidated on reroll)
var _cached_total_effects: Array[Dictionary] = []
var _cache_valid: bool = false

func _init(
	p_id: String = "",
	p_display_name: String = "",
	p_rarity: String = "common",
	p_slot: String = "weapon"
) -> void:
	id = p_id
	base_id = p_id  # Initialize base_id to same as id
	display_name = p_display_name
	rarity = p_rarity
	slot = p_slot
	instance_id = UUID.generate()

func add_effect(effect_type: String, value: float) -> void:
	effects.append({
		"type": effect_type,
		"value": value
	})
	_cache_valid = false  # Invalidate cache

## Compute total effects (base + affixes) with caching
func compute_total_effects() -> Array[Dictionary]:
	if _cache_valid:
		return _cached_total_effects
	
	# Start with base effects
	var total: Array[Dictionary] = []
	for effect in effects:
		total.append(effect.duplicate())
	
	# Add affix effects
	for affix in affixes:
		var rolled_effects: Array = affix.get("rolled_effects", [])
		for effect in rolled_effects:
			if effect is Dictionary:
				total.append(effect.duplicate())
	
	_cached_total_effects = total
	_cache_valid = true
	return total

## Invalidate the effects cache (call after reroll or affix changes)
func invalidate_cache() -> void:
	_cache_valid = false

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
		"instance_id": instance_id,
		"base_id": base_id,
		"affixes": affixes,
		"reroll_count": reroll_count
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
	base_id = data.get("base_id", id)  # Default to id if missing
	affixes = data.get("affixes", [])
	reroll_count = data.get("reroll_count", 0)
	_cache_valid = false  # Invalidate cache on load
