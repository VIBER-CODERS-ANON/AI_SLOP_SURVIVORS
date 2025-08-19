# Critical Hit System Guide

## Overview
The critical hit system is implemented at the weapon level, allowing each weapon type to have unique base crit chances and multipliers.

## Architecture

### Base Implementation (BasePrimaryWeapon)
```gdscript
# Core crit properties
@export var base_crit_chance: float = 0.05  # 5% default
@export var base_crit_multiplier: float = 2.0  # 2x damage

# Modifiers (from boons/items)
var bonus_crit_chance: float = 0.0
var bonus_crit_multiplier: float = 0.0
```

### Damage Calculation Flow
1. Weapon calls `calculate_final_damage()` which:
   - Rolls for crit based on total chance
   - Applies multiplier if crit succeeds
   - Returns damage and crit flag

2. Weapon calls `deal_damage_to_enemy()` which:
   - Gets damage result from calculation
   - Adds "crit" tag if critical hit
   - Passes tags to enemy's `take_damage()`

3. Enemy's `take_damage()` checks for "crit" tag
4. Damage number spawns with yellow color if crit

## Weapon Examples

### Sword (10% base crit)
```gdscript
base_crit_chance = 0.1  # High precision weapon
```

### Future Hammer (0% base crit)
```gdscript
base_crit_chance = 0.0  # Heavy, slow weapon
```

### Future Dagger (20% base crit)
```gdscript
base_crit_chance = 0.2  # Precision weapon
```

## Modifying Crit Stats

### From Boons
```gdscript
# Add flat crit chance
weapon.add_crit_chance(0.025)  # +2.5%

# Add crit damage
weapon.add_crit_multiplier(0.5)  # +0.5x damage
```

### From Items (Future)
```gdscript
# Items can modify base OR bonus stats
weapon.base_crit_chance *= 1.5  # Multiplicative
weapon.bonus_crit_chance += 0.1  # Additive
```

## Visual Feedback
- **Yellow text** for critical hits
- **Larger font size** (32px vs 24px)
- **Exclamation mark** added to damage
- **Scale animation** (1.0 -> 1.5 -> 1.0)

## Stat Display
```gdscript
# Get total crit for UI
var total_crit = weapon.get_total_crit_chance()  # Returns 0.0-1.0
var total_mult = weapon.get_total_crit_multiplier()  # Returns multiplier
```

## Common Issues & Solutions

### Issue: Crits not showing yellow text
**Cause**: Weapon not adding "crit" tag to damage_tags
**Solution**: Ensure weapon uses `calculate_final_damage()` and passes tags

### Issue: Boons not affecting crit
**Cause**: Boon applying to player instead of weapons
**Solution**: Apply to all weapons in player_weapons group

## Best Practices
1. **Always use the helper methods** (`add_crit_chance()`, not direct modification)
2. **Clamp crit chance** between 0.0 and 1.0
3. **Track statistics** (total_crits counter for analytics)
4. **Consistent visual feedback** across all damage sources