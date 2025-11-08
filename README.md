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

### Prestige System
Formula: `essence_gain = floor((total / 1,000,000) ^ 0.6)`
- Resets most progress
- Grants permanent "Essence" currency
- Unlocks advanced upgrades and multipliers

## 💾 Save/Load Strategy

### Save Schema v2

- **File**: `user://savegame.json` with atomic write via `.tmp` and rolling `.bak` backup
- **Format**: Pretty-printed JSON (indented) for easier diffing
- **Schema**: Versioned with migration support

#### Schema Fields (v2)
```json
{
  "version": 2,
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
  "essence": 0.0
}
```

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

### Planned
- ✅ **PR1**: Project scaffold, singleton stubs, basic main scene
- ✅ **PR2**: Implement Resource & Upgrade models + Economy tick
- ✅ **PR3**: SaveSystem + offline progression + autosave + debug controls
- ⬜ **PR4**: UI panels (resources, upgrades, tooltips)
- ⬜ **PR4**: UI panels (resources, upgrades, tooltips)
- ⬜ **PR5**: Cost scaling + multiple upgrade types
- ⬜ **PR6**: Items & InventorySystem
- ⬜ **PR7**: CombatSystem with wave simulation
- ⬜ **PR8**: Enemy drop tables, item rewards
- ⬜ **PR9**: Prestige system + essence currency
- ⬜ **PR10+**: Balancing, analytics, polish

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
