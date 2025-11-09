# Idle Godot - Incremental Game

A 2D idle/incremental game built with Godot 4.x featuring resource management, upgrades, combat, inventory, and prestige systems.

## 🎮 Project Vision

Build a comprehensive idle/incremental game with:
- **Phase 1**: Core idle loop (resources, upgrades, passive tick, offline progression, save/load)
- **Phase 2**: UI (resource panel, upgrades panel, tooltips, basic layout)
- **Phase 3**: Combat system (wave-based battles yielding resources/items)
- **Phase 4**: Inventory & equipment (items with effects modifying stats and idle rates)
- **Phase 5**: Prestige & meta progression (reset for permanent multipliers)
- **Phase 6**: Balancing, analytics, and polish

## 📁 Project Structure

```
idle-godot/
├── scripts/
│   ├── autoload/          # Singleton systems (GameState, Economy, etc.)
│   ├── models/            # Data structures (Resource, Upgrade, Item, etc.)
│   ├── systems/           # Additional logic modules
│   └── constants.gd       # Shared constants and enums
├── scenes/
│   ├── ui/                # UI components and panels
│   └── game/              # Main game scenes
├── data/                  # JSON/tres config files
└── tests/                 # Test scripts
```

## 🔧 Core Systems

### Autoload Singletons

- **GameState**: In-memory authoritative state (resources, upgrades, items, player stats)
- **Economy**: Income calculation, upgrade application, cost scaling, prestige formulas
- **TimeService**: Tick/update loop, offline progression calculation
- **SaveSystem**: JSON serialization/deserialization, versioned schema migration
- **CombatSystem**: Enemy spawning, combat simulation, reward generation
- **InventorySystem**: Item management, equip/unequip, stat modifiers
- **PrestigeService**: Prestige mechanics, essence currency, reset flow

### Data Models

- **Resource**: Tracks id, amount, generation rate, and modifiers
- **Upgrade**: Purchasable improvements with cost scaling and effects
- **Item**: Equipment with rarity, slots, and stat effects
- **Enemy**: Combat opponents with HP, attack, defense, and drop tables
- **PlayerStats**: Combat and idle progression stats
- **SaveSchema**: Versioned save data structure

## 🎯 Gameplay Loops

### Idle Loop
Every tick (1 second default), resources generate based on:
```
effective_rate = (base_rate + sum(rate_adders)) * product(multiplier_factors)
```

Where:
- **rate_adders**: All rate-type upgrades targeting the resource: `base_bonus * level`
- **multiplier_factors**: For each multiplier-type upgrade: `(1 + base_bonus * level)`
- Final rate is multiplied by global player stat multiplier

**Example**: Gold with base_rate=1, one rate upgrade (+2 per level) at level 3, one multiplier upgrade (x0.1 per level) at level 2:
```
effective_rate = (1 + 2*3) * (1 + 0.1*2) * 1.0
               = 7 * 1.2 * 1.0
               = 8.4 gold/sec
```

### Rate Calculation Formula

Resources are configured in `data/resources.json` with base production rates.
Upgrades are defined in `data/upgrades.json` with two types:

1. **Rate Upgrades** (`type: "rate"`): Add flat amounts to production
   - Effect: `base_bonus * level` added to rate
   
2. **Multiplier Upgrades** (`type: "multiplier"`): Multiply production
   - Effect: `(1 + base_bonus * level)` multiplied to rate
   - Multiple multipliers stack multiplicatively

### Upgrade Bulk Purchase Formula

The game supports purchasing multiple upgrade levels at once (x1, x10, x100, or Max).

#### Exponential Cost Scaling

For upgrades with exponential cost scaling (`cost_scaling_type: "exponential"`):

**Formula**: 
```
cost_bulk(L, n) = base_cost × growth^L × (growth^n - 1) / (growth - 1)
```

Where:
- `L` = current level
- `n` = number of levels to purchase
- `growth` = cost_growth_factor (e.g., 1.15)
- `base_cost` = initial cost at level 0

This is the geometric series sum formula, which is exact and efficient for exponential scaling.

**Example**: Purchasing 10 levels of an upgrade with base_cost=100, growth=1.15, starting at level 5:
```
cost_bulk(5, 10) = 100 × 1.15^5 × (1.15^10 - 1) / (1.15 - 1)
                 ≈ 100 × 2.0114 × 2.6600 / 0.15
                 ≈ 3,571 gold
```

#### Quadratic/Linear Cost Scaling

For quadratic and linear scaling, costs are calculated iteratively by summing individual level costs:
```
cost_bulk(L, n) = Σ(i=0 to n-1) cost(L + i)
```

This approach is acceptable for reasonable quantities (n ≤ 1000). A hard cap prevents performance issues.

