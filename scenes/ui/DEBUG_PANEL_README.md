# Debug Panel Usage Guide

## Overview
The Debug Panel is a temporary UI for testing and validating the resource rate calculation and upgrade system implemented in PR2.

## Location
- Scene: `scenes/ui/debug_panel.tscn`
- Script: `scenes/ui/debug_panel.gd`
- Main debug scene: `scenes/game/main_debug.tscn`

## Features

### Resource Display
Each resource shows:
- Resource name
- Current amount (updated in real-time)
- Per-second rate (calculated from base rate + upgrades)

Format: `Resource: <name> | Amount: X.YZ | Rate/sec: R.YZ`

### Upgrades Section
Each upgrade displays:
- Upgrade name and type (Rate or Mult)
- Current level
- Cost to buy next level
- Next delta/sec (how much the rate will increase if purchased)
- Buy button (disabled if unaffordable)

Format: `<name> [Type] Lvl:N Cost:C NextΔ/sec:+Δ [Buy]`

### Auto-refresh
The UI automatically refreshes every 1 second to show updated values.

## How to Use

### Running the Debug Scene
1. Open the project in Godot 4.3+
2. Set `scenes/game/main_debug.tscn` as the main scene (or run it directly)
3. The debug panel will load with:
   - Gold starting at 0, gaining 1 gold/sec (base rate)
   - Three upgrades available for purchase

### Testing Upgrades

#### Gold Mine (Rate Upgrade)
- Type: Rate (additive)
- Base cost: 10 gold
- Effect: +2 gold/sec per level
- Cost scaling: Exponential (1.15x per level)

**Example progression:**
- Level 0→1: Cost 10, gold/sec goes 1.0 → 3.0
- Level 1→2: Cost 11.5, gold/sec goes 3.0 → 5.0
- Level 2→3: Cost 13.2, gold/sec goes 5.0 → 7.0

#### Gold Press (Multiplier Upgrade)
- Type: Multiplier (multiplicative)
- Base cost: 100 gold
- Effect: x(1 + 0.1 * level) to gold production
- Cost scaling: Exponential (1.15x per level)

**Example progression:**
- Level 0→1: Cost 100, multiplier goes 1.0x → 1.1x (adds 10% to total)
- Level 1→2: Cost 115, multiplier goes 1.1x → 1.2x (adds another 10%)

#### Super Mine (High-value Rate Upgrade)
- Type: Rate (additive)
- Base cost: 500 gold
- Effect: +5 gold/sec per level
- Cost scaling: Exponential (1.15x per level)

### Testing Rate Calculation

The rate calculation formula is:
```
effective_rate = (base_rate + sum(rate_adders)) * product(multiplier_factors)
```

**Example scenario:**
1. Start: 1 gold/sec (base only)
2. Buy Gold Mine to level 3: 1 + (2*3) = 7 gold/sec
3. Buy Gold Press to level 2: 7 * (1 + 0.1*2) = 7 * 1.2 = 8.4 gold/sec
4. Buy Super Mine to level 1: (7 + 5) * 1.2 = 14.4 gold/sec

### Testing Save/Load
The debug panel works with the existing save system:
- Upgrade levels are saved
- Resource amounts are saved
- Rates are recalculated on load

## Expected Behavior

### On Startup
- Gold displays: `Resource: Gold | Amount: 0.00 | Rate/sec: 1.00`
- All upgrade buttons are disabled (not enough gold)
- Timer starts, updating display every second

### After 10 Seconds
- Gold displays: `Resource: Gold | Amount: 10.00 | Rate/sec: 1.00`
- Gold Mine "Buy" button becomes enabled (cost: 10)

### After First Purchase (Gold Mine)
- Gold amount decreases by 10
- Gold Mine level increments to 1
- Rate/sec updates to 3.0
- Gold starts accumulating faster

### Rates Update
- Rates recalculate after every upgrade purchase
- Rates recalculate every tick (1 second)
- Display updates show new rates within 1 second

## Troubleshooting

### "Resources data file not found" error
- Ensure `data/resources.json` exists
- Fallback resources will be created automatically

### "Upgrades data file not found" error
- Ensure `data/upgrades.json` exists
- Fallback upgrades will be created automatically

### Rates not updating
- Check console for errors
- Verify `Economy.recalculate_all_rates()` is being called
- Check that `GameState.rates_updated` signal is emitted

### Buy button stays disabled
- Verify gold amount is >= upgrade cost
- Check console for purchase errors
- Ensure upgrade is unlocked in data file

## Removing the Debug Panel

When PR2 is complete and merged, the debug panel can be removed:
1. Delete `scenes/ui/debug_panel.tscn` and `scenes/ui/debug_panel.gd`
2. Delete `scenes/game/main_debug.tscn` and `scenes/game/main_debug.gd`
3. The core functionality (Economy, GameState, data files) remains in place
4. Real UI panels can be built using the same Economy API

## Developer Notes

### Key Functions for UI Integration

```gdscript
# Get current per-second rate for a resource
var rate: float = Economy.get_per_second_rate("gold")

# Purchase an upgrade
var success: bool = Economy.purchase_upgrade("gold_mine_rate")

# Listen for rate changes
GameState.rates_updated.connect(_on_rates_updated)

# Listen for upgrade purchases
GameState.upgrade_purchased.connect(_on_upgrade_purchased)
```

### Testing Checklist

- [ ] Resources load from data file
- [ ] Upgrades load from data file
- [ ] Base rate accumulation works (1 gold/sec)
- [ ] Rate upgrades add correctly (additive)
- [ ] Multiplier upgrades multiply correctly
- [ ] Multiple multipliers stack multiplicatively
- [ ] Cost scaling follows formulas
- [ ] Purchase deducts gold correctly
- [ ] Purchase increments level correctly
- [ ] Rates update immediately after purchase
- [ ] Display updates within 1 second
- [ ] Buy buttons disable when unaffordable
- [ ] Save/load preserves upgrade levels
