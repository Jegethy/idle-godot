extends Node
## BalanceConstants: Centralized balancing and tuning constants for prestige system
## 
## All prestige-related formulas and thresholds are defined here
## for easy tuning and balancing.

class_name BalanceConstants

# Prestige Essence Formula Constants
const GOLD_DENOMINATOR: float = 1_000_000.0  # Scaling factor for essence gain
const ESSENCE_EXPONENT: float = 0.6  # Diminishing returns exponent

# Soft Cap for very high lifetime_gold values
const SOFT_CAP_BASE: float = 1_000_000_000.0  # 1 billion
const SOFT_CAP_EXPONENT: float = 0.15  # Soft cap reduction factor

# Essence Multiplier Effects
const ESSENCE_BASE_MULTIPLIER: float = 0.02  # Base multiplier per sqrt(essence)

# Prestige Requirements
const PRESTIGE_REQUIRED_LIFETIME_GOLD: float = 2_000_000.0  # Minimum lifetime gold to prestige
const PRESTIGE_CURRENT_GOLD_REQUIREMENT: float = 500_000.0  # Alternative: current gold requirement

# Prestige Settings Schema Version
const PRESTIGE_FORMULA_VERSION: int = 1  # Track formula changes for future migrations

# Combat System Constants
const COMBAT_TICK_SECONDS: float = 0.5  # Combat simulation tick duration
const PLAYER_BASE_CRIT_CHANCE: float = 0.05  # 5% base crit chance
const PLAYER_BASE_CRIT_MULTIPLIER: float = 2.0  # 2x damage on crit
const COMBAT_ESSENCE_MULTIPLIER: float = 0.01  # Essence bonus to combat stats (1% per sqrt(essence))
const BASE_PLAYER_HP: float = 100.0  # Base player HP before bonuses

# Wave Scaling Multipliers
const ELITE_HP_MULTIPLIER: float = 2.5  # Elite enemies have 2.5x HP
const ELITE_ATTACK_MULTIPLIER: float = 1.5  # Elite enemies have 1.5x attack
const BOSS_HP_MULTIPLIER: float = 5.0  # Boss enemies have 5x HP
const BOSS_ATTACK_MULTIPLIER: float = 2.0  # Boss enemies have 2x attack

# Combat Simulation Limits
const MAX_SIM_TICKS: int = 1000  # Maximum ticks to prevent infinite loops

# Inventory & Equipment Constants
const INVENTORY_SOFT_CAP: int = 200  # Soft limit on inventory entries
const MAX_STACK: int = 999  # Maximum stack size for stackable items
const ITEM_ATTACK_MULT_CAP: float = 5.0  # Max +500% attack multiplier from items
const ITEM_IDLE_MULT_CAP: float = 10.0  # Max +1000% idle rate multiplier from items

# Gear Slots
const GEAR_SLOTS: Array[String] = ["weapon", "armor", "trinket1", "trinket2", "accessory"]

# Rarity Order
const RARITY_ORDER: Array[String] = ["common", "uncommon", "rare", "epic", "legendary"]

# Rarity Colors (hex codes)
const RARITY_COLORS: Dictionary = {
	"common": "#CCCCCC",
	"uncommon": "#4CAF50",
	"rare": "#2196F3",
	"epic": "#9C27B0",
	"legendary": "#FF9800"
}

# Affix & Reroll Constants
const BASE_REROLL_GOLD: float = 250.0  # Base gold cost for rerolling affixes
const REROLL_GOLD_GROWTH: float = 1.35  # Exponential growth factor for reroll cost
const BASE_REROLL_ESSENCE: float = 1.0  # Base essence cost for rerolling (optional)
const REROLL_ESSENCE_GROWTH: float = 1.25  # Exponential growth factor for essence cost
const MAX_REROLL_COUNT: int = 50  # Soft cap on reroll count
const AFFIX_WAVE_SCALING_CAP: int = 100  # Cap on wave scaling for affix values
const ANALYZER_MIN_IMPROVEMENT_THRESHOLD: float = 0.005  # 0.5% minimum to highlight improvement

# Meta Upgrade Constants
const META_REFUND_RATE: float = 0.6  # 60% of essence spent returned on respec
const META_RESPEC_COOLDOWN_SEC: int = 3600  # 1 hour cooldown between respecs
const META_ROI_MIN_DELTA: float = 0.0001  # Minimum delta to avoid division by near-zero

# Meta Upgrade Category Colors (hex codes)
const META_CATEGORY_COLORS: Dictionary = {
	"idle": "#FFD700",      # Golden
	"combat": "#DC143C",    # Crimson Red
	"loot": "#32CD32",      # Lime Green
	"prestige": "#9370DB"   # Medium Purple
}