#### Max Purchase Strategy

When "Max" mode is selected, the system calculates the maximum affordable quantity:

**For exponential scaling**: Binary search algorithm
1. Find upper bound by doubling (1, 2, 4, 8, ...) until cost exceeds available gold
2. Binary search between 0 and upper_bound to find exact maximum
3. Time complexity: O(log n)

**For quadratic/linear scaling**: Iterative search
1. Calculate bulk cost for increasing quantities (1, 2, 3, ...)
2. Stop when cost exceeds available gold
3. Capped at 1000 iterations for performance

### Offline Progression
On game load, calculates resource gains during absence:
- Capped at 8 hours (configurable)
- Applies diminishing returns for extended offline periods

### Upgrade System
- Check affordability
- Deduct cost
- Increase level
- Apply effects
- Recalculate next cost using scaling formulas

## 🌟 Prestige & Essence

The Prestige system allows players to reset their progress in exchange for **Essence**, a permanent currency that provides multiplicative bonuses to idle production.

### Prestige Requirements

To prestige, you must meet **at least one** of these conditions:
- **Lifetime Gold** ≥ 2,000,000 (cumulative gold earned across all time)
- **Current Gold** ≥ 500,000

### Essence Gain Formula

When you prestige, essence is calculated from your **lifetime gold**:

```
essence_gain = floor((lifetime_gold / 1,000,000) ^ 0.6)
```

**Example Calculations:**
- 1,000,000 lifetime gold → floor(1^0.6) = **1 essence**
- 5,000,000 lifetime gold → floor(5^0.6) = floor(2.626...) = **2 essence**
- 10,000,000 lifetime gold → floor(10^0.6) = floor(3.981...) = **3 essence**
- 100,000,000 lifetime gold → floor(100^0.6) = floor(15.848...) = **15 essence**

### Soft Cap

For very high lifetime gold values (> 1 billion), a soft cap applies to prevent exponential growth:

```
if lifetime_gold > 1,000,000,000:
    soft_cap_factor = (1,000,000,000 / lifetime_gold) ^ 0.15
    essence_gain = floor(raw_essence × soft_cap_factor)
```

This ensures diminishing returns at extreme values while still rewarding long-term play.

### Essence Effects

Essence provides a **global multiplier** to all idle production rates:

```
multiplier = 1 + (0.02 × sqrt(essence))
```

**Example Multipliers:**
- 0 essence → 1.0× (no bonus)
- 25 essence → 1.1× (+10% production)
- 100 essence → 1.2× (+20% production)
- 400 essence → 1.4× (+40% production)

This multiplier applies **after** all upgrade bonuses, making each prestige increasingly impactful.

### What Resets on Prestige

When you prestige, the following are **reset**:
- Gold → 0
- All upgrades → level 0
- All items cleared
- Player stats → baseline

### What Is Preserved

The following are **kept** through prestige:
- **Essence** (increases with each prestige)
- **Lifetime Gold** (tracking only, never decreases)
- **Total Prestiges** count
- **Essence Spent** (for future meta-upgrades)

### Prestige Strategy

The optimal prestige timing depends on your progression rate:
- **Early game**: Prestige as soon as you reach 2M lifetime gold (1 essence)
- **Mid game**: Wait until doubling your essence would provide significant gains
- **Late game**: Balance prestige frequency with soft cap diminishing returns

Use the **Projected Gain** display in the Prestige Panel to preview your essence reward before confirming.

## 💾 Save/Load Strategy

### Save Schema v3

- **File**: `user://savegame.json` with atomic write via `.tmp` and rolling `.bak` backup
- **Format**: Pretty-printed JSON (indented) for easier diffing
- **Schema**: Versioned with migration support

#### Schema Fields (v3)
```json
{
  "version": 3,
  "timestamp": 1699999999,
  "last_saved_time": 1699999999,
  "resources": {
    "gold": {"amount": 1234.56, "unlocked": true}
  },
  "upgrades": {
    "gold_mine_rate": {"level": 5, "type": "rate", ...}
  },
  "items": [],
  "player_stats": {...},
  "essence": 10.0,
  "lifetime_gold": 5000000.0,
  "total_prestiges": 3,
  "essence_spent": 0.0,
  "prestige_settings": {"formula_version": 1}
}
```

#### Save Schema v3 Changes

New fields added in version 3 for prestige system:
- **lifetime_gold**: Cumulative gold earned across all time (never decreases)
- **total_prestiges**: Number of times player has prestiged
- **essence_spent**: Essence used on meta-upgrades (reserved for future use)
- **prestige_settings**: Versioned prestige formula settings

