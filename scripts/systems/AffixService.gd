extends Node
## AffixService: Procedural generation of item affixes
## 
## Handles affix rolling, effect computation, and item instance generation.

class_name AffixServiceClass

# Loaded data
var affix_definitions: Dictionary = {}  # {id: Dictionary}
var prefix_pool: Array[Dictionary] = []
var suffix_pool: Array[Dictionary] = []
var loot_weights: Dictionary = {}

func _ready() -> void:
	_load_affix_definitions()
	_load_loot_weights()
	print("AffixService initialized with %d affixes" % affix_definitions.size())

func _load_affix_definitions() -> void:
	var file_path := "res://data/affixes.json"
	if not FileAccess.file_exists(file_path):
		push_error("Affixes data file not found: %s" % file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open affixes data file")
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse affixes JSON: %s" % json.get_error_message())
		return
	
	var data: Dictionary = json.data
	if not data.has("affixes"):
		push_error("Affixes JSON missing 'affixes' array")
		return
	
	var affixes_array: Array = data["affixes"]
	for affix_data in affixes_array:
		if affix_data is Dictionary:
			var affix_id: String = affix_data.get("id", "")
			if not affix_id.is_empty():
				affix_definitions[affix_id] = affix_data
				
				# Add to category pools
				var category: String = affix_data.get("category", "")
				if category == "prefix":
					prefix_pool.append(affix_data)
				elif category == "suffix":
					suffix_pool.append(affix_data)

func _load_loot_weights() -> void:
	var file_path := "res://data/loot_weights.json"
	if not FileAccess.file_exists(file_path):
		push_error("Loot weights data file not found: %s" % file_path)
		return
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open loot weights data file")
		return
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse loot weights JSON: %s" % json.get_error_message())
		return
	
	loot_weights = json.data

## Get affix pool by category
func get_affix_pool(category: String) -> Array[Dictionary]:
	if category == "prefix":
		return prefix_pool
	elif category == "suffix":
		return suffix_pool
	return []

## Compute effect value with rarity and wave scaling
func compute_effect_value(effect_def: Dictionary, rarity: String, wave_index: int) -> float:
	var base: float = effect_def.get("base", 0.0)
	var per_wave_factor: float = effect_def.get("per_wave_factor", 0.0)
	
	# Apply wave scaling cap
	var capped_wave: int = mini(wave_index, BalanceConstants.AFFIX_WAVE_SCALING_CAP)
	
	# Get rarity scaling (default to 1.0 if not found)
	# This should be on the affix definition, not the effect
	var rarity_scaling: float = 1.0
	
	# Wave scaling
	var wave_mult: float = 1.0 + (per_wave_factor * capped_wave)
	
	return base * rarity_scaling * wave_mult

## Roll affixes for an item
## Returns: Array of affix data [{id, category, rolled_effects}]
func roll_affixes(base_item_def: Dictionary, rarity: String, wave_index: int, rng_service: RNGServiceClass) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	
	# Get max affixes for this rarity
	var max_affixes_data: Dictionary = loot_weights.get("max_affixes_per_rarity", {})
	var max_affixes: int = max_affixes_data.get(rarity, 1)
	
	# Get roll chances
	var affix_roll_chance: Dictionary = loot_weights.get("affix_roll_chance", {})
	var prefix_chance_data: Dictionary = affix_roll_chance.get("prefix", {})
	var suffix_chance_data: Dictionary = affix_roll_chance.get("suffix", {})
	
	var prefix_chance: float = prefix_chance_data.get(rarity, 0.0)
	var suffix_chance: float = suffix_chance_data.get(rarity, 0.0)
	
	# Roll prefix
	if rng_service.chance(prefix_chance) and prefix_pool.size() > 0:
		var affix := _roll_single_affix("prefix", rarity, wave_index, rng_service)
		if not affix.is_empty():
			result.append(affix)
	
	# Roll suffix if we haven't hit max
	if result.size() < max_affixes and rng_service.chance(suffix_chance) and suffix_pool.size() > 0:
		var affix := _roll_single_affix("suffix", rarity, wave_index, rng_service)
		if not affix.is_empty():
			result.append(affix)
	
	# For rare+ items, try to roll additional affixes up to max
	if rarity in ["rare", "epic", "legendary"]:
		while result.size() < max_affixes:
			# Try prefix or suffix randomly
			var category := "prefix" if rng_service.randf() < 0.5 else "suffix"
			var pool := get_affix_pool(category)
			
			if pool.size() == 0:
				break
			
			# Check if we already have this category
			var has_category := false
			for existing in result:
				if existing.get("category", "") == category:
					has_category = true
					break
			
			# For legendary, allow multiple of same category
			if has_category and rarity != "legendary":
				continue
			
			var affix := _roll_single_affix(category, rarity, wave_index, rng_service)
			if not affix.is_empty():
				result.append(affix)
			else:
				break
	
	return result

func _roll_single_affix(category: String, rarity: String, wave_index: int, rng_service: RNGServiceClass) -> Dictionary:
	var pool := get_affix_pool(category)
	if pool.size() == 0:
		return {}
	
	# Build weights array
	var weights: Array = []
	for affix_def in pool:
		weights.append(affix_def.get("weight", 1.0))
	
	# Select affix using weighted random
	var selected_index := rng_service.weighted_random(weights)
	var affix_def: Dictionary = pool[selected_index]
	
	# Compute rolled effects
	var rolled_effects: Array[Dictionary] = []
	var effects_array: Array = affix_def.get("effects", [])
	var rarity_scaling_data: Dictionary = affix_def.get("rarity_scaling", {})
	var rarity_mult: float = rarity_scaling_data.get(rarity, 1.0)
	
	for effect_def in effects_array:
		if effect_def is Dictionary:
			var base: float = effect_def.get("base", 0.0)
			var per_wave_factor: float = effect_def.get("per_wave_factor", 0.0)
			var capped_wave: int = mini(wave_index, BalanceConstants.AFFIX_WAVE_SCALING_CAP)
			var wave_mult: float = 1.0 + (per_wave_factor * capped_wave)
			var final_value: float = base * rarity_mult * wave_mult
			
			var rolled_effect := {
				"type": effect_def.get("type", ""),
				"value": final_value
			}
			
			# Add resource if present
			if effect_def.has("resource"):
				rolled_effect["resource"] = effect_def.get("resource")
			
			rolled_effects.append(rolled_effect)
	
	return {
		"id": affix_def.get("id", ""),
		"category": category,
		"rolled_effects": rolled_effects
	}

## Generate a complete item instance with affixes
func generate_item_instance(item_def: Dictionary, rarity: String, wave_index: int, rng_service: RNGServiceClass) -> ItemModel:
	var item := ItemModel.new()
	item.from_dict(item_def)
	
	# Override rarity if specified
	item.rarity = rarity
	
	# Set base_id
	item.base_id = item.id
	
	# Roll affixes
	item.affixes = roll_affixes(item_def, rarity, wave_index, rng_service)
	
	# Generate new instance_id
	item.instance_id = UUID.generate()
	
	# Invalidate cache
	item.invalidate_cache()
	
	return item

## Get rarity by weighted random
func roll_rarity(rng_service: RNGServiceClass, rarity_factor: float = 1.0) -> String:
	var rarity_weights_data: Dictionary = loot_weights.get("rarity_base_weights", {})
	
	# Build weights array with rarity factor adjustment
	var rarities: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]
	var weights: Array = []
	
	for rarity in rarities:
		var base_weight: float = rarity_weights_data.get(rarity, 0.0)
		# Apply rarity factor - higher rarities get boosted more
		var boost := 1.0
		if rarity == "uncommon":
			boost = 1.0 + (rarity_factor - 1.0) * 0.3
		elif rarity == "rare":
			boost = 1.0 + (rarity_factor - 1.0) * 0.6
		elif rarity == "epic":
			boost = 1.0 + (rarity_factor - 1.0) * 0.9
		elif rarity == "legendary":
			boost = 1.0 + (rarity_factor - 1.0) * 1.2
		
		weights.append(base_weight * boost)
	
	var selected_index := rng_service.weighted_random(weights)
	return rarities[selected_index]
