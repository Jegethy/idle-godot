extends RefCounted
## SaveSchema: Versioned save game data structure
## 
## Handles serialization/deserialization and schema migration.

class_name SaveSchemaModel

var version: int = Constants.SAVE_VERSION
var timestamp: float = 0.0
var resources: Dictionary = {}
var upgrades: Dictionary = {}
var inventory: Array[Dictionary] = []
var player_stats: Dictionary = {}
var essence: float = 0.0

func _init() -> void:
	timestamp = Time.get_unix_time_from_system()

func to_dict() -> Dictionary:
	return {
		"version": version,
		"timestamp": timestamp,
		"resources": resources,
		"upgrades": upgrades,
		"inventory": inventory,
		"player_stats": player_stats,
		"essence": essence
	}

func from_dict(data: Dictionary) -> void:
	version = data.get("version", 1)
	timestamp = data.get("timestamp", 0.0)
	resources = data.get("resources", {})
	upgrades = data.get("upgrades", {})
	inventory = data.get("inventory", [])
	player_stats = data.get("player_stats", {})
	essence = data.get("essence", 0.0)

func migrate(from_version: int) -> void:
	# TODO: Implement migration logic for each version
	# Example: if from_version < 2: apply_migration_v1_to_v2()
	pass
