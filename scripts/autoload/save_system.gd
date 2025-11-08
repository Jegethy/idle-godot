extends Node
## SaveSystem: Save/load game state with versioned schema
## 
## Handles JSON serialization/deserialization and schema migration.

func _ready() -> void:
	print("SaveSystem initialized")

func save_game() -> bool:
	var save_data := SaveSchemaModel.new()
	save_data.timestamp = Time.get_unix_time_from_system()
	
	# Serialize resources
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		save_data.resources[resource_id] = resource.to_dict()
	
	# Serialize upgrades
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		save_data.upgrades[upgrade_id] = upgrade.to_dict()
	
	# Serialize items
	for item in GameState.items:
		save_data.inventory.append(item.to_dict())
	
	# Serialize player stats
	save_data.player_stats = GameState.player_stats.to_dict()
	save_data.essence = GameState.essence
	
	# Write to file
	var file := FileAccess.open(Constants.SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string := JSON.stringify(save_data.to_dict(), "\t")
		file.store_string(json_string)
		file.close()
		print("Game saved successfully")
		return true
	else:
		push_error("Failed to save game: cannot open file")
		return false

func load_game() -> bool:
	if not FileAccess.file_exists(Constants.SAVE_FILE_PATH):
		print("No save file found")
		return false
	
	var file := FileAccess.open(Constants.SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to load game: cannot open file")
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save file JSON")
		return false
	
	var data: Dictionary = json.data
	var save_data := SaveSchemaModel.new()
	save_data.from_dict(data)
	
	# Handle schema migration
	if save_data.version < Constants.SAVE_VERSION:
		print("Migrating save from version %d to %d" % [save_data.version, Constants.SAVE_VERSION])
		save_data.migrate(save_data.version)
	
	# Calculate offline progression
	var offline_data := TimeService.calculate_offline_progression(save_data.timestamp)
	
	# Load resources
	for resource_id in save_data.resources:
		if GameState.resources.has(resource_id):
			GameState.resources[resource_id].from_dict(save_data.resources[resource_id])
	
	# Load upgrades
	for upgrade_id in save_data.upgrades:
		if GameState.upgrades.has(upgrade_id):
			GameState.upgrades[upgrade_id].from_dict(save_data.upgrades[upgrade_id])
	
	# Load items
	# TODO: Deserialize items properly
	
	# Load player stats
	GameState.player_stats.from_dict(save_data.player_stats)
	GameState.essence = save_data.essence
	
	# Apply offline gains
	TimeService.apply_offline_gains(offline_data)
	
	print("Game loaded successfully")
	return true

func delete_save() -> void:
	if FileAccess.file_exists(Constants.SAVE_FILE_PATH):
		DirAccess.remove_absolute(Constants.SAVE_FILE_PATH)
		print("Save file deleted")
