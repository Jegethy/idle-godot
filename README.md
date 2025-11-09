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

## ⚔️ Combat System

The Combat System provides wave-based battles against enemies, yielding gold and item drops. Combat is **deterministic** and **seeded** for reproducible outcomes, making it ideal for testing and balancing.

### Core Features

- **Wave-based progression**: Each wave increases in difficulty with scaled enemy stats
- **Deterministic simulation**: Same seed produces identical combat outcomes
- **Two simulation modes**: Interactive (tick-by-tick) and Fast (instant resolution)
- **Essence integration**: Essence provides combat stat bonuses
- **Item drops**: Enemies drop items based on configured drop tables

### Combat Flow

1. **Start Wave**: Player initiates combat against current wave
2. **Combat Resolution**: Player and enemies exchange attacks based on combat speed
3. **Victory/Defeat**: Wave completes when all enemies defeated or player HP reaches zero
4. **Rewards**: On victory, player receives gold and item drops

### Combat Statistics

Player combat stats are derived from base stats plus essence bonuses:

```
essence_combat_bonus = 1 + (COMBAT_ESSENCE_MULTIPLIER × sqrt(essence))
effective_attack = base_attack × essence_combat_bonus
effective_defense = base_defense × essence_combat_bonus
player_max_hp = BASE_PLAYER_HP × essence_combat_bonus
```

**Base Stats** (from `PlayerStatsModel`):
- **Attack**: 10.0 (base damage per hit)
- **Defense**: 5.0 (damage reduction)
- **Crit Chance**: 5% (probability of critical hit)
- **Crit Multiplier**: 2.0x (damage multiplier on crit)
- **Combat Speed**: 1.0 (attacks per second)

**Essence Multiplier** (default: 0.01):
- 0 essence → 1.0× bonus (no change)
- 100 essence → 1.1× bonus (+10% to attack/defense/HP)
- 400 essence → 1.2× bonus (+20% to attack/defense/HP)

### Damage Formula

Each attack calculates damage as follows:

```
base_damage = max(1, attacker_attack - target_defense)
if critical_hit:
    final_damage = base_damage × crit_multiplier
else:
    final_damage = base_damage
```

**Attack Timing**:
- Attack interval = 1.0 / combat_speed
- Player attacks first enemy in list
- Each enemy attacks player independently

### Wave Scaling

Enemy stats scale exponentially with wave index:

```
enemy_hp = base_hp × (hp_growth_factor ^ wave_index)
enemy_attack = base_attack × (attack_growth_factor ^ wave_index)
enemy_defense = base_defense × (defense_growth_factor ^ wave_index)
gold_reward = base_gold × (gold_multiplier ^ wave_index)
```

**Default Scaling Factors** (from `wave_config.json`):
- HP Growth: 1.15 (15% increase per wave)
- Attack Growth: 1.10 (10% increase per wave)
- Defense Growth: 1.08 (8% increase per wave)
- Gold Multiplier: 1.05 (5% increase per wave)

**Wave Composition**:
- Base enemy count: 3
- Enemy count growth: +0.2 per wave
- **Elite Wave**: Every 5th wave, last enemy becomes Elite (2.5× HP, 1.5× attack)
- **Boss Wave**: Every 10th wave, single Boss enemy (5× HP, 2× attack)

### Enemy Types

Defined in `data/enemies.json`:

| Enemy | Base HP | Base Attack | Base Defense | Base Gold |
|-------|---------|-------------|--------------|-----------|
| Slime | 50 | 5 | 2 | 10 |
| Goblin | 75 | 8 | 4 | 15 |
| Skeleton | 100 | 12 | 6 | 20 |
| Boss Core | 500 | 25 | 15 | 100 |

### Drop Tables

Each enemy has a configured drop table with weighted probabilities:

```json
{
  "item_id": "health_potion",
  "weight": 10,
  "min_qty": 1,
  "max_qty": 2,
  "chance": 0.2
}
```

- **chance**: Probability of drop (0.2 = 20%)
- **weight**: Relative weight for weighted random selection
- **min_qty/max_qty**: Quantity range (randomly selected)

### Deterministic Simulation

Combat uses seeded RNG for reproducibility:

```gdscript
# Same seed produces identical outcomes
CombatSystem.fast_simulate_wave(wave_index, seed: 12345)
```

**Use Cases**:
- Testing combat balance
- Reproducing bug reports
- Validating combat formulas

### Interactive vs Fast Simulation

**Interactive Mode** (`Start Wave` button):
- Combat progresses tick-by-tick (0.5s per tick)
- UI updates in real-time showing enemy HP bars
- Combat log displays each hit/crit/defeat event
- Player can observe combat flow

**Fast Simulation Mode** (`Fast Sim` button):
- Entire wave resolves instantly
- Summary displayed immediately
- No real-time updates
- Efficient for farming/testing