### Atomic Write Process
1. Write to `savegame.json.tmp`
2. Flush and close temp file
3. Rename `savegame.json` → `savegame.bak` (if exists)
4. Rename `savegame.json.tmp` → `savegame.json`

This ensures save data is never corrupted even if the game crashes during save.

### Autosave
- Automatically saves every 30 seconds
- Saves on application exit
- Manual save available via debug panel

### Offline Progression

On game load, calculates resource gains during absence:

**Formula**: `gain = per_second_rate × min(time_away, OFFLINE_HARD_CAP_SEC)`

- **Cap**: 8 hours (28,800 seconds) - configurable via `Constants.OFFLINE_HARD_CAP_SEC`
- **Clock skew protection**: Negative time deltas are treated as 0 and reset `last_saved_time`
- Uses current upgrade levels to compute per-second rates
- Applied once on load before first tick

**Example**: 
- Player has 10 gold/sec from upgrades
- Away for 1 hour (3,600 seconds)
- On return: +36,000 gold

If away for 12 hours, gain is capped at 8 hours:
- On return: +288,000 gold (10/sec × 8 hours)

## 🎨 Coding Conventions

- **Naming**: PascalCase for classes, snake_case for functions/variables
- **Types**: Full type hints everywhere (`var amount: float = 0.0`)
- **Functions**: Single-responsibility, <= 40 lines
- **Documentation**: Docstrings at top of each file
- **Constants**: No magic numbers; use `constants.gd`

## 📋 Development Roadmap

### Completed
- ✅ **PR1**: Project scaffold, singleton stubs, basic main scene
- ✅ **PR2**: Implement Resource & Upgrade models + Economy tick
- ✅ **PR3**: SaveSystem + offline progression + autosave + debug controls
- ✅ **PR4**: Structured Game UI + Upgrade Purchase Enhancements + Tooltips + Number Formatting
- ✅ **PR5**: Prestige Mechanic + Essence Currency + Reset Flow + UI Integration

### Planned
- ⬜ **PR6**: Items & InventorySystem
- ⬜ **PR7**: CombatSystem with wave simulation
- ⬜ **PR8**: Enemy drop tables, item rewards
- ⬜ **PR9**: Balancing, analytics, polish

## 🚀 Getting Started

### Prerequisites
- Godot 4.3 or later
- Basic knowledge of GDScript

### Running the Project
1. Clone the repository
2. Open the project in Godot 4.x
3. Run the main scene (`scenes/game/main.tscn`)

### Adding a New Upgrade

1. Define upgrade in `GameState._initialize_default_state()`:
```gdscript
var new_upgrade := UpgradeModel.new("upgrade_id", "Display Name", "target_resource", 10.0, true)
new_upgrade.description = "What this upgrade does"
new_upgrade.effect_value = 1.0
new_upgrade.cost_scaling_type = Constants.CostScalingType.EXPONENTIAL
upgrades["upgrade_id"] = new_upgrade
```

2. The upgrade will automatically appear in the UI and be purchasable

## 📊 Save Schema Versions

| Version | Changes |
|---------|---------|
| 1       | Initial schema with resources, upgrades, items, player stats, essence |
| 2       | Added `last_saved_time` for offline progression, ensured all known resources present, atomic write with backup |
| 3       | Added prestige fields: `lifetime_gold`, `total_prestiges`, `essence_spent`, `prestige_settings` |

## ⚖️ Tuning Constants

The following constants control prestige balance and can be adjusted in `scripts/config/BalanceConstants.gd`:

| Constant | Default Value | Description |
|----------|---------------|-------------|
| `GOLD_DENOMINATOR` | 1,000,000 | Scaling factor for essence gain formula |
| `ESSENCE_EXPONENT` | 0.6 | Diminishing returns exponent |
| `SOFT_CAP_BASE` | 1,000,000,000 | Lifetime gold threshold for soft cap |
| `SOFT_CAP_EXPONENT` | 0.15 | Soft cap reduction factor |
| `ESSENCE_BASE_MULTIPLIER` | 0.02 | Base multiplier per sqrt(essence) |
| `PRESTIGE_REQUIRED_LIFETIME_GOLD` | 2,000,000 | Minimum lifetime gold to prestige |
| `PRESTIGE_CURRENT_GOLD_REQUIREMENT` | 500,000 | Alternative current gold requirement |

## 🛡️ Security & Integrity

Future improvements:
- HMAC hash for save file validation
- Compression for large save files
- Anti-cheat measures

## 📝 License

This project is open source and available for educational purposes.

## 🤝 Contributing

This is a learning project following incremental development practices:
- Keep PRs small and focused
- Use conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`)
- Provide inline comments for complex formulas
- Test changes thoroughly before submitting

---

**Current Status**: PR1 - Project structure scaffolded and ready for core implementation.
