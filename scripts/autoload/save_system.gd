extends Node
## SaveSystem: Save/load game state with versioned schema
## 
## Handles JSON serialization/deserialization, schema migration,
## atomic writes, autosave, and backup management.

# Signals
signal save_completed(success: bool, path: String)

# Autosave timer
var autosave_timer: Timer
var last_saved_time: float = 0.0

func _ready() -> void:
	# Setup autosave timer
	autosave_timer = Timer.new()
	autosave_timer.wait_time = 30.0  # Autosave every 30 seconds
	autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	add_child(autosave_timer)
	autosave_timer.start()
	
	print("SaveSystem initialized with autosave every 30 seconds")

func _exit_tree() -> void:
	# Save on application exit
	save()

func _on_autosave_timer_timeout() -> void:
	save()

## Save the game state to disk with atomic write
func save() -> bool:
	return save_game()

## Load the game state from disk with migration
func load() -> bool:
	return load_game()

## Wipe save files and reset to defaults
func wipe(include_essence: bool = false) -> void:
	# Delete save files
	var save_path := Constants.SAVE_FILE_PATH
	var backup_path := save_path.replace(".json", ".bak")
	var temp_path := save_path + ".tmp"
	
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		print("Deleted save file")
	
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
		print("Deleted backup file")
	
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
		print("Deleted temp file")
	
	# Reset game state to defaults
	# Zero out resources
	for resource_id in GameState.resources:
		GameState.resources[resource_id].amount = 0.0
	
	# Reset upgrades to level 0
	for upgrade_id in GameState.upgrades:
		GameState.upgrades[upgrade_id].level = 0
	
	# Reset last_saved_time to now
	last_saved_time = Time.get_unix_time_from_system()
	
	# Reset other state
	if include_essence:
		GameState.essence = 0.0
		GameState.lifetime_gold = 0.0
		GameState.total_prestiges = 0
		GameState.essence_spent = 0.0
	GameState.items.clear()
	
	# Recalculate rates
	Economy.recalculate_all_rates()
	
	# Immediately save the clean state
	save()
	
	print("Save wiped and reset to defaults")

func save_game() -> bool:
	var save_data := SaveSchemaModel.new()
	var now := Time.get_unix_time_from_system()
	save_data.timestamp = now
	save_data.last_saved_time = now
	
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
	save_data.lifetime_gold = GameState.lifetime_gold
	save_data.total_prestiges = GameState.total_prestiges
	save_data.essence_spent = GameState.essence_spent
	save_data.prestige_settings = {"formula_version": BalanceConstants.PRESTIGE_FORMULA_VERSION}
	save_data.current_wave = GameState.current_wave
	save_data.lifetime_enemies_defeated = GameState.lifetime_enemies_defeated
	
	# Atomic write: write to .tmp, then rename
	var save_path := Constants.SAVE_FILE_PATH
	var temp_path := save_path + ".tmp"
	var backup_path := save_path.replace(".json", ".bak")
	
	# Write to temporary file
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save game: cannot open temp file")
		save_completed.emit(false, save_path)
		return false
	
	var json_string := JSON.stringify(save_data.to_dict(), "\t")
	file.store_string(json_string)
	file.close()
	
	# Get absolute paths for rename operations
	var abs_save_path := ProjectSettings.globalize_path(save_path)
	var abs_temp_path := ProjectSettings.globalize_path(temp_path)
	var abs_backup_path := ProjectSettings.globalize_path(backup_path)
	
	# Backup existing save file if it exists
	if FileAccess.file_exists(save_path):
		# Remove old backup if it exists
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		
		# Rename current save to backup
		var err := DirAccess.rename_absolute(abs_save_path, abs_backup_path)
		if err != OK:
			push_warning("Failed to create backup: %d" % err)
	
	# Rename temp to main save
	var err := DirAccess.rename_absolute(abs_temp_path, abs_save_path)
	if err != OK:
		push_error("Failed to rename temp file to save file: %d" % err)
		save_completed.emit(false, save_path)
		return false
	
	last_saved_time = now
	save_completed.emit(true, save_path)
	print("Game saved successfully (atomic write)")
	return true

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
	GameState.lifetime_gold = save_data.lifetime_gold
	GameState.total_prestiges = save_data.total_prestiges
	GameState.essence_spent = save_data.essence_spent
	GameState.current_wave = save_data.current_wave
	GameState.lifetime_enemies_defeated = save_data.lifetime_enemies_defeated
	
	# Store last_saved_time for offline progression and UI display
	last_saved_time = save_data.last_saved_time
	
	# Recalculate rates after loading upgrades
	Economy.recalculate_all_rates()
	
	# Apply offline progression using new method
	var now := Time.get_unix_time_from_system()
	TimeService.apply_offline_progression(now, Economy, GameState)
	
	print("Game loaded successfully")
	return true

func delete_save() -> void:
	if FileAccess.file_exists(Constants.SAVE_FILE_PATH):
		DirAccess.remove_absolute(Constants.SAVE_FILE_PATH)
		print("Save file deleted")
