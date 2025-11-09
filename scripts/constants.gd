extends Node
## Constants: Shared game constants and configuration values
## 
## Central location for magic numbers, configuration, and game balance parameters.

class_name Constants

# Version
const SAVE_VERSION: int = 6

# Tick rates (seconds)
const IDLE_TICK_RATE: float = 1.0

# Offline progression
const MAX_OFFLINE_HOURS: float = 8.0
const MAX_OFFLINE_SECONDS: float = MAX_OFFLINE_HOURS * 3600.0
const OFFLINE_HARD_CAP_SEC: float = MAX_OFFLINE_SECONDS  # 28,800 seconds (8 hours)

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
	TRINKET1,
	TRINKET2,
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

# Item effect types (string constants for JSON compatibility)
class EffectType:
	const COMBAT_ATTACK_ADD = "combat_attack_add"
	const COMBAT_DEFENSE_ADD = "combat_defense_add"
	const COMBAT_ATTACK_MULT = "combat_attack_mult"
	const COMBAT_DEFENSE_MULT = "combat_defense_mult"
	const COMBAT_CRIT_CHANCE_ADD = "combat_crit_chance_add"
	const COMBAT_CRIT_MULTIPLIER_ADD = "combat_crit_multiplier_add"
	const COMBAT_SPEED_ADD = "combat_speed_add"
	const IDLE_RATE_ADD = "idle_rate_add"
	const IDLE_RATE_MULTIPLIER = "idle_rate_multiplier"
	const ESSENCE_MULTIPLIER = "essence_multiplier"

# Save file path
const SAVE_FILE_PATH: String = "user://savegame.json"
