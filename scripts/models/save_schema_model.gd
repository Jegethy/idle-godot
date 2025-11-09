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
var lifetime_gold: float = 0.0
var total_prestiges: int = 0
var essence_spent: float = 0.0
var prestige_settings: Dictionary = {}

# Combat state (v3)
var current_wave: int = 0
var lifetime_enemies_defeated: int = 0

# Inventory & Equipment state (v4)
var equipped_slots: Dictionary = {}  # {slot: instance_id}

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
		"essence": essence,
		"lifetime_gold": lifetime_gold,
		"total_prestiges": total_prestiges,
		"essence_spent": essence_spent,
		"prestige_settings": prestige_settings,
		"current_wave": current_wave,
		"lifetime_enemies_defeated": lifetime_enemies_defeated,
		"equipped_slots": equipped_slots
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
	lifetime_gold = data.get("lifetime_gold", 0.0)
	total_prestiges = data.get("total_prestiges", 0)
	essence_spent = data.get("essence_spent", 0.0)
	prestige_settings = data.get("prestige_settings", {})
	current_wave = data.get("current_wave", 0)
	lifetime_enemies_defeated = data.get("lifetime_enemies_defeated", 0)
	equipped_slots = data.get("equipped_slots", {})

func migrate(from_version: int) -> void:
	# Apply migrations sequentially from old version to current
	if from_version < 2:
		_migrate_v1_to_v2()
	if from_version < 3:
		_migrate_v2_to_v3()
	if from_version < 4:
		_migrate_v3_to_v4()

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

func _migrate_v2_to_v3() -> void:
	# Set version to 3
	version = 3
	
	# Add new prestige fields with defaults
	if lifetime_gold == 0.0:
		# Initialize lifetime_gold with current gold if not already set
		if resources.has("gold") and resources["gold"].has("amount"):
			lifetime_gold = resources["gold"]["amount"]
		else:
			lifetime_gold = 0.0
	
	# Initialize total_prestiges if not present
	if total_prestiges == 0:
		total_prestiges = 0
	
	# Initialize essence_spent if not present
	if essence_spent == 0.0:
		essence_spent = 0.0
	
	# Initialize prestige_settings with formula version
	if prestige_settings.is_empty():
		prestige_settings = {
			"formula_version": BalanceConstants.PRESTIGE_FORMULA_VERSION
		}
	
	print("Migrated save from v2 to v3")

func _migrate_v3_to_v4() -> void:
	# Set version to 4
	version = 4
	
	# Initialize equipped_slots if not present
	if equipped_slots.is_empty():
		equipped_slots = {}
	
	# Ensure inventory is an array
	if not inventory is Array:
		inventory = []
	
	print("Migrated save from v3 to v4")
