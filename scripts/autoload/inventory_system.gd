extends Node
## InventorySystem: Item management and equipment
## 
## Handles item CRUD, equipping/unequipping, stat modifiers, and item database.

signal item_added(instance_id: String)
signal item_equipped(slot: String, instance_id: String)
signal item_unequipped(slot: String, instance_id: String)
signal inventory_changed()

# Item database loaded from items.json
var item_definitions: Dictionary = {}  # {id: Dictionary} - raw item data

func _ready() -> void:
	_load_item_definitions()
	print("InventorySystem initialized with %d item definitions" % item_definitions.size())

func _load_item_definitions() -> void:
	var file_path := "res://data/items.json"
	if not FileAccess.file_exists(file_path):
		push_error("Items data file not found: %s" % file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open items data file")
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse items JSON: %s" % json.get_error_message())
		return
	
	var data: Dictionary = json.data
	if not data.has("items"):
		push_error("Items JSON missing 'items' array")
		return
	
	var items_array: Array = data["items"]
	for item_data in items_array:
		if item_data is Dictionary:
			var item_id: String = item_data.get("id", "")
			if not item_id.is_empty():
				item_definitions[item_id] = item_data

## Add an item to inventory by ID or from definition
func add_item(item_id_or_def: Variant, quantity: int = 1) -> bool:
	var item_def: Dictionary
	
	# Handle both string ID and dictionary definition
	if item_id_or_def is String:
		if not item_definitions.has(item_id_or_def):
			push_error("Item definition not found: %s" % item_id_or_def)
			return false
		item_def = item_definitions[item_id_or_def]
	elif item_id_or_def is Dictionary:
		item_def = item_id_or_def
	else:
		push_error("Invalid item_id_or_def type")
		return false
	
	var item_id: String = item_def.get("id", "")
	var is_stackable: bool = item_def.get("stackable", false)
	
	# Check for stacking
	if is_stackable:
		# Find existing stack
		for item in GameState.items:
			if item.id == item_id and item.stackable:
				# Add to existing stack (capped at MAX_STACK)
				var new_quantity := mini(item.quantity + quantity, BalanceConstants.MAX_STACK)
				var added := new_quantity - item.quantity
				item.quantity = new_quantity
				if added > 0:
					inventory_changed.emit()
					item_added.emit(item.instance_id)
				return true
	
	# Create new item instance
	var item := ItemModel.new()
	item.from_dict(item_def)
	item.quantity = mini(quantity, BalanceConstants.MAX_STACK)
	item.instance_id = UUID.generate()
	
	GameState.items.append(item)
	inventory_changed.emit()
	item_added.emit(item.instance_id)
	GameState.item_acquired.emit(item_id, quantity)
	
	print("Item added: %s (x%d)" % [item.display_name, item.quantity])
	return true

## Remove an item from inventory by instance_id
func remove_item(instance_id: String, quantity: int = 1) -> bool:
	for i in range(GameState.items.size()):
		var item: ItemModel = GameState.items[i]
		if item.instance_id == instance_id:
			if item.stackable and item.quantity > quantity:
				# Reduce stack
				item.quantity -= quantity
				inventory_changed.emit()
				return true
			else:
				# Remove entire item
				GameState.items.remove_at(i)
				inventory_changed.emit()
				return true
	
	return false

## Equip an item by instance_id
func equip_item(instance_id: String) -> bool:
	# Find the item
	var item: ItemModel = null
	for inv_item in GameState.items:
		if inv_item.instance_id == instance_id:
			item = inv_item
			break
	
	if not item:
		push_error("Item not found: %s" % instance_id)
		return false
	
	# Check if slot is valid
	if item.slot == "consumable":
		push_error("Cannot equip consumable items")
		return false
	
	# Unequip current item in slot if any
	if GameState.equipped_slots.has(item.slot):
		unequip_slot(item.slot)
	
	# Equip the item
	GameState.equipped_slots[item.slot] = instance_id
	item_equipped.emit(item.slot, instance_id)
	
	# Recalculate modifiers
	recompute_all_modifiers()
	
	print("Item equipped: %s in slot %s" % [item.display_name, item.slot])
	return true

## Unequip an item from a slot
func unequip_slot(slot: String) -> bool:
	if not GameState.equipped_slots.has(slot):
		return false
	
	var instance_id: String = GameState.equipped_slots[slot]
	GameState.equipped_slots.erase(slot)
	item_unequipped.emit(slot, instance_id)
	
	# Recalculate modifiers
	recompute_all_modifiers()
	
	print("Item unequipped from slot: %s" % slot)
	return true

## Get equipped slots as dictionary of slot -> ItemModel
func get_equipped_slots() -> Dictionary:
	var result := {}
	for slot in GameState.equipped_slots:
		var instance_id: String = GameState.equipped_slots[slot]
		for item in GameState.items:
			if item.instance_id == instance_id:
				result[slot] = item
				break
	return result

## Get item by instance_id
func get_item_by_instance_id(instance_id: String) -> ItemModel:
	for item in GameState.items:
		if item.instance_id == instance_id:
			return item
	return null

## Recompute all modifiers from equipped items
func recompute_all_modifiers() -> void:
	# Reset all modifiers
	GameState.idle_additive.clear()
	GameState.idle_multiplier_extra = 1.0
	GameState.combat_modifiers = {
		"attack_add": 0.0,
		"attack_mult": 1.0,
		"defense_add": 0.0,
		"defense_mult": 1.0,
		"crit_chance_add": 0.0,
		"crit_multiplier_add": 0.0,
		"speed_add": 0.0
	}
	
	# Apply effects from all equipped items
	var equipped := get_equipped_slots()
	for slot in equipped:
		var item: ItemModel = equipped[slot]
		_apply_item_effects(item)
	
	# Apply caps
	GameState.combat_modifiers["attack_mult"] = minf(GameState.combat_modifiers["attack_mult"], BalanceConstants.ITEM_ATTACK_MULT_CAP)
	GameState.idle_multiplier_extra = minf(GameState.idle_multiplier_extra, BalanceConstants.ITEM_IDLE_MULT_CAP)
	
	GameState.modifiers_recomputed.emit()
	print("Modifiers recomputed: idle_mult=%.2f, attack_add=%.1f, attack_mult=%.2f" % [
		GameState.idle_multiplier_extra,
		GameState.combat_modifiers["attack_add"],
		GameState.combat_modifiers["attack_mult"]
	])

func _apply_item_effects(item: ItemModel) -> void:
	for effect in item.effects:
		var effect_type: String = effect.get("type", "")
		var value: float = effect.get("value", 0.0)
		
		match effect_type:
			Constants.EffectType.COMBAT_ATTACK_ADD:
				GameState.combat_modifiers["attack_add"] += value
			Constants.EffectType.COMBAT_DEFENSE_ADD:
				GameState.combat_modifiers["defense_add"] += value
			Constants.EffectType.COMBAT_ATTACK_MULT:
				GameState.combat_modifiers["attack_mult"] += value
			Constants.EffectType.COMBAT_DEFENSE_MULT:
				GameState.combat_modifiers["defense_mult"] += value
			Constants.EffectType.COMBAT_CRIT_CHANCE_ADD:
				GameState.combat_modifiers["crit_chance_add"] += value
			Constants.EffectType.COMBAT_CRIT_MULTIPLIER_ADD:
				GameState.combat_modifiers["crit_multiplier_add"] += value
			Constants.EffectType.COMBAT_SPEED_ADD:
				GameState.combat_modifiers["speed_add"] += value
			Constants.EffectType.IDLE_RATE_ADD:
				# Resource-specific or global additive
				var resource: String = effect.get("resource", "gold")
				if not GameState.idle_additive.has(resource):
					GameState.idle_additive[resource] = 0.0
				GameState.idle_additive[resource] += value
			Constants.EffectType.IDLE_RATE_MULTIPLIER:
				GameState.idle_multiplier_extra += value

## Get a human-readable description of an item's effects
func describe_item(item: ItemModel) -> String:
	var lines: Array[String] = []
	
	for effect in item.effects:
		var effect_type: String = effect.get("type", "")
		var value: float = effect.get("value", 0.0)
		
		match effect_type:
			Constants.EffectType.COMBAT_ATTACK_ADD:
				lines.append("+%.0f Attack" % value)
			Constants.EffectType.COMBAT_DEFENSE_ADD:
				lines.append("+%.0f Defense" % value)
			Constants.EffectType.COMBAT_ATTACK_MULT:
				lines.append("+%s Attack" % NumberFormatter.format_percentage(value))
			Constants.EffectType.COMBAT_DEFENSE_MULT:
				lines.append("+%s Defense" % NumberFormatter.format_percentage(value))
			Constants.EffectType.COMBAT_CRIT_CHANCE_ADD:
				lines.append("+%s Crit Chance" % NumberFormatter.format_percentage(value))
			Constants.EffectType.COMBAT_CRIT_MULTIPLIER_ADD:
				lines.append("+%s Crit Damage" % NumberFormatter.format_percentage(value))
			Constants.EffectType.COMBAT_SPEED_ADD:
				lines.append("+%s Combat Speed" % NumberFormatter.format_percentage(value))
			Constants.EffectType.IDLE_RATE_ADD:
				var resource: String = effect.get("resource", "gold")
				lines.append("+%.1f %s/sec" % [value, resource.capitalize()])
			Constants.EffectType.IDLE_RATE_MULTIPLIER:
				lines.append("+%s Idle Rate" % NumberFormatter.format_percentage(value))
	
	return "\n".join(lines)
