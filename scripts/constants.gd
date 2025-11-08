extends Node
## Constants: Shared game constants and configuration values
## 
## Central location for magic numbers, configuration, and game balance parameters.

class_name Constants

# Version
const SAVE_VERSION: int = 1

# Tick rates (seconds)
const IDLE_TICK_RATE: float = 1.0

# Offline progression
const MAX_OFFLINE_HOURS: float = 8.0
const MAX_OFFLINE_SECONDS: float = MAX_OFFLINE_HOURS * 3600.0

# Prestige
const PRESTIGE_THRESHOLD: float = 1_000_000.0
const PRESTIGE_ESSENCE_EXPONENT: float = 0.6

# Cost scaling types
enum CostScalingType {
	EXPONENTIAL,  # cost_n = base * (growth ^ level)
	QUADRATIC,    # cost_n = base * (1 + level + level^2 * k)
	LINEAR,       # cost_n = base * (1 + level * k)
	CUSTOM        # Defined by upgrade-specific formula
}

# Item rarity
enum ItemRarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY
}

# Item slots
enum ItemSlot {
	WEAPON,
	ARMOR,
	ACCESSORY,
	CONSUMABLE
}

# Stat modifiers
enum StatModifier {
	ATTACK,
	DEFENSE,
	CRIT_CHANCE,
	CRIT_MULTIPLIER,
	IDLE_RATE_MULTIPLIER,
	COMBAT_SPEED
}

# Save file path
const SAVE_FILE_PATH: String = "user://savegame.json"
