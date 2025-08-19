# Boon System Quick Reference

## Essential Code Patterns

### Basic Boon Structure
```gdscript
extends BaseBoon

func _init():
    id = "unique_id"
    display_name = "Display Name"
    base_type = "category"
    icon_color = Color(1, 0, 0)
    is_repeatable = true  # or false

func get_formatted_description() -> String:
    var value = get_effective_power(BASE_VALUE)
    return "Description with %.0f value" % value

func _on_apply(entity: BaseEntity) -> void:
    if entity is Player:
        var player = entity as Player
        # Apply effect
```

### Always Use Rarity Scaling
```gdscript
# CORRECT - Scales with rarity
var bonus = get_effective_power(10.0)

# WRONG - Ignores rarity
var bonus = 10.0
```

### Type Checking Pattern
```gdscript
func _on_apply(entity: BaseEntity) -> void:
    if not entity is Player:
        push_warning("Boon applied to non-player")
        return
    
    var player = entity as Player
    # Safe to use player methods
```

### Weapon Modifier Pattern
```gdscript
var weapon = player.get_primary_weapon()
if weapon and "Sword" in weapon.get_weapon_tags():
    weapon.add_arc_degrees(get_effective_power(25.0))
```

## Rarity System

| Rarity | Multiplier | Color | Tickets | Code |
|--------|------------|-------|---------|------|
| Common | 1.0x | Light Grey | 100 | `Color(0.8, 0.8, 0.8)` |
| Magic | 2.0x | Soft Blue | 25 | `Color(0.4, 0.6, 1.0)` |
| Rare | 3.0x | Soft Yellow | 10 | `Color(1.0, 0.9, 0.3)` |
| Epic | 4.0x | Vibrant Purple | 5 | `Color(0.7, 0.3, 1.0)` |
| Unique | Custom | Orange | 10 | `Color(1.0, 0.6, 0.2)` |

## Scaling Types

### MORE (Multiplicative)
```gdscript
# Compounds with each stack
player.stat *= (1.0 + get_effective_power(0.05))
# 3 stacks of 5%: 1.05 × 1.05 × 1.05 = 1.157 (15.7% total)
```

### Increased (Additive)
```gdscript
# Adds together before applying
player.stat_bonus += get_effective_power(0.05)
# 3 stacks of 5%: 5% + 5% + 5% = 15% total
```

## Common Base Values

### Stat Boons
```gdscript
Health: 10.0          # +10 HP at Common
Damage: 1.0 - 5.0     # Depends on attack speed
Speed: 10.0 - 20.0    # Movement units
Defense: 1.0 - 5.0    # Flat or percentage
Regen: 0.5 - 2.0      # HP per second
```

### Percentage Boons
```gdscript
Crit Chance: 0.05     # 5% base
Attack Speed: 0.1     # 10% base
Area Effect: 0.05     # 5% MORE base
Move Speed: 0.1       # 10% increased base
```

### Weapon Modifiers
```gdscript
Arc Angle: 25.0       # +25° per stack
Extra Strikes: 1      # +1 hit
Pierce Count: 1       # +1 enemy
Projectiles: 1        # +1 projectile
```

## Debug Print Patterns

### Basic Confirmation
```gdscript
print("✨ %s gained %s!" % [player.name, display_name])
```

### With Values
```gdscript
print("📈 %s gained %s: +%.0f damage!" % [
    player.name, 
    display_name, 
    bonus_value
])
```

### Stack Information
```gdscript
print("🔷 %s gained %s! (Stack %d)" % [
    player.name,
    display_name,
    current_stacks + 1
])
```

## Common Emojis

```gdscript
✨ - General boon
📈 - Stat increase
💪 - Damage/Strength
❤️ - Health
⚡ - Speed/Energy
🎯 - Critical/Precision
🗡️ - Weapon modifier
🌟 - Unique boon
🔷 - Stackable
💀 - Risk/Drawback
🩸 - Vampiric/Blood
🔥 - Fire/Rage
❄️ - Ice/Slow
```

## Boon Categories

### base_type Values
```gdscript
"health"           # Health increases
"damage"           # Damage boosts
"defense"          # Defense/resistance
"utility"          # Speed, pickup range
"critical"         # Crit chance/damage
"weapon_modifier"  # Weapon-specific
"unique"           # Special mechanics
```