Both modes produce **identical results** for the same seed.

### Combat Summary

After combat ends, summary statistics are displayed:

- **Time**: Total combat duration (seconds)
- **Enemies Defeated**: Count of enemies killed
- **Damage Dealt**: Total player damage output
- **Damage Taken**: Total player damage received
- **DPS**: Damage per second (damage_dealt / time)
- **Rewards**: Gold and items gained (victory only)

### Combat Constants

Tunable constants in `BalanceConstants.gd`:

| Constant | Default | Description |
|----------|---------|-------------|
| `COMBAT_TICK_SECONDS` | 0.5 | Duration of each simulation tick |
| `PLAYER_BASE_CRIT_CHANCE` | 0.05 | 5% base critical hit chance |
| `PLAYER_BASE_CRIT_MULTIPLIER` | 2.0 | 2x damage on critical hits |
| `COMBAT_ESSENCE_MULTIPLIER` | 0.01 | Essence bonus scaling factor |
| `BASE_PLAYER_HP` | 100.0 | Base player HP before bonuses |
| `ELITE_HP_MULTIPLIER` | 2.5 | Elite enemy HP multiplier |
| `ELITE_ATTACK_MULTIPLIER` | 1.5 | Elite enemy attack multiplier |
| `BOSS_HP_MULTIPLIER` | 5.0 | Boss enemy HP multiplier |
| `BOSS_ATTACK_MULTIPLIER` | 2.0 | Boss enemy attack multiplier |
| `MAX_SIM_TICKS` | 1000 | Maximum ticks to prevent runaway |

### Save Data

Combat progress is saved with the following fields:
- **current_wave**: Highest wave completed (auto-increments on victory)
- **lifetime_enemies_defeated**: Total enemies killed across all time

### Testing

Comprehensive test suite validates:
- **RNG Determinism**: Same seed produces same random sequences
- **Wave Scaling**: Enemy stats scale according to formulas
- **Combat Victory**: Player can defeat weak enemies
- **Drop Probability**: Drops occur with expected frequency (tolerance)
- **Mode Equivalence**: Fast and interactive modes yield identical results

Run tests with:
```bash
godot --headless --script tests/test_rng_determinism.gd
godot --headless --script tests/test_wave_scaling.gd
godot --headless --script tests/test_combat_simple_win.gd
```

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
  "prestige_settings": {"formula_version": 1},
  "current_wave": 5,
  "lifetime_enemies_defeated": 42
}
```

#### Save Schema v3 Changes

New fields added in version 3:

**Prestige System**:
- **lifetime_gold**: Cumulative gold earned across all time (never decreases)
- **total_prestiges**: Number of times player has prestiged
- **essence_spent**: Essence used on meta-upgrades (reserved for future use)
- **prestige_settings**: Versioned prestige formula settings

**Combat System**:
- **current_wave**: Highest wave completed (increments on victory)
- **lifetime_enemies_defeated**: Total enemies killed across all sessions

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
- ✅ **PR6**: Combat System Expansion (Wave-based, Scaling, Drops, Essence Integration, Deterministic Sim, UI, Tests)

### Planned
- ⬜ **PR7**: ✅ Complete - Items & InventorySystem (backend complete, UI deferred)
- ⬜ **PR8**: Additional combat features (abilities, status effects)
- ⬜ **PR9**: Balancing, analytics, polish

## 🎒 Inventory & Equipment

The Inventory & Equipment system allows players to collect items from combat drops and equip them to modify both idle production rates and combat statistics.

### Item System

Items are defined in `data/items.json` and loaded at runtime. Each item has:
- **ID**: Unique identifier (e.g., `iron_sword`)
- **Name**: Display name
- **Slot**: Equipment slot (weapon, armor, trinket1, trinket2, accessory, consumable)
- **Rarity**: Common, Uncommon, Rare, Epic, Legendary
- **Stackable**: Whether multiple copies merge into a single stack
- **Effects**: Array of stat modifiers

### Rarity Tiers

| Rarity | Color | Hex Code |
|--------|-------|----------|
| Common | Gray | #CCCCCC |
| Uncommon | Green | #4CAF50 |
| Rare | Blue | #2196F3 |
| Epic | Purple | #9C27B0 |
| Legendary | Orange | #FF9800 |

### Equipment Slots

Players have 5 equipment slots:
- **weapon**: Primary weapon (affects attack)
- **armor**: Defensive gear (affects defense)
- **trinket1**: Accessory slot 1 (various effects)
- **trinket2**: Accessory slot 2 (various effects)
- **accessory**: Powerful unique items

Consumables cannot be equipped and are reserved for future use (e.g., potions).

### Item Effects

Items can have multiple effects that modify player stats:

| Effect Type | Description | Example |
|-------------|-------------|---------|
| `combat_attack_add` | Flat attack bonus | +5 Attack |
| `combat_defense_add` | Flat defense bonus | +8 Defense |
| `combat_attack_mult` | Attack multiplier | +10% Attack |
| `combat_defense_mult` | Defense multiplier | +15% Defense |
| `combat_crit_chance_add` | Critical hit chance | +5% Crit Chance |
| `combat_crit_multiplier_add` | Critical damage bonus | +20% Crit Damage |
| `combat_speed_add` | Attacks per second | +20% Speed |
| `idle_rate_add` | Flat idle production | +10 Gold/sec |
| `idle_rate_multiplier` | Idle production multiplier | +25% Idle Rate |
| `essence_multiplier` | Essence bonus (future) | +5% Essence |

### Effect Stacking Rules

**Additive Effects**: Multiple items with additive bonuses sum together.
- Iron Sword (+5 attack) + Steel Armor (+8 defense) = +5 attack, +8 defense

**Multiplicative Effects**: Multiple items with multipliers stack multiplicatively.
- Steel Armor (+10% attack) + Epic Gem (+15% attack) = ×1.1 × 1.15 = ×1.265 (26.5% total)

**Caps**: To prevent imbalance, multipliers have caps:
- Attack multiplier: Max +500% (×6.0 total)
- Idle rate multiplier: Max +1000% (×11.0 total)

### Inventory Management

**Capacity**: Soft cap of 200 item entries (stacks count as 1 entry each).

**Stacking**: Stackable items (like potions) merge automatically:
- Max stack size: 999
- Adding to a full stack creates a new stack

**Instance Tracking**: Each non-stackable item has a unique `instance_id` for equipping.

### Stat Recalculation

When items are equipped or unequipped, the system:
1. Clears all cached modifiers
2. Iterates through equipped items and applies their effects
3. Applies caps to prevent overflow
4. Recalculates idle production rates and combat stats
5. Emits `modifiers_recomputed` signal

**Formula for Idle Production**:
```
effective_rate = (base_rate + upgrade_add + item_idle_add) 
                 × upgrade_mult × item_idle_multiplier × essence_multiplier
