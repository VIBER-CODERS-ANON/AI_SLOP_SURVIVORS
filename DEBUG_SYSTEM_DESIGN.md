# Debug System & Architecture Refactor Design

## Overview

This document outlines a comprehensive debugging system and architectural improvements to make the game more scalable and maintainable. The primary goals are:

1. **Modern Debug Interface**: Replace outdated cheat system with proper debugging tools
2. **Resource-Based Configuration**: Move from hardcoded enemies to .tres resource files
3. **Unified Systems**: Create consistent interfaces while preserving performance optimizations
4. **Scalability**: Make adding new content straightforward and data-driven

## Current Architecture Issues

### Problems to Solve

1. **Hardcoded Enemy Definitions**

   - Enemy stats scattered across multiple files
   - Adding new enemies requires code changes in multiple places
   - No central configuration system

2. **Dual Spawning Systems**

   - Minions: Direct calls to EnemyManager
   - Bosses: Direct calls to BossFactory
   - No unified interface for spawning

3. **Limited Debug Capabilities**

   - Basic keyboard shortcuts only
   - No runtime inspection tools
   - Can't test specific enemy behaviors easily

4. **Ability System Fragmentation**
   - Simple abilities hardcoded in V2AbilityProxy
   - Complex abilities require custom scripts
   - No data-driven ability configuration

## Proposed Architecture

### 1. Resource-Based Enemy System

#### Enemy Resource Structure (.tres files)

```gdscript
# res://resources/enemies/rat_enemy.tres
extends Resource
class_name EnemyResource

@export var enemy_id: String = "rat"
@export var display_name: String = "Rat"
@export var enemy_category: String = "minion" # "minion" or "boss"

# Base Stats
@export var base_health: float = 10.0
@export var base_speed: float = 50.0
@export var base_damage: float = 5.0
@export var base_scale: float = 1.0
@export var xp_value: int = 1
@export var mxp_value: int = 1

# Visual Configuration
@export var sprite_texture: Texture2D
@export var sprite_frames: SpriteFrames  # For animated enemies
@export var multimesh_scene: PackedScene  # For minions
@export var node_scene: PackedScene       # For bosses

# Behavior Configuration
@export var ai_type: String = "basic_chase"  # "basic_chase", "ranged", "complex"
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.0

# Abilities
@export var abilities: Array[AbilityResource] = []
@export var passive_abilities: Array[String] = []

# Special Properties
@export var can_evolve: bool = false
@export var evolution_targets: Array[String] = []
@export var spawn_weight: int = 100  # For ticket system
```

#### Ability Resource Structure

```gdscript
# res://resources/abilities/explode_ability.tres
extends Resource
class_name AbilityResource

@export var ability_id: String = "explode"
@export var display_name: String = "Explode"
@export var cooldown: float = 5.0
@export var damage: float = 20.0
@export var range: float = 100.0
@export var effect_scene: PackedScene
@export var trigger_type: String = "instant"  # "instant", "channeled", "projectile"
@export var custom_script: Script  # For complex abilities
```

### 2. Unified Spawn System

#### SpawnManager (New System)

```gdscript
# systems/core/spawn_manager.gd
extends Node
class_name SpawnManager

static var instance: SpawnManager

# Unified spawn interface
func spawn_entity(enemy_resource: EnemyResource, position: Vector2, owner_username: String = "") -> int:
    match enemy_resource.enemy_category:
        "minion":
            return _spawn_minion(enemy_resource, position, owner_username)
        "boss":
            return _spawn_boss(enemy_resource, position, owner_username)

func _spawn_minion(resource: EnemyResource, position: Vector2, username: String) -> int:
    # Delegate to EnemyManager for array-based handling
    return EnemyManager.instance.spawn_from_resource(resource, position, username)

func _spawn_boss(resource: EnemyResource, position: Vector2, username: String) -> Node:
    # Delegate to BossFactory for node-based handling
    return BossFactory.instance.spawn_from_resource(resource, position, username)
```

### 3. Debug System Design

#### Systems to Remove/Replace

Before implementing the new debug system, the following outdated systems should be removed:

##### Current Cheat System (To Be Removed)

- **CheatManager** (`systems/core/cheat_manager.gd`) - Entire file can be deleted
- **InputManager cheat handling** (`systems/core/input_manager.gd`) - Remove all cheat key bindings:
  - Alt+1-6: Spawn test enemies
  - Alt+7-0: Spawn bosses
  - F1-F3: Grant XP/MXP/Health
  - Ctrl+1-4: God mode, XP, level up, boss vote
- **Mock chat system** in TwitchBot - Should be integrated into debug UI instead

##### Overlapping Debug Features (To Be Consolidated)

- Keyboard shortcuts scattered across multiple files
- Console logging for debug info (replace with UI display)
- Hardcoded test spawn methods in GameController
- Debug flags in various managers

