extends RefCounted
## SaveSchema: Versioned save game data structure
## 
## Handles serialization/deserialization and schema migration.

class_name SaveSchemaModel

var version: int = Constants.SAVE_VERSION
var timestamp: float = 0.0
var last_saved_time: float = 0.0
var resources: Dictionary = {}
var upgrades: Dictionary = {}
var inventory: Array[Dictionary] = []
var player_stats: Dictionary = {}
var essence: float = 0.0

func _init() -> void:
	timestamp = Time.get_unix_time_from_system()
	last_saved_time = timestamp

func to_dict() -> Dictionary:
	return {
		"version": version,
		"timestamp": timestamp,
		"last_saved_time": last_saved_time,
		"resources": resources,
		"upgrades": upgrades,
		"inventory": inventory,
		"player_stats": player_stats,
		"essence": essence
	}

func from_dict(data: Dictionary) -> void:
	version = data.get("version", 1)
	timestamp = data.get("timestamp", 0.0)
	last_saved_time = data.get("last_saved_time", timestamp)
	resources = data.get("resources", {})
	upgrades = data.get("upgrades", {})
	inventory = data.get("inventory", [])
	player_stats = data.get("player_stats", {})
	essence = data.get("essence", 0.0)

func migrate(from_version: int) -> void:
	# Apply migrations sequentially from old version to current
	if from_version < 2:
		_migrate_v1_to_v2()
	# Future migrations can be added here:
	# if from_version < 3:
	#     _migrate_v2_to_v3()

func _migrate_v1_to_v2() -> void:
	# Set version to 2
	version = 2
	
	# Ensure last_saved_time exists; if missing, set to current time
	if last_saved_time == 0.0:
		last_saved_time = Time.get_unix_time_from_system()
	
	# Ensure resources include all known resource IDs from GameState
	# Initialize missing ones to 0.0
	for resource_id in GameState.resources:
		if not resources.has(resource_id):
			# Create default resource entry
			var resource: ResourceModel = GameState.resources[resource_id]
			resources[resource_id] = {
				"amount": 0.0,
				"unlocked": resource.unlocked
			}
	
	print("Migrated save from v1 to v2")
