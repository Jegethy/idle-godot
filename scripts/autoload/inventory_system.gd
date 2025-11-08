extends Node
## InventorySystem: Item management and equipment
## 
## Handles item CRUD, equipping/unequipping, and stat modifiers.

signal item_equipped(item: ItemModel)
signal item_unequipped(item: ItemModel)

var equipped_items: Dictionary = {}  # {slot: ItemModel}

func _ready() -> void:
	print("InventorySystem initialized")

func add_item(item: ItemModel) -> void:
	# TODO: Handle stacking for stackable items
	GameState.items.append(item)
	GameState.item_acquired.emit(item.id, item.quantity)
	print("Item added: %s" % item.display_name)

func remove_item(item: ItemModel) -> bool:
	var index := GameState.items.find(item)
	if index >= 0:
		GameState.items.remove_at(index)
		return true
	return false

func equip_item(item: ItemModel) -> bool:
	# Check if slot is already occupied
	if equipped_items.has(item.slot):
		unequip_item(item.slot)
	
	equipped_items[item.slot] = item
	_apply_item_effects(item, true)
	item_equipped.emit(item)
	print("Item equipped: %s" % item.display_name)
	return true

func unequip_item(slot: Constants.ItemSlot) -> bool:
	if equipped_items.has(slot):
		var item: ItemModel = equipped_items[slot]
		_apply_item_effects(item, false)
		equipped_items.erase(slot)
		item_unequipped.emit(item)
		print("Item unequipped: %s" % item.display_name)
		return true
	return false

func _apply_item_effects(item: ItemModel, apply: bool) -> void:
	# Apply or remove item stat modifiers
	for effect in item.effects:
		var stat: Constants.StatModifier = effect.get("stat", Constants.StatModifier.ATTACK)
		var op: String = effect.get("op", "add")
		var value: float = effect.get("value", 0.0)
		
		# If removing effect, invert the operation
		if not apply:
			if op == "add":
				value = -value
			elif op == "multiply":
				value = 1.0 / value if value != 0.0 else 1.0
		
		GameState.player_stats.apply_modifier(stat, op, value)

func get_equipped_item(slot: Constants.ItemSlot) -> ItemModel:
	return equipped_items.get(slot, null)