##### Migration Notes

- Keep F12 as the debug mode toggle key
- All other debug functionality moves to the debug UI
- Remove all `print()` debug statements once UI inspection is available
- Consolidate all debug features into DebugManager singleton

#### DebugManager (Core Debug Coordinator)

```gdscript
# systems/debug/debug_manager.gd
extends Node
class_name DebugManager

static var instance: DebugManager

signal debug_mode_toggled(enabled: bool)
signal entity_selected(entity_id: int)
signal entity_inspected(entity_data: Dictionary)

var debug_enabled: bool = false
var selected_entity_id: int = -1
var debug_ui: Control

func toggle_debug_mode():
    debug_enabled = !debug_enabled
    emit_signal("debug_mode_toggled", debug_enabled)

    if debug_enabled:
        _enter_debug_mode()
    else:
        _exit_debug_mode()

func _enter_debug_mode():
    # Disable Twitch spawning
    TicketSpawnManager.instance.set_spawning_enabled(false)

    # Clear all enemies
    EnemyManager.instance.clear_all_enemies()
    BossFactory.instance.clear_all_bosses()

    # Show debug UI
    _show_debug_ui()

func _exit_debug_mode():
    # Re-enable normal systems
    TicketSpawnManager.instance.set_spawning_enabled(true)

    # Hide debug UI
    _hide_debug_ui()
```

#### Debug UI Layout

```
┌─────────────────────────────────────────┐
│ Debug Panel (F12 to toggle)             │
├─────────────────────────────────────────┤
│ Enemy Spawner                           │
│ ┌─────────────────────────────────────┐ │
│ │ [Dropdown: Select Enemy Type]       │ │
│ │ ├─ Minions                         │ │
│ │ │  ├─ Rat                          │ │
│ │ │  ├─ Succubus                     │ │
│ │ │  └─ Woodland Joe                 │ │
│ │ └─ Bosses                          │ │
│ │    ├─ Thor                         │ │
│ │    ├─ Mika                         │ │
│ │    └─ Forsen                       │ │
│ └─────────────────────────────────────┘ │
│ [Spawn at Cursor] [Spawn at Player]     │
│ Count: [1] [5] [10] [100]              │
├─────────────────────────────────────────┤
│ Entity Inspector                        │
│ ┌─────────────────────────────────────┐ │
│ │ Selected: Succubus #42              │ │
│ │ Owner: testuser123                  │ │
│ │ Health: 45/50                       │ │
│ │ Speed: 75                           │ │
│ │ Damage: 10                          │ │
│ │ State: Attacking                    │ │
│ │                                     │ │
│ │ Abilities:                          │ │
│ │ [Trigger Explode] (Ready)           │ │
│ │ [Trigger Suction] (Cooldown: 2.3s) │ │
│ │ [Trigger Boost] (Ready)             │ │
│ └─────────────────────────────────────┘ │
│ [Kill Selected] [Heal Full] [Damage 10] │
├─────────────────────────────────────────┤
│ System Controls                         │
│ □ Pause AI                             │
│ □ Show Collision Shapes                │
│ □ Show Pathfinding Grid                │
│ □ Show Performance Stats               │
│ [Clear All Enemies] [Reset Session]    │
└─────────────────────────────────────────┘
```

### 4. Affected Systems & Migration Plan

#### Systems Requiring Updates

1. **EnemyManager**

   - Add `spawn_from_resource()` method
   - Update to read from EnemyResource instead of hardcoded values
   - Maintain backward compatibility during transition

2. **BossFactory**

   - Add `spawn_from_resource()` method
   - Migrate BOSS_CONFIGS to resource files
   - Update boss scripts to read from resources

3. **EnemyConfigManager**

   - Deprecate in favor of resource system
   - Create migration tool to convert existing configs

4. **Evolution System**

   - Update to use resource evolution_targets
   - Make evolution paths data-driven

5. **CommandProcessor**

   - Update spawn commands to use SpawnManager
   - Add debug command support

6. **TicketSpawnManager**
   - Update to use resource spawn_weights
   - Integrate with SpawnManager

#### Migration Strategy

**Phase 1: Foundation**

- Create resource classes (EnemyResource, AbilityResource)
- Build SpawnManager with dual delegation
- Implement DebugManager core functionality

**Phase 2: Resource Migration**

- Convert existing enemies to .tres files
- Create resource loader/cache system
- Update EnemyManager to support resources

**Phase 3: Debug UI**

- Build debug panel UI scene
- Implement entity selection/inspection
- Add ability triggering system

**Phase 4: Integration**

- Update all systems to use SpawnManager
- Deprecate old spawning methods
- Full testing and polish

### 5. Implementation Details

#### Enemy Selection System

