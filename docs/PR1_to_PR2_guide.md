# PR1 to PR2 Transition Guide

## What PR1 Accomplished

PR1 successfully scaffolded the entire project structure with:
- Complete Godot 4 project setup
- All 6 core singleton systems (stubbed but functional)
- All 6 data model classes (fully implemented)
- Working main scene with basic UI
- Functional idle loop, upgrade system, and save/load
- Comprehensive documentation

## Current Game State

When you run the project:
1. Game starts with 0 gold
2. Gold generates at 1.0/second
3. "Gold Production" upgrade available for 10 gold (exponential scaling @ 1.15x)
4. Each upgrade level adds +0.5 gold/s
5. Save/Load buttons work with JSON persistence
6. Offline progression calculates when loading

## Recommended PR2 Scope

**Goal**: Transform from hardcoded to data-driven resource/upgrade system

### Tasks:
1. Create JSON data files in `data/` directory:
   - `resources.json` - Define multiple resource types
   - `upgrades.json` - Define upgrade configurations
   
2. Update `GameState._initialize_default_state()`:
   - Load resources from `resources.json`
   - Load upgrades from `upgrades.json`
   - Remove hardcoded gold/upgrade

3. Add new resource types:
   - Wood (base rate 0.5/s, unlocked)
   - Stone (base rate 0.3/s, unlocked)
   - Mana (base rate 0.1/s, unlocked at 100 gold)

4. Add upgrade varieties:
   - Rate boosts (increase base_rate)
   - Multiplier boosts (add to idle_rate_multiplier)
   - Unlock upgrades (make resources available)

5. Implement unlock conditions:
   - Add `UnlockCondition` evaluation system
   - Support conditions like: `gold >= 100`, `wood_boost.level >= 5`

## Success Criteria for PR2

1. At least 3 different resources generating
2. At least 5 different upgrades available
3. At least 1 unlock condition working (mana unlocks)
4. All data loaded from JSON files (no hardcoded resources)
5. Save/load works with multiple resources
6. UI scales to show all resources/upgrades