```

**Formula for Combat Stats**:
```
effective_attack = (base_attack + item_attack_add) × item_attack_mult × essence_bonus
effective_defense = (base_defense + item_defense_add) × item_defense_mult × essence_bonus
```

### Item Acquisition

Items drop from defeated enemies based on drop tables in `data/enemies.json`:
- Each enemy has a drop table with weighted items
- Each drop has a `chance` (probability to drop)
- Quantities can vary (`min_qty` to `max_qty`)
- Drops are deterministic when using seeded RNG

**Example Drop Entry**:
```json
{
  "item_id": "epic_gem",
  "weight": 20,
  "min_qty": 1,
  "max_qty": 1,
  "chance": 0.5
}
```

### Save Schema v4

Inventory state is persisted with the following fields:

```json
{
  "version": 4,
  "inventory": [
    {
      "id": "iron_sword",
      "instance_id": "item_1",
      "quantity": 1,
      "rarity": "common",
      "slot": "weapon",
      "stackable": false
    }
  ],
  "equipped_slots": {
    "weapon": "item_1",
    "armor": "item_5"
  }
}
```

**Migration from v3 → v4**:
- Adds `inventory` array (empty by default)
- Adds `equipped_slots` dictionary (empty by default)
- Preserves all existing fields (essence, upgrades, combat state)

### Balancing Tools

**LoadoutSimulation** tool calculates expected performance for item combinations:

```gdscript
# Simulate idle gain with a loadout
var loadout: Array = [iron_sword, epic_gem]
var idle_rate = LoadoutSimulation.simulate_idle_gain(loadout, base_rate)

# Simulate combat DPS
var dps = LoadoutSimulation.simulate_combat_dps(loadout, base_attack, essence)

