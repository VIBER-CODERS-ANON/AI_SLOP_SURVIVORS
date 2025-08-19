# Modular Ability System

This is a fully modular, OOP-based ability system that allows any entity to use any ability. Abilities are self-contained modules that can be plugged into any entity (player, NPC, enemy, or even items).

## Core Components

### 1. **IAbility** (Interface)
Defines what every ability must implement. Use `BaseAbility` instead of implementing this directly.

### 2. **IAbilityHolder** (Interface) 
Defines what an entity needs to provide to use abilities (stats, resources, etc).

### 3. **BaseAbility** (Base Class)
Extend this for all abilities. Provides common functionality like cooldowns, resource costs, and targeting.

### 4. **AbilityManager** (Component)
Add this to any entity to give it the ability to use abilities. Handles execution, cooldowns, and keybinds.

### 5. **AbilityHolderComponent** (Component)
Implements IAbilityHolder interface. Add this to entities alongside AbilityManager.

## Quick Start

### Adding Abilities to an Entity

```gdscript
# In your entity's _ready() function:
func _ready():
    # Option 1: If using BaseEntity (already has ability system)
    var fireball = preload("res://systems/ability_system/abilities/fireball_ability.gd").new()
    add_ability(fireball)
    
    # Option 2: Manual setup for custom entities
    var ability_holder = AbilityHolderComponent.new()
    var ability_manager = AbilityManager.new() 
    add_child(ability_holder)
    add_child(ability_manager)
    
    ability_manager.add_ability(fireball)
```

### Executing Abilities

```gdscript
# By ID
execute_ability("fireball")

# With custom targeting
var target_data = AbilityTargetData.create_enemy_target(enemy)
execute_ability("fireball", target_data)

# Via keybinds (for player)
ability_manager.set_ability_keybind(0, "ability_1")  # Q key
ability_manager.set_ability_keybind(1, "ability_2")  # W key
```

## Creating New Abilities

### Basic Template

```gdscript
extends BaseAbility
class_name MyNewAbility

func _init() -> void:
    # Metadata
    ability_id = "my_ability"
    ability_name = "My Ability"
    ability_description = "Does something cool"
    ability_tags = [AbilityTypes.TAG_SPELL]
    
    # Costs and cooldown
    base_cooldown = 5.0
    resource_costs = {
        AbilityTypes.RESOURCE_MANA: 20
    }
    
    # Targeting
    targeting_type = AbilityTargeting.Type.DIRECTION
    base_range = 500.0

func _execute_ability(holder: IAbilityHolder, target_data: AbilityTargetData) -> void:
    # Your ability logic here
    var damage = get_modified_value(base_damage, AbilityTypes.STAT_SPELL_POWER, holder)
    # Do something with the damage
    
    # Always call these at the end
    _start_cooldown(holder)
    holder.on_ability_executed(self)
    executed.emit(target_data)
```

## Ability Scaling

Abilities automatically scale based on the entity's stats:

```gdscript
# In ability:
var damage = get_modified_value(base_damage, AbilityTypes.STAT_SPELL_POWER, holder)

# Entity with +50% spell power = 150% damage
# Entity with -20% spell power = 80% damage
```

### Common Stats
- `spell_power` - Magical damage scaling
- `physical_power` - Physical damage scaling  
- `healing_power` - Healing amount scaling
- `cooldown_reduction` - Reduces ability cooldowns
- `area_size` - Increases AoE radius
- `cast_speed` - Reduces cast times

## Targeting Types

- **SELF** - Targets the caster
- **TARGET_ENEMY** - Single enemy target
- **TARGET_ALLY** - Single ally target
- **DIRECTION** - Fires in a direction
- **LOCATION** - Ground-targeted
- **AREA_AROUND_SELF** - AoE centered on caster
- **AREA_AT_LOCATION** - AoE at ground location

## Resource Types

- `health` - HP cost (sacrifice)
- `mana` - Mana/MP cost
- `stamina` - Stamina cost
- Custom resources supported

## Example Abilities

### Included Examples:
1. **DashAbility** - Movement ability with collision adjustment
2. **MeleeAttackAbility** - Basic weapon swing with arc detection
3. **FireballAbility** - Projectile spell with explosion
4. **HealAbility** - Self-targeted healing with HoT option
5. **BlinkAbility** - Teleportation with location validation

## Advanced Features

### Channeled Abilities
```gdscript
is_channeled = true
channel_duration = 3.0

func _update_channel(delta: float, holder: IAbilityHolder) -> void:
    # Called every frame during channel
```

### Combo Abilities
```gdscript
ability_type = AbilityTypes.Type.COMBO
# Chain abilities together
```

### Passive Abilities
```gdscript
ability_type = AbilityTypes.Type.PASSIVE

func _on_added(holder: IAbilityHolder) -> void:
    # Apply passive bonuses
```

## Tips

1. **Abilities are Resources** - Save them as .tres files for easy reuse
2. **Use Tags** - Tag abilities for buff interactions (e.g., "Fire" abilities get bonuses from fire buffs)
3. **Check Requirements** - Override `_check_requirements()` for custom conditions
4. **Visual Feedback** - Always add particles/sounds for better game feel
5. **Modular Effects** - Create reusable effect scenes abilities can spawn

## Integration with Existing Systems

The ability system integrates with:
- **Tag System** - Abilities can have tags, check entity tags
- **Buff System** - Buffs can modify ability stats
- **Movement System** - Abilities can modify or override movement
- **Combat System** - Abilities trigger damage calculations

## Performance Notes

- Abilities update only when active (casting/cooldown)
- Target validation is lightweight
- Particle effects auto-cleanup
- No hardcoded references - fully modular
