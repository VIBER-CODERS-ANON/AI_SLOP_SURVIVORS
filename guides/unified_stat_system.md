# Unified Stat System Guide

## Overview
The stat system uses a **player-centric** design where the player holds all bonus stats, and weapons/abilities check these bonuses based on their tags.

## Architecture

### Player Stats
```gdscript
# Player holds all bonus stats
var bonus_crit_chance: float = 0.0      # Added to "Crit" tagged items
var bonus_crit_multiplier: float = 0.0  # Added to crit damage
var bonus_attack_speed: float = 0.0     # Multiplier for "AttackSpeed" tag
var area_of_effect: float = 1.0         # Multiplier for "AoE" tag
var bonus_damage: float = 0.0           # Flat damage for "Damage" tag
var bonus_damage_multiplier: float = 1.0 # Multiplier for "Damage" tag
```

### Weapon Base Stats
```gdscript
# Each weapon has its own base values
@export var base_damage: float = 1.0
@export var base_attack_speed: float = 1.0
@export var base_crit_chance: float = 0.1  # 10% for swords
@export var base_crit_multiplier: float = 2.0
```

## Tag System

Tags determine which stats apply:

| Tag | Affected Stats | Example |
|-----|---------------|---------|
| `"Crit"` | bonus_crit_chance, bonus_crit_multiplier | Swords, Daggers |
| `"AoE"` | area_of_effect | Explosions, Arc attacks |
| `"AttackSpeed"` | bonus_attack_speed | Fast weapons |
| `"Damage"` | bonus_damage, bonus_damage_multiplier | All damaging effects |

## Implementation Pattern

### 1. Weapon Checks Player Stats
```gdscript
func calculate_final_damage(base_dmg: float) -> Dictionary:
    _update_player_bonuses()  # Cache player stats
    
    # Apply damage bonuses if tagged
    if "Damage" in weapon_tags:
        base_dmg += cached_player_bonuses.get("damage", 0.0)
        base_dmg *= cached_player_bonuses.get("damage_mult", 1.0)
    
    # Apply crit if tagged
    if "Crit" in weapon_tags:
        var total_crit = base_crit_chance + cached_player_bonuses.get("crit_chance", 0.0)
        # Roll for crit...
```

### 2. AOE Scaling
```gdscript
func get_aoe_scale() -> float:
    if "AoE" in weapon_tags:
        return owner_entity.area_of_effect
    return 1.0

# In weapon code
var aoe_scale = get_aoe_scale()
arc_radius *= aoe_scale
sword_scale *= aoe_scale
```

### 3. Attack Speed
```gdscript
func get_effective_attack_speed() -> float:
    var speed = base_attack_speed
    if "AttackSpeed" in weapon_tags:
        speed *= (1.0 + cached_player_bonuses.get("attack_speed", 0.0))
    return speed
```

## Boon Integration

Boons modify **player stats**, not weapon stats:

```gdscript
# Crit Boon
func _on_apply(entity: BaseEntity):
    if entity is Player:
        entity.bonus_crit_chance += 0.025  # +2.5%

# AOE Boon (multiplicative)
func _on_apply(entity: BaseEntity):
    if entity is Player:
        entity.area_of_effect *= 1.05  # 5% MORE
```

## Benefits

1. **Single Source of Truth**: Player holds all bonuses
2. **No Double-Dipping**: Each system checks once
3. **Future-Proof**: New items automatically work if tagged
4. **Clear Separation**: Base (weapon) vs Bonus (player)
5. **Easy Debugging**: Check player.bonus_X for any stat

## Examples

### Sword with 10% base crit
- Has tags: `["Melee", "Primary", "AoE", "AttackSpeed", "Crit", "Damage", "Sword"]`
- Base crit: 10%
- Player bonus crit: +5% (from boons)
- Total crit: 15%

### Future Exploding Enemy Death
- Has tag: `["AoE"]`
- Checks player.area_of_effect
- Explosion radius *= area_of_effect

### Future Dagger with high crit
- Base crit: 20%
- Has `"Crit"` tag
- Adds player.bonus_crit_chance
- Total could be 25%+ with boons

## Best Practices

1. **Always tag appropriately**: If it can crit, add `"Crit"` tag
2. **Check tags before applying**: Only apply bonuses to tagged items
3. **Cache player stats**: Update once per attack, not per calculation
4. **Use multiplicative for AOE**: It's a "MORE" multiplier, not additive
5. **Document base values**: Comment what each weapon's base stats represent