# Get complete stat breakdown
var stats = LoadoutSimulation.calculate_loadout_stats(loadout, 10.0, 5.0, 100.0)
print("Effective Attack: ", stats["effective_attack"])
```

### Testing

Run inventory tests with:
```bash
godot --headless --script tests/test_item_stacking.gd
godot --headless --script tests/test_equip_modifiers.gd
godot --headless --script tests/test_idle_rate_with_items.gd
godot --headless --script tests/test_serialization_inventory.gd
godot --headless --script tests/test_migration_v3_to_v4.gd
godot --headless --script tests/test_drag_drop_logic.gd
godot --headless --script tests/test_loadout_simulation.gd
```

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
| 3       | Added prestige fields: `lifetime_gold`, `total_prestiges`, `essence_spent`, `prestige_settings`; Added combat fields: `current_wave`, `lifetime_enemies_defeated` |
| 4       | Added inventory fields: `inventory` array with full item serialization, `equipped_slots` dictionary mapping slots to instance IDs |
| 5       | Added affix fields: `base_id`, `affixes` array, `reroll_count` for procedurally generated item variants |

## 🎲 Affix System

The Affix System adds procedural item generation with prefixes and suffixes that modify item stats.

### How Affixes Work

Items dropped from enemies can roll **affixes** based on their **rarity**:
- **Common**: Max 1 affix
- **Uncommon**: Max 1 affix
- **Rare**: Max 2 affixes
- **Epic**: Max 2 affixes
- **Legendary**: Max 3 affixes

Each affix provides **scaled effects** based on:
1. **Rarity Scaling**: Higher rarities have stronger effect multipliers
2. **Wave Scaling**: Effects increase with wave progression (capped at wave 100)

### Affix Formula

For each affix effect:
```
value = base × rarity_scaling[rarity] × (1 + per_wave_factor × wave_index)
```

**Example**: "Sharp" prefix on a Rare item at wave 10:
```
base = 2.0
rarity_scaling["rare"] = 1.5
per_wave_factor = 0.25
value = 2.0 × 1.5 × (1 + 0.25 × 10) = 2.0 × 1.5 × 3.5 = 10.5 attack
```

### Affix Categories

**Prefixes** (combat-focused):
- Sharp: +Attack
- Fortified: +Defense
- Swift: +Combat Speed
- Deadly: +Crit Chance
- Powerful: +Attack Multiplier
- Reinforced: +Defense Multiplier

**Suffixes** (utility-focused):
- Gleaming: +Idle Rate Multiplier
- Prosperity: +Gold per Second
- Precision: +Crit Damage
- Essence: +Essence Multiplier
- Vigor: +Attack and Defense
- Balance: +Attack and Defense Multipliers

### Rarity-Weighted Drops

Items roll rarity using weighted distribution:
- Common: 60% (weight: 60)
- Uncommon: 25% (weight: 25)
- Rare: 10% (weight: 10)
- Epic: 4% (weight: 4)
- Legendary: 1% (weight: 1)

**Rarity Factor**: Elite and boss enemies have boosted drop quality.

### Deterministic Generation

Affixes use seeded RNG for reproducibility:
```gdscript
var rng := RNGService.new()
rng.set_seed(12345)
var item := AffixService.generate_item_instance(item_def, "rare", 10, rng)
# Same seed always produces same affixes with same values
```

## 🔄 Item Rerolling

Players can reroll item affixes at increasing cost:

### Reroll Cost Formula

```
gold_cost = BASE_REROLL_GOLD × (REROLL_GOLD_GROWTH ^ reroll_count)
essence_cost = BASE_REROLL_ESSENCE × (REROLL_ESSENCE_GROWTH ^ reroll_count)
```

**Default Constants**:
- `BASE_REROLL_GOLD`: 250
- `REROLL_GOLD_GROWTH`: 1.35
- `BASE_REROLL_ESSENCE`: 1
- `REROLL_ESSENCE_GROWTH`: 1.25
- `MAX_REROLL_COUNT`: 50 (soft cap)

**Cost Progression Example**:
| Reroll # | Gold Cost | Essence Cost |
|----------|-----------|--------------|
| 1st      | 250       | 1.0          |
| 2nd      | 338       | 1.3          |
| 3rd      | 456       | 1.6          |
| 5th      | 831       | 2.4          |
| 10th     | 5,024     | 9.3          |

### Usage

```gdscript
# Check reroll cost
var cost_info := InventorySystem.get_reroll_cost(item_instance_id)
print("Costs: %d gold, %.1f essence" % [cost_info["gold"], cost_info["essence"]])

# Reroll affixes
if InventorySystem.reroll_item(item_instance_id):
    print("Item rerolled successfully!")
```

## 📊 Gear Analyzer

The Gear Analyzer compares candidate items against currently equipped items.

### Comparison Metrics

The analyzer calculates:
- **Combat DPS Delta**: Percentage change in damage per second
- **Idle Rate Delta**: Percentage change in idle gold generation
- **Attack Delta**: Raw attack difference
- **Defense Delta**: Raw defense difference
- **Crit Chance Delta**: Critical hit chance difference

### Improvement Threshold

An item is marked as "recommended" if:
- DPS improves by > 0.5% (`ANALYZER_MIN_IMPROVEMENT_THRESHOLD`)
- OR Idle rate improves by > 0.5%

### Usage

```gdscript
# Compare candidate vs equipped
var comparison := GearAnalyzer.compare_items(candidate_item, "weapon")

if comparison["is_improvement"]:
    print("DPS Change: %.1f%%" % comparison["dps_delta_pct"])
    print("Idle Change: %.1f%%" % comparison["idle_delta_pct"])
    
# Get formatted text
var text := GearAnalyzer.get_comparison_text(comparison)
print(text)  # Shows all deltas with recommendation
```

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
