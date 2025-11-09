extends Node
## DropService: Calculate and distribute combat rewards
## 
## Handles item and gold drops from defeated enemies.

class_name DropService

## Compute rewards from defeated enemies
## enemies_defeated: Array of enemy Dictionaries
## wave_index: Current wave for affix scaling
## Returns: Dictionary with {gold: float, items: Array[ItemModel]}
func compute_rewards(enemies_defeated: Array, rng_service: RNGService, wave_index: int = 0) -> Dictionary:
	var total_gold := 0.0
	var items: Array[ItemModel] = []
	
	for enemy in enemies_defeated:
		if not enemy is Dictionary:
			continue
		
		# Add gold reward
		total_gold += enemy.get("gold_reward", 0.0)
		
		# Get enemy rarity factor for loot quality boost
		var rarity_factor: float = enemy.get("rarity_factor", 1.0)
		
		# Process drop table
		var drop_table: Array = enemy.get("drop_table", [])
		for drop_entry in drop_table:
			if not drop_entry is Dictionary:
				continue
			
			var chance: float = drop_entry.get("chance", 0.0)
			
			# Apply meta upgrade drop rate multiplier
			var drop_mult: float = 1.0 + float(GameState.meta_effects_cache.get(&"drop_rate_multiplier", 0.0))
			var adjusted_chance: float = min(1.0, chance * drop_mult)
			
			if rng_service.chance(adjusted_chance):
				var item_id: String = drop_entry.get("item_id", "")
				
				# Get item definition
				if not InventorySystem.item_definitions.has(item_id):
					continue
				
				var item_def: Dictionary = InventorySystem.item_definitions[item_id]
				
				# Skip stackable items (they don't get affixes)
				if item_def.get("stackable", false):
					var min_qty: int = drop_entry.get("min_qty", 1)
					var max_qty: int = drop_entry.get("max_qty", 1)
					var quantity: int = rng_service.rand_range(min_qty, max_qty)
					
					# Add directly without affixes
					for i in range(quantity):
						var item := ItemModel.new()
						item.from_dict(item_def)
						items.append(item)
					continue
				
				# Roll rarity with enemy rarity factor boost
				var rarity: String = AffixService.roll_rarity(rng_service, rarity_factor)
				
				# Generate item instance with affixes
				var item := AffixService.generate_item_instance(item_def, rarity, wave_index, rng_service)
				items.append(item)
	
	return {
		"gold": total_gold,
		"items": items
	}

## Apply rewards to game state
func apply_rewards(rewards: Dictionary) -> void:
	# Add gold
	var gold_amount: float = rewards.get("gold", 0.0)
	if gold_amount > 0.0:
		GameState.add_resource_amount("gold", gold_amount)
		
		# Update lifetime gold for prestige tracking
		GameState.lifetime_gold += gold_amount
	
	# Add items via InventorySystem
	var items: Array = rewards.get("items", [])
	for item in items:
		if item is ItemModel:
			# Add ItemModel instance directly
			GameState.items.append(item)
			InventorySystem.inventory_changed.emit()
			InventorySystem.item_added.emit(item.instance_id)
			GameState.item_acquired.emit(item.id, 1)
			print("Item added: %s (rarity: %s, affixes: %d)" % [item.display_name, item.rarity, item.affixes.size()])
		elif item is Dictionary:
			# Legacy path for simple item dictionaries
			var item_id: String = item.get("item_id", "")
			var quantity: int = item.get("quantity", 1)
			if not item_id.is_empty():
				InventorySystem.add_item(item_id, quantity)