```gdscript
# systems/debug/entity_selector.gd
extends Node
class_name EntitySelector

func get_entity_at_position(world_pos: Vector2) -> Dictionary:
    # Check minions first (array-based)
    var minion_id = EnemyManager.instance.get_enemy_at_position(world_pos)
    if minion_id >= 0:
        return {
            "type": "minion",
            "id": minion_id,
            "data": EnemyManager.instance.get_enemy_data(minion_id)
        }

    # Check bosses (node-based)
    var boss = BossFactory.instance.get_boss_at_position(world_pos)
    if boss:
        return {
            "type": "boss",
            "node": boss,
            "data": boss.get_debug_data()
        }

    return {}
```

#### Ability Triggering

```gdscript
# systems/debug/debug_ability_trigger.gd
extends Node
class_name DebugAbilityTrigger

func trigger_ability(entity_data: Dictionary, ability_name: String):
    match entity_data.type:
        "minion":
            V2AbilityProxy.instance.force_execute_ability(entity_data.id, ability_name)
        "boss":
            if entity_data.node.has_method("force_trigger_ability"):
                entity_data.node.force_trigger_ability(ability_name)
```

### 6. Benefits of This Architecture

#### For Development

- **Easy Content Addition**: Just create a new .tres file
- **Visual Editing**: Use Godot's inspector to tweak values
- **Hot Reload**: Change resources without recompiling
- **Version Control**: Resources diff better than code

#### For Testing

- **Isolated Testing**: Test specific enemies/abilities
- **State Inspection**: See exactly what's happening
- **Reproducible Scenarios**: Save/load test configurations
- **Performance Analysis**: Identify bottlenecks easily

#### For Performance

- **Preserved Optimization**: Dual system remains intact
- **Lazy Loading**: Load resources on demand
- **Efficient Caching**: Resource system handles caching
- **No Runtime Overhead**: Debug features compile out in release

### 7. Example Resource Files

#### Rat Enemy Resource

```gdscript
# res://resources/enemies/minions/rat.tres
[gd_resource type="Resource" script_class="EnemyResource"]

[resource]
enemy_id = "rat"
display_name = "Rat"
enemy_category = "minion"
base_health = 10.0
base_speed = 50.0
base_damage = 5.0
base_scale = 0.8
xp_value = 1
mxp_value = 1
sprite_texture = preload("res://sprites/enemies/rat.png")
ai_type = "basic_chase"
attack_range = 30.0
attack_cooldown = 1.0
spawn_weight = 100
```

#### Thor Boss Resource

```gdscript
# res://resources/enemies/bosses/thor.tres
[gd_resource type="Resource" script_class="EnemyResource"]

[resource]
enemy_id = "thor"
display_name = "Thor the Coward"
enemy_category = "boss"
base_health = 500.0
base_speed = 40.0
base_damage = 25.0
base_scale = 2.0
xp_value = 50
mxp_value = 10
node_scene = preload("res://entities/enemies/bosses/thor_boss.tscn")
ai_type = "complex"
attack_range = 50.0
attack_cooldown = 2.0
abilities = [
    preload("res://resources/abilities/hammer_smash.tres"),
    preload("res://resources/abilities/lightning_strike.tres")
]
```

### 8. Debug Mode Workflow

1. **Press F12** to enter debug mode
2. **All enemies cleared**, Twitch spawning disabled
3. **Select enemy type** from dropdown
4. **Click to spawn** at cursor position
5. **Click enemy** to select and inspect
6. **Trigger abilities** manually for testing
7. **Monitor stats** in real-time
8. **Press F12** again to exit debug mode

### 9. Future Enhancements

- **Save/Load Test Scenarios**: Export current state for reproduction
- **Replay System**: Record and replay entity behaviors
- **Visual Scripting**: Node-based ability creation
- **Mod Support**: Allow community content via resources
- **A/B Testing**: Compare different stat configurations
- **Automated Testing**: Use debug system for integration tests

## Implementation Priority

1. **Critical** (Do First)

   - DebugManager core
   - Resource classes
   - SpawnManager interface

2. **High** (Core Functionality)

   - Debug UI panel
   - Entity selection/inspection
   - Resource migration for existing enemies

3. **Medium** (Enhanced Features)

   - Ability triggering system
   - Performance monitoring
   - Visual debug overlays

4. **Low** (Nice to Have)
   - Save/load scenarios
   - Automated testing integration
   - Advanced profiling tools

## Conclusion

This architecture provides:

- **Clean separation** between debug and production code
- **Scalable system** for adding new content
- **Powerful debugging** tools for development
- **Minimal disruption** to existing systems
- **Future-proof** foundation for enhancements

The dual approach (arrays for minions, nodes for bosses) is preserved as it's a smart optimization. The new systems simply provide better interfaces and tooling around these core implementations.
