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
