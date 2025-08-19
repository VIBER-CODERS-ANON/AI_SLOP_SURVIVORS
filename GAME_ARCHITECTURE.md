# A.S.S (AI SLOP SURVIVORS) - Game Architecture

## Overview
This is a modular Vampire Survivors-style game with Twitch chat integration built in Godot 4.x. The architecture is designed to be extensible and maintainable.

## Core Systems

### 1. Tag System (`systems/tag_system/`)
The universal tagging system allows dynamic interactions between all game elements.

**Key Components:**
- `TagSystem`: Static utility class for tag operations
- `Taggable`: Component that can be added to any node to make it taggable

**Example Tags:**
- Entity Types: `Player`, `Enemy`, `Boss`, `Minion`
- Damage Types: `Physical`, `Magical`, `Fire`, `Ice`
- Ability Types: `Melee`, `Ranged`, `Projectile`, `AoE`

**Usage Example:**
```gdscript
# Check if entity is a boss
if TagSystem.has_tag(enemy, "Boss"):
    damage *= 1.5  # Deal 50% more damage to bosses

# Get all flying enemies
var flying_enemies = TagSystem.get_tagged_in_group("enemies", "Flying")
```

### 2. Entity System (`systems/entity_system/`)
Base class for all game entities with health, movement, and damage handling.

**BaseEntity Features:**
- Health management
- Movement velocity system
- Status effects
- Tag integration
- Damage calculations with tag modifiers

### 3. Movement System (`systems/movement_system/`)
Modular movement controllers that can be attached to entities.

**Controllers:**
- `MovementController`: Base class for all movement
- `PlayerMovementController`: WASD input handling

## Adding New Features

### Creating a New Enemy
1. Create a new script extending `BaseEntity`:
```gdscript
extends BaseEntity
class_name Zombie

func _entity_ready():
    # Set enemy-specific tags
    taggable.permanent_tags = ["Enemy", "Undead", "Ground"]
    
    # Set stats
    max_health = 50
    move_speed = 150
    
    # Add AI movement controller
    var ai_controller = AIMovementController.new()
    add_child(ai_controller)
```

### Creating a New Ability
1. Create ability script in `abilities/` folder:
```gdscript
extends Node
class_name FireballAbility

@export var damage: float = 20.0
@export var cooldown: float = 1.0

var owner_entity: BaseEntity

func activate():
    # Spawn fireball projectile
    # Apply "Fire" and "Projectile" tags to the projectile
```

### Creating a New Buff
1. Create buff script in `buffs/` folder:
```gdscript
extends Node
class_name DamageVsBossesBuff

@export var damage_multiplier: float = 1.5

func apply_to_entity(entity: BaseEntity):
    # Add damage modifier for attacks against "Boss" tagged enemies
```

## Twitch Chat Integration

### Current Features
- Anonymous connection to quin69's channel
- Chat display in top-right corner
- Basic chat commands affect gameplay:
  - "heal" - Heals player for 5 HP
  - "damage" - Damages player for 5 HP
  - quin69 messages - Heal player for 10 HP

### Adding Chat Interactions
In `game_controller.gd`, modify `_handle_chat_message()`:
```gdscript
# Example: Spawn enemy when someone says "spawn"
if "spawn" in msg_lower:
    spawn_enemy_at_random_position()
    chat_display.add_message("System", "%s spawned an enemy!" % username, Color.ORANGE)
```

## Project Structure
```
AI SLOP SURVIVORS/
├── systems/              # Core game systems
│   ├── tag_system/      # Universal tagging
│   ├── entity_system/   # Base entity classes
│   ├── ability_system/  # Ability framework
│   ├── buff_system/     # Buff/debuff system
│   └── movement_system/ # Movement controllers
├── entities/            # Game entities
│   ├── player/         # Player character
│   └── enemies/        # Enemy types
├── abilities/          # Player abilities
├── buffs/             # Buffs and debuffs
├── ui/                # User interface
│   └── chat/          # Twitch chat display
└── addons/            # Third-party addons
    └── gift/          # Twitch integration

```

## Best Practices

1. **Always use tags** for entity interactions
2. **Extend base classes** instead of creating from scratch
3. **Keep systems modular** - one responsibility per system
4. **Use signals** for decoupled communication
5. **Add new features incrementally** without breaking existing ones

## Next Steps

1. **Add Enemies**: Create enemy spawning system and AI
2. **Add Abilities**: Implement player abilities with cooldowns
3. **Add Pickups**: Experience orbs, health pickups, etc.
4. **Add Buff System**: Temporary and permanent upgrades
5. **Add Wave System**: Progressive difficulty
6. **Add More Chat Integration**: Let chat vote on upgrades, spawn bosses, etc.



