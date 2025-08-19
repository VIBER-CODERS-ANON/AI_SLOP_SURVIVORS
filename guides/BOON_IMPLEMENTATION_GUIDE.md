# Comprehensive Boon Implementation Guide

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Creating a New Boon](#creating-a-new-boon)
4. [Rarity System](#rarity-system)
5. [Boon Types](#boon-types)
6. [Integration](#integration)
7. [Balance Philosophy](#balance-philosophy)
8. [Best Practices](#best-practices)
9. [Examples](#examples)
10. [Troubleshooting](#troubleshooting)
11. [Checklist](#checklist)

## Overview

The A.S.S (AI SLOP SURVIVORS) boon system provides permanent upgrades to players that:
- **Scale Automatically**: Single base value scales across all rarities
- **Stack Intelligently**: Using MORE (multiplicative) or Increased (additive) scaling
- **Integrate Seamlessly**: Works with all game systems via standardized hooks
- **Display Beautifully**: Rarity-based visual effects and UI
- **Balance Easily**: Change one value, affects all rarities proportionally

## Architecture

### Core Components

1. **BaseBoon** (`systems/boon_system/base_boon.gd`)
   - Base class for all boons
   - Handles rarity scaling via `get_effective_power()`
   - Provides lifecycle hooks

2. **BoonManager** (`systems/boon_system/boon_manager.gd`)
   - Manages boon pools (common/unique)
   - Implements ticket-based rarity selection
   - Tracks selected unique boons
   - Handles boon application

3. **BoonRarity** (`systems/boon_system/boon_rarity.gd`)
   - Defines rarity properties
   - Sets power multipliers
   - Configures visual effects
   - Manages ticket weights

4. **BoonSelection UI** (`ui/boon_selection.gd`)
   - Presents 3 boon choices on level up
   - Displays rarity-based visual effects
   - Handles player selection

### System Flow

```
Level Up → BoonManager.get_random_boons() → Draw Rarity Tickets → Select Boons
                                                      ↓
                                           Apply Power Multipliers
                                                      ↓
Player Selects → BoonManager.apply_boon() → BaseBoon._on_apply()
                                                      ↓
                                              Modify Entity Stats
```

## Creating a New Boon

### Step 1: Create the Boon Class

Create a new file in `systems/boon_system/boons/` named `your_boon.gd`:

```gdscript
extends BaseBoon
class_name YourBoon

## Brief description of what your boon does
## Include scaling behavior (MORE vs Increased)

func _init():
    # REQUIRED: Set unique ID
    id = "your_boon_id"
    display_name = "Your Boon Name"
    description = "What this boon does"  # Will be shown in selection UI
    
    # REQUIRED: Set base type for categorization
    base_type = "category"  # e.g., "damage", "defense", "utility", "unique"
    
    # REQUIRED: Set icon color (used when no custom icon)
    icon_color = Color(1.0, 0.5, 0.0)  # Orange example
    
    # OPTIONAL: For unique boons that can be selected multiple times
    is_repeatable = false  # Default is false

func get_formatted_description() -> String:
    # REQUIRED: Return description with calculated values
    # This is called by UI to show actual numbers
    var value = get_effective_power(BASE_VALUE)
    return "+%.0f to Something" % value
    # OR for percentage
    return "+%.0f%% Something" % (value * 100)

func _on_apply(entity: BaseEntity) -> void:
    # REQUIRED: Implement the actual effect
    # This is called when player selects the boon
    
    # Example: Modify a stat
    if entity is Player:
        var player = entity as Player
        var bonus = get_effective_power(10.0)  # Base value of 10
        player.some_stat += bonus
        
    # Always print confirmation for debugging
    print("✨ %s gained %s!" % [entity.name, display_name])

func _on_remove(entity: BaseEntity) -> void:
    # OPTIONAL: Only needed for removable boons
    # Most boons are permanent and don't need this
    pass
```

### Step 2: Understanding Power Scaling

The `get_effective_power()` method automatically scales your base values:

```gdscript
# In your boon's _on_apply method:
var damage_bonus = get_effective_power(5.0)  # Base value of 5

# This returns:
# Common: 5 * 1.0 = 5
# Magic:  5 * 2.0 = 10
# Rare:   5 * 3.0 = 15
# Epic:   5 * 4.0 = 20
```

### Step 3: Choose Scaling Type

#### Increased (Additive) - Linear Growth
```gdscript
# Example: Movement Speed Boon
func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var speed_bonus = get_effective_power(10.0)  # Base 10
        player.move_speed += speed_bonus
        # Stacking: 310 → 320 → 330 → 340...
```

#### MORE (Multiplicative) - Exponential Growth
```gdscript
# Example: Area of Effect Boon
func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var aoe_multiplier = get_effective_power(0.05)  # Base 5%
        player.area_of_effect *= (1.0 + aoe_multiplier)
        # Stacking: 1.05 → 1.1025 → 1.157625...
```

### Step 4: Add to Boon Pool

In `boon_manager.gd`, add your boon to the appropriate pool:

```gdscript
func _initialize_boon_pools():
    # For stat-based boons
    common_boons = [
        # ... existing boons ...
        preload("res://systems/boon_system/boons/your_boon.gd").new(),
    ]
    
    # OR for special mechanic boons
    unique_boons = [
        # ... existing boons ...
        preload("res://systems/boon_system/boons/your_unique_boon.gd").new(),
    ]
```

## Rarity System

### Power Multipliers

| Rarity | Multiplier | Color | Ticket Weight | Visual Effects |
|--------|------------|-------|---------------|----------------|
| Common | 1.0x | Light Grey | 100 | Basic border |
| Magic | 2.0x | Soft Blue | 25 | Glow effect |
| Rare | 3.0x | Soft Yellow | 10 | Shine animation |
| Epic | 4.0x | Vibrant Purple | 5 | Particles + shine |
| Unique | Custom | Orange | 10 | Special effects |

### Ticket System

The rarity is determined BEFORE the boon is selected:

1. Draw from ticket pool (145 total tickets)
2. Determine rarity based on ticket
3. Select random boon from that rarity's pool
4. Apply power multiplier

This ensures consistent rarity distribution regardless of pool sizes.

### Unique Boons

Unique boons bypass the standard multiplier system:

```gdscript
# Unique boons often have custom effects
func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        # Custom effect, no scaling
        player.max_health *= 0.5  # Halve health
        player.get_primary_weapon().base_damage *= 2.0  # Double damage
```

## Boon Types

### 1. Stat Boons (Common Pool)

Simple stat increases that scale with rarity:

```gdscript
class_name HealthBoon
extends BaseBoon

func _init():
    id = "health_boost"
    display_name = "Vitality"
    base_type = "max_health"
    icon_color = Color(0, 1, 0)  # Green

func get_formatted_description() -> String:
    var value = get_effective_power(10.0)
    return "+%.0f Maximum Health" % value

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var health_bonus = get_effective_power(10.0)
        player.max_health += health_bonus
        player.current_health += health_bonus  # Also heal
```

### 2. Percentage Boons

Boons that modify stats by percentages:

```gdscript
class_name CritBoon
extends BaseBoon

func _init():
    id = "crit_chance"
    display_name = "Precision"
    base_type = "critical"
    icon_color = Color(1, 1, 0)  # Yellow

func get_formatted_description() -> String:
    var value = get_effective_power(0.05)  # 5% base
    return "+%.0f%% Critical Strike Chance" % (value * 100)

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var crit_bonus = get_effective_power(0.05)
        player.crit_chance += crit_bonus
```

### 3. Weapon Modifier Boons

Boons that affect weapon behavior:

```gdscript
class_name ArcExtensionBoon
extends BaseBoon

func _init():
    id = "arc_extension"
    display_name = "Sweeping Blade"
    base_type = "weapon_modifier"
    icon_color = Color(0.5, 0.5, 1)  # Light blue

func get_formatted_description() -> String:
    var degrees = get_effective_power(25.0)
    return "+%.0f° Arc Angle for Sword Weapons" % degrees

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var weapon = player.get_primary_weapon()
        if weapon and "Sword" in weapon.get_weapon_tags():
            var degrees = get_effective_power(25.0)
            weapon.add_arc_degrees(degrees)
```

### 4. Unique Mechanic Boons

Boons with special effects that don't scale traditionally:

```gdscript
class_name GlassCannonBoon
extends BaseBoon

func _init():
    id = "glass_cannon"
    display_name = "Glass Cannon"
    base_type = "unique"
    icon_color = Color(1.0, 0.6, 0.2)  # Orange
    is_repeatable = false  # Can only be selected once

func get_formatted_description() -> String:
    return "Double your damage, but halve your maximum health. High risk, high reward!"

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        
        # Double damage
        var weapon = player.get_primary_weapon()
        if weapon:
            weapon.base_damage *= 2.0
        
        # Halve health
        player.max_health *= 0.5
        if player.current_health > player.max_health:
            player.current_health = player.max_health
```

### 5. Stackable Unique Boons

Some unique boons can be selected multiple times:

```gdscript
class_name TwinSlashBoon
extends BaseBoon

func _init():
    id = "twin_slash"
    display_name = "Twin Slash"
    base_type = "unique"
    icon_color = Color(0.8, 0.2, 0.8)  # Purple
    is_repeatable = true  # Can stack!

func get_formatted_description() -> String:
    return "All sword-tagged weapons swing an additional time"

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var weapon = player.get_primary_weapon()
        if weapon and "Sword" in weapon.get_weapon_tags():
            weapon.add_extra_strike()  # Stackable method
```

## Integration

### Player Integration

The player automatically receives boon selection on level up:

```gdscript
# In player.gd or game_controller.gd
func _on_player_level_up(new_level: int):
    # Show boon selection UI
    var boon_selection = preload("res://ui/boon_selection.tscn").instantiate()
    get_tree().current_scene.add_child(boon_selection)
    boon_selection.show_selection()
    
    # Connect to selection
    boon_selection.boon_selected.connect(_on_boon_selected)
    
    # Pause game
    get_tree().paused = true

func _on_boon_selected(boon: BaseBoon):
    # Apply boon
    var boon_manager = BoonManager.get_instance()
    if boon_manager:
        boon_manager.apply_boon(boon, player)
    
    # Resume game
    get_tree().paused = false
```

### Weapon Integration

For boons that modify weapons:

```gdscript
# In weapon class
var arc_angle_bonus: float = 0.0
var extra_strikes: int = 0

func add_arc_degrees(degrees: float) -> void:
    arc_angle_bonus += degrees
    _update_arc_parameters()

func add_extra_strike() -> void:
    extra_strikes += 1
    _update_attack_pattern()

func get_total_arc_angle() -> float:
    return base_arc_angle + arc_angle_bonus
```

### Stat Integration

For boons that modify player stats:

```gdscript
# In player.gd
func get_total_damage() -> float:
    var base = base_damage
    # Apply additive bonuses
    base += damage_bonus_flat
    # Apply multiplicative bonuses
    base *= damage_multiplier
    return base

func get_movement_speed() -> float:
    return move_speed * movement_speed_multiplier

func get_crit_chance() -> float:
    return clamp(base_crit_chance + crit_chance_bonus, 0.0, 1.0)
```

## Balance Philosophy

### Single Source of Truth

- Define values ONCE at the Common level
- All rarities scale automatically
- Change base value = affects all rarities proportionally

### Scaling Guidelines

#### Use Increased (Additive) For:
- Basic stat bonuses (health, damage, speed)
- Linear progression needs
- Predictable growth curves
- Early game boons

#### Use MORE (Multiplicative) For:
- Powerful late-game scaling
- Compound effects
- Build-defining boons
- Risk/reward mechanics

### Balance Examples

```gdscript
# Health Boon: +10 HP (Increased)
# Common: +10 HP
# Magic:  +20 HP  
# Rare:   +30 HP
# Epic:   +40 HP
# Result: Linear, predictable growth

# AoE Boon: 5% MORE (Multiplicative)
# Common: x1.05
# Magic:  x1.10
# Rare:   x1.15
# Epic:   x1.20
# 3 Epic stacks: 1.2 × 1.2 × 1.2 = 1.728 (72.8% increase!)
```

### Testing Balance

Always test at Common rarity first:

```gdscript
# Quick balance test
func test_boon_scaling():
    var base_value = 10.0
    print("Testing boon with base value: ", base_value)
    print("Common: ", base_value * 1.0)
    print("Magic: ", base_value * 2.0)
    print("Rare: ", base_value * 3.0)
    print("Epic: ", base_value * 4.0)
```

## Best Practices

### 1. Use Clear Naming

```gdscript
# GOOD
id = "movement_speed"
display_name = "Swift Feet"

# BAD
id = "spd"
display_name = "Fast"
```

### 2. Write Descriptive Descriptions

```gdscript
func get_formatted_description() -> String:
    var value = get_effective_power(0.1)
    # GOOD - Clear and specific
    return "Increases movement speed by %.0f%%" % (value * 100)
    
    # BAD - Vague
    return "Move faster"
```

### 3. Always Scale Values

```gdscript
# GOOD - Uses rarity scaling
var bonus = get_effective_power(5.0)

# BAD - Hardcoded value
var bonus = 5.0  # Ignores rarity!
```

### 4. Validate Entity Type

```gdscript
func _on_apply(entity: BaseEntity) -> void:
    # GOOD - Type check
    if entity is Player:
        var player = entity as Player
        # Apply effect
    
    # BAD - Assumes entity type
    entity.player_specific_method()  # Might crash!
```

### 5. Print Debug Info

```gdscript
func _on_apply(entity: BaseEntity) -> void:
    # Always print what happened
    print("🎯 %s gained %s: +%.0f damage!" % [
        entity.name, 
        display_name,
        get_effective_power(10.0)
    ])
```

### 6. Handle Edge Cases

```gdscript
func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        
        # Check if weapon exists
        var weapon = player.get_primary_weapon()
        if not weapon:
            push_warning("No weapon found for " + display_name)
            return
        
        # Check if weapon has required tag
        if not "Sword" in weapon.get_weapon_tags():
            push_warning("Weapon is not a sword for " + display_name)
            return
        
        # Apply effect
        weapon.modify_something()
```

### 7. Consider Stacking

```gdscript
# For percentage multipliers
func _on_apply(entity: BaseEntity) -> void:
    # MORE scaling (multiplicative)
    entity.stat *= (1.0 + get_effective_power(0.05))
    
    # Increased scaling (additive)
    entity.stat_bonus += get_effective_power(5.0)
```

## Examples

### Example 1: Attack Speed Boon

```gdscript
extends BaseBoon
class_name AttackSpeedBoon

func _init():
    id = "attack_speed"
    display_name = "Fury"
    base_type = "attack_speed"
    icon_color = Color(1, 0.5, 0)  # Orange

func get_formatted_description() -> String:
    var value = get_effective_power(0.1)  # 10% base
    return "+%.0f%% Attack Speed" % (value * 100)

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var weapon = player.get_primary_weapon()
        if weapon:
            var speed_bonus = get_effective_power(0.1)
            # Assuming weapon has attack speed multiplier
            weapon.attack_speed_multiplier *= (1.0 + speed_bonus)
            print("⚔️ %s attacks %.0f%% faster!" % [player.name, speed_bonus * 100])
```

### Example 2: Lifesteal Boon

```gdscript
extends BaseBoon
class_name LifestealBoon

func _init():
    id = "lifesteal"
    display_name = "Vampiric Strike"
    base_type = "unique"
    icon_color = Color(0.8, 0, 0)  # Dark red

func get_formatted_description() -> String:
    var value = get_effective_power(0.02)  # 2% base
    return "Heal for %.0f%% of damage dealt" % (value * 100)

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        var lifesteal_percent = get_effective_power(0.02)
        
        # Add to player's lifesteal stat
        if "lifesteal_percent" in player:
            player.lifesteal_percent += lifesteal_percent
        else:
            player.set("lifesteal_percent", lifesteal_percent)
        
        print("🩸 %s gained %.0f%% lifesteal!" % [player.name, lifesteal_percent * 100])
```

### Example 3: Unique Mechanic Boon

```gdscript
extends BaseBoon
class_name BerserkBoon

func _init():
    id = "berserk"
    display_name = "Berserker Rage"
    base_type = "unique"
    icon_color = Color(1, 0, 0)  # Red
    is_repeatable = false

func get_formatted_description() -> String:
    return "Gain 50% attack speed but lose 2 HP per second. Fury comes at a price!"

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        
        # Apply attack speed bonus
        var weapon = player.get_primary_weapon()
        if weapon:
            weapon.attack_speed_multiplier *= 1.5
        
        # Mark player as berserk for damage over time system
        player.set_meta("is_berserk", true)
        player.set_meta("berserk_damage_per_second", 2.0)
        
        print("🔥 %s entered Berserker Rage! Kill or be killed!" % player.name)
```

## Troubleshooting

### Common Issues

1. **Boon not appearing in selection**
   - Check if added to boon pool in `boon_manager.gd`
   - Verify boon class extends `BaseBoon`
   - Ensure `_init()` sets all required properties

2. **Values not scaling with rarity**
   - Use `get_effective_power()` not raw values
   - Check if rarity is properly assigned
   - Verify power multipliers in `BoonRarity`

3. **Effect not applying**
   - Add debug prints in `_on_apply()`
   - Check entity type validation
   - Verify target stat/property exists

4. **UI showing wrong description**
   - Implement `get_formatted_description()`
   - Return calculated values, not base values
   - Include units (%, points, etc.)

### Debug Tips

Add debug mode to your boon:

```gdscript
const DEBUG = true

func _on_apply(entity: BaseEntity) -> void:
    if DEBUG:
        print("[BOON DEBUG] Applying ", display_name)
        print("[BOON DEBUG] Entity: ", entity.name)
        print("[BOON DEBUG] Rarity: ", rarity.display_name if rarity else "None")
        print("[BOON DEBUG] Base value: ", 10.0)
        print("[BOON DEBUG] Effective value: ", get_effective_power(10.0))
```

Test rarity scaling:

```gdscript
func test_scaling():
    # Temporarily set different rarities
    var rarities = BoonRarity.get_default_rarities()
    for rarity_type in rarities:
        rarity = rarities[rarity_type]
        print("%s: %f" % [rarity.display_name, get_effective_power(10.0)])
```

## Checklist

### New Boon Checklist

- [ ] Created new boon file in `systems/boon_system/boons/`
- [ ] Extended `BaseBoon` class
- [ ] Set unique `id` in `_init()`
- [ ] Set `display_name` (shown in UI)
- [ ] Set `base_type` for categorization
- [ ] Set `icon_color`
- [ ] Set `is_repeatable` if applicable
- [ ] Implemented `get_formatted_description()`
- [ ] Implemented `_on_apply()` method
- [ ] Used `get_effective_power()` for all values
- [ ] Added type checking for entity
- [ ] Added debug print statements
- [ ] Added to appropriate pool in `boon_manager.gd`
- [ ] Tested at different rarities
- [ ] Tested stacking behavior
- [ ] Verified UI display
- [ ] Checked visual effects match rarity

### Balance Checklist

- [ ] Defined base (Common) values
- [ ] Tested Common rarity in isolation
- [ ] Verified scaling feels good at each tier
- [ ] Compared to similar existing boons
- [ ] Tested multiple stacks (if stackable)
- [ ] Considered early vs late game impact
- [ ] Documented scaling type (MORE vs Increased)

## Advanced Topics

### Custom Rarity Effects

Override rarity behavior for special boons:

```gdscript
func get_effective_power(base_value: float) -> float:
    # Custom scaling for this boon only
    if rarity and rarity.type == BoonRarity.Type.EPIC:
        # Epic gives 10x instead of 4x for this boon
        return base_value * 10.0
    # Otherwise use normal scaling
    return super.get_effective_power(base_value)
```

### Conditional Boons

Boons with requirements or conditions:

```gdscript
class_name LowHealthDamageBoon
extends BaseBoon

func _init():
    id = "desperation"
    display_name = "Desperation"
    description = "Deal more damage when below 50% health"

func get_formatted_description() -> String:
    var value = get_effective_power(0.5)  # 50% base
    return "+%.0f%% damage when below half health" % (value * 100)

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        # Store multiplier for damage calculation
        player.set_meta("desperation_multiplier", get_effective_power(0.5))
        # Damage system checks this during calculation
```

### Synergy Systems

Create boons that interact with others:

```gdscript
func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        
        # Check for synergy
        if player.has_meta("has_fire_boon"):
            # Enhanced effect with fire boon
            print("🔥 Synergy detected! Enhanced effect!")
            apply_enhanced_effect(player)
        else:
            apply_normal_effect(player)
        
        # Mark this boon for other synergies
        player.set_meta("has_ice_boon", true)
```

### Dynamic Descriptions

Show different descriptions based on player state:

```gdscript
func get_formatted_description() -> String:
    var base_desc = "+%.0f Base Damage" % get_effective_power(5.0)
    
    # Add context if player already has this boon
    if current_stacks > 0:
        base_desc += " (Stack %d)" % (current_stacks + 1)
    
    return base_desc
```

This guide provides everything needed to create robust, balanced boons that integrate seamlessly with the A.S.S game systems while maintaining the single-source-of-truth philosophy for easy balancing.
