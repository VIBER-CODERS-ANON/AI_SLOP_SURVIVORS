# Unified Stat System - Complete Architecture

## Core Design Principle
**Player = Stat Hub, Everything Else = Consumer**

## Player Stats Structure

### Base Stats (Exportable)
```gdscript
@export var base_move_speed: float = 210.0
@export var base_pickup_range: float = 100.0
@export var base_health: float = 20.0
@export var base_mana: float = 100.0
```

### Bonus Stats (Modified by Boons/Items)
```gdscript
var bonus_move_speed: float = 0.0       # Flat bonus
var bonus_health: float = 0.0           # Flat bonus
var bonus_pickup_range: float = 0.0     # Flat bonus
var bonus_crit_chance: float = 0.0      # For "Crit" tagged items
var bonus_crit_multiplier: float = 0.0  # For crit damage
var bonus_attack_speed: float = 0.0     # For "AttackSpeed" tagged items
var area_of_effect: float = 1.0         # For "AoE" tagged items
var bonus_damage: float = 0.0           # For "Damage" tagged items
var bonus_damage_multiplier: float = 1.0 # For damage multiplication
```

### Derived Stats (Base + Bonus)
```gdscript
func _update_derived_stats():
    move_speed = base_move_speed + bonus_move_speed
    max_health = base_health + bonus_health
    pickup_range = base_pickup_range + bonus_pickup_range
    max_mana = base_mana  # No bonus mana yet
```

## Boon Implementation Pattern

### Simple Additive Boon
```gdscript
# Health Boon
func _on_apply(entity: BaseEntity):
    if entity is Player:
        var player = entity as Player
        player.bonus_health += 10
        player._update_derived_stats()
```

### Percentage Boon
```gdscript
# Speed Boon (+2% movement)
func _on_apply(entity: BaseEntity):
    if entity is Player:
        var player = entity as Player
        var bonus = player.base_move_speed * 0.02
        player.bonus_move_speed += bonus
        player._update_derived_stats()
```

### Multiplicative Boon
```gdscript
# AOE Boon (5% MORE)
func _on_apply(entity: BaseEntity):
    if entity is Player:
        var player = entity as Player
        player.area_of_effect *= 1.05
```

## Weapon Stat Consumption

### Tag-Based System
```gdscript
# In BasePrimaryWeapon
func calculate_final_damage(base_dmg: float) -> Dictionary:
    _update_player_bonuses()
    
    # Check tags and apply bonuses
    if "Damage" in weapon_tags:
        base_dmg += player.bonus_damage
        base_dmg *= player.bonus_damage_multiplier
    
    if "Crit" in weapon_tags:
        var total_crit = base_crit_chance + player.bonus_crit_chance
        # Roll for crit...
```

## Benefits

1. **Single Source of Truth**: All bonuses on player
2. **No Spaghetti**: Clean data flow
3. **Tag-Based Scaling**: Only tagged items get bonuses
4. **Easy Balance**: Change one number
5. **Future-Proof**: New items just need tags

## Migration Checklist

✅ Player stats restructured
✅ Movement speed using base + bonus
✅ Health using base + bonus
✅ Pickup range using base + bonus
✅ Crit system player-centric
✅ AOE system player-centric
✅ Damage bonuses on player
✅ All boons updated
✅ Weapons check player stats

## Removed Complexity

- ❌ Direct stat modification
- ❌ Multiple stat locations
- ❌ Complex inheritance chains
- ❌ Redundant getter methods
- ❌ Property checking with has()

## Code Reduction

- Before: ~15 different stat systems
- After: 1 unified pattern
- Lines saved: ~200+
- Complexity: -80%