## Meta Properties

### Setting Meta Data
```gdscript
# For unique mechanics
player.set_meta("property_name", value)
player.set_meta("is_vampiric", true)
player.set_meta("vampiric_heal_percent", 0.1)
```

### Checking Meta Data
```gdscript
if player.has_meta("property_name"):
    var value = player.get_meta("property_name")
```

### Removing Meta Data
```gdscript
player.remove_meta("property_name")
```

## Weapon Tag Checking

### Single Tag
```gdscript
if "Sword" in weapon.get_weapon_tags():
    # Apply sword-specific effect
```

### Multiple Tags
```gdscript
var tags = weapon.get_weapon_tags()
if "Ranged" in tags or "Projectile" in tags:
    # Apply to ranged weapons
```

## Pool Management

### Adding to Common Pool
```gdscript
# In boon_manager.gd
common_boons = [
    # ... existing boons ...
    preload("res://systems/boon_system/boons/your_boon.gd").new(),
]
```

### Adding to Unique Pool
```gdscript
unique_boons = [
    # ... existing boons ...
    preload("res://systems/boon_system/boons/your_unique.gd").new(),
]
```

## Testing Commands

### Quick Rarity Test
```gdscript
func test_rarity_scaling():
    var base = 10.0
    var rarities = BoonRarity.get_default_rarities()
    for type in rarities:
        rarity = rarities[type]
        print("%s: %f" % [
            rarity.display_name,
            get_effective_power(base)
        ])
```

### Force Specific Rarity
```gdscript
# In boon_manager for testing
func force_rarity_test(rarity_type: BoonRarity.Type):
    var boon = my_boon.new()
    boon.rarity = rarities[rarity_type]
    apply_boon(boon, player)
```

## Common Pitfalls

### ❌ Wrong
```gdscript
# Hardcoded value
player.damage += 10

# No type check
entity.player_only_method()

# Wrong scaling
player.stat += get_effective_power(0.05)  # Should be *= for MORE
```

### ✅ Correct
```gdscript
# Scaled value
player.damage += get_effective_power(10.0)

# Type checked
if entity is Player:
    entity.player_only_method()

# Correct MORE scaling
player.stat *= (1.0 + get_effective_power(0.05))
```

## Balance Quick Formulas

### Stack Calculations

**MORE Stacking:**
```
Final = Base × (1 + bonus)^stacks
5% MORE, 3 stacks: 1.05^3 = 1.157
```

**Increased Stacking:**
```
Final = Base × (1 + bonus × stacks)
5% Increased, 3 stacks: 1 + (0.05 × 3) = 1.15
```

### Breakpoints

**Attack Speed:** Don't exceed 200% (animation breaks)
**Movement Speed:** Cap around 200% (control issues)
**Crit Chance:** Cap at 100% (1.0)
**Area of Effect:** Visual limits around 300%

## Unique Boon Patterns

### Risk/Reward
```gdscript
# Benefit
weapon.base_damage *= 2.0

# Drawback
player.max_health *= 0.5
```

### Conditional Power
```gdscript
player.set_meta("rage_threshold", 0.3)  # 30% HP
player.set_meta("rage_bonus", 0.5)      # 50% attack speed
# Combat system checks these
```

### Toggle Effects
```gdscript
player.set_meta("mode_active", true)
player.set_meta("mode_type", "defensive")
# Systems check and apply effects
```

## Quick Decision Tree

1. **What type of boon?**
   - Stat increase → Stat template
   - Percentage modifier → Percentage template
   - Weapon-specific → Weapon modifier template
   - Game-changing → Unique template

2. **How should it scale?**
   - Linear growth → Increased (additive)
   - Exponential growth → MORE (multiplicative)
   - Custom mechanics → Unique (no standard scaling)

3. **Which pool?**
   - Standard upgrades → Common pool
   - Special mechanics → Unique pool

4. **Can it stack?**
   - Most boons → Yes (`is_repeatable = true`)
   - Game-changing uniques → No (`is_repeatable = false`)
   - Special stackables → Yes with patterns
