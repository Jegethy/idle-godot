extends Node
## AnalyticsWiring: Connects game signals to AnalyticsService
## 
## Centralizes all analytics event emission triggered by game events.
## Loaded as part of the main scene to wire up signals after autoloads are ready.

func _ready() -> void:
	# Wait one frame to ensure all autoloads are initialized
	await get_tree().process_frame
	
	_wire_game_state_signals()
	_wire_economy_signals()
	_wire_upgrade_signals()
	_wire_prestige_signals()
	_wire_combat_signals()
	_wire_inventory_signals()
	_wire_meta_upgrade_signals()
	_wire_save_signals()
	
	print("AnalyticsWiring: All signals connected")

## Wire GameState signals
func _wire_game_state_signals() -> void:
	if not GameState:
		return
	
	# Resource changed events
	GameState.resource_changed.connect(_on_resource_changed)

## Wire Economy signals
func _wire_economy_signals() -> void:
	if not Economy:
		return
	
	# Rates updated (throttled)
	Economy.rates_updated.connect(_on_rates_updated)

## Wire UpgradeService signals
func _wire_upgrade_signals() -> void:
	if not UpgradeService:
		return
	
	# Single upgrade purchase
	UpgradeService.upgrade_purchased.connect(_on_upgrade_purchased)
	
	# Bulk purchase
	UpgradeService.bulk_purchase_completed.connect(_on_bulk_purchase_completed)

## Wire PrestigeService signals
func _wire_prestige_signals() -> void:
	if not PrestigeService:
		return
	
	# Prestige performed
	PrestigeService.prestige_performed.connect(_on_prestige_performed)

## Wire CombatSystem signals
func _wire_combat_signals() -> void:
	if not CombatSystem:
		return
	
	# Combat started and finished
	CombatSystem.combat_started.connect(_on_combat_started)
	CombatSystem.combat_finished.connect(_on_combat_finished)

## Wire InventorySystem signals
func _wire_inventory_signals() -> void:
	if not InventorySystem:
		return
	
	# Item added and equipped
	InventorySystem.item_added.connect(_on_item_added)
	InventorySystem.item_equipped.connect(_on_item_equipped)

## Wire MetaUpgradeService signals
func _wire_meta_upgrade_signals() -> void:
	if not MetaUpgradeService:
		return
	
	# Meta upgrade leveled
	MetaUpgradeService.meta_upgrade_leveled.connect(_on_meta_upgrade_leveled)

## Wire SaveSystem signals
func _wire_save_signals() -> void:
	# SaveSystem doesn't have a save_completed signal in the original code
	# We could add one, but for now we'll skip this
	pass

## Signal handlers

func _on_resource_changed(resource_id: String, new_amount: float) -> void:
	# Calculate delta (we don't have the old amount, so use 0 as placeholder)
	var delta := 0.0  # This would need to be tracked separately for accurate deltas
	
	AnalyticsService.emit_event("economy.resource_changed", {
		"id": resource_id,
		"amount": new_amount,
		"delta": delta
	})

func _on_rates_updated() -> void:
	# Get current rates from Economy
	var rates := Economy.per_second_rates.duplicate()
	
	AnalyticsService.emit_event("economy.rates_updated", {
		"per_second_rates": rates
	})

func _on_upgrade_purchased(upgrade_id: String, new_level: int) -> void:
	var upgrade = GameState.get_upgrade(upgrade_id)
	var cost := upgrade.get_current_cost() if upgrade else 0.0
	
	AnalyticsService.emit_event("upgrade.purchased", {
		"id": upgrade_id,
		"level": new_level,
		"cost": cost
	})

func _on_bulk_purchase_completed(upgrade_id: String, levels_purchased: int) -> void:
	var upgrade = GameState.get_upgrade(upgrade_id)
	var new_level: int = upgrade.level if upgrade else 0
	var cost: float = UpgradeService.compute_bulk_cost(upgrade_id, levels_purchased)
	
	AnalyticsService.emit_event("upgrades.bulk_purchased", {
		"ids": [upgrade_id],  # Array for consistency with schema
		"levels": [new_level],
		"cost_total": cost
	})

func _on_prestige_performed(gained: int, total_essence: float, total_prestiges: int) -> void:
	AnalyticsService.emit_event("prestige.performed", {
		"gained": gained,
		"total_essence": total_essence,
		"total_prestiges": total_prestiges
	})

func _on_combat_started(wave_index: int, seed: int) -> void:
	AnalyticsService.emit_event("combat.started", {
		"wave": wave_index,
		"seed": seed
	})

func _on_combat_finished(result: Dictionary) -> void:
	var gold_gained := 0.0
	var items_count := 0
	
	# Extract rewards if available
	if result.has("rewards"):
		var rewards = result["rewards"]
		gold_gained = rewards.get("gold", 0.0)
		if rewards.has("items"):
			items_count = rewards["items"].size()
	
	AnalyticsService.emit_event("combat.finished", {
		"wave": result.get("wave_index", 0),
		"victory": result.get("victory", false),
		"time": result.get("time", 0.0),
		"enemies_defeated": result.get("enemies_defeated", 0),
		"gold_gained": gold_gained,
		"items": items_count
	})

func _on_item_added(instance_id: String) -> void:
	# Find the item in inventory
	var item: ItemModel = null
	for inv_item in GameState.items:
		if inv_item.instance_id == instance_id:
			item = inv_item
			break
	
	if not item:
		return
	
	AnalyticsService.emit_event("inventory.item_acquired", {
		"id": item.id,
		"qty": item.quantity,
		"rarity": item.rarity
	})

func _on_item_equipped(slot: String, instance_id: String) -> void:
	# Find the item in inventory
	var item: ItemModel = null
	for inv_item in GameState.items:
		if inv_item.instance_id == instance_id:
			item = inv_item
			break
	
	if not item:
		return
	
	AnalyticsService.emit_event("inventory.item_equipped", {
		"slot": slot,
		"id": item.id,
		"rarity": item.rarity
	})

func _on_meta_upgrade_leveled(id: StringName, new_level: int) -> void:
	var upgrade = MetaUpgradeService.get_upgrade(str(id))
	var cost: float = upgrade.get_cost_at_level(new_level - 1) if upgrade else 0.0
	
	AnalyticsService.emit_event("meta.level_up", {
		"id": str(id),
		"new_level": new_level,
		"cost": cost
	})
