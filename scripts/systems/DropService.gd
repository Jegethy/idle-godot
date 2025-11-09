extends Node
## DropService: Calculate and distribute combat rewards
## 
## Handles item and gold drops from defeated enemies.

class_name DropService

## Compute rewards from defeated enemies
## enemies_defeated: Array of enemy Dictionaries
## Returns: Dictionary with {gold: float, items: Array[Dictionary]}
func compute_rewards(enemies_defeated: Array, rng_service: RNGService) -> Dictionary:
	var total_gold := 0.0
	var items: Array[Dictionary] = []
	
	for enemy in enemies_defeated:
		if not enemy is Dictionary:
			continue
		
		# Add gold reward
		total_gold += enemy.get("gold_reward", 0.0)
		
		# Process drop table
		var drop_table: Array = enemy.get("drop_table", [])
		for drop_entry in drop_table:
			if not drop_entry is Dictionary:
				continue
			
			var chance: float = drop_entry.get("chance", 0.0)
			if rng_service.chance(chance):
				var item_id: String = drop_entry.get("item_id", "")
				var min_qty: int = drop_entry.get("min_qty", 1)
				var max_qty: int = drop_entry.get("max_qty", 1)
				var quantity: int = rng_service.rand_range(min_qty, max_qty)
				
				# Check if we already have this item in the list
				var found := false
				for item in items:
					if item.get("item_id", "") == item_id:
						item["quantity"] = item.get("quantity", 0) + quantity
						found = true
						break
				
				if not found:
					items.append({
						"item_id": item_id,
						"quantity": quantity
					})
	
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
	for item_dict in items:
		if not item_dict is Dictionary:
			continue
		var item_id: String = item_dict.get("item_id", "")
		var quantity: int = item_dict.get("quantity", 1)
		
		# Add item to inventory using InventorySystem
		if not item_id.is_empty():
			InventorySystem.add_item(item_id, quantity)
