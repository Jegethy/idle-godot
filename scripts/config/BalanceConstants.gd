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
