# Refined Architecture Plan

## Problem Definition

After reviewing the codebase, the core issues are:

### 1. **Scalability Problem**
- **Current**: All enemies hardcoded in `EnemyConfigManager` dictionaries
- **Issue**: Adding enemies requires code changes in 3+ files
- **Solution**: Resource-based (.tres) enemy definitions

### 2. **Ability System Problem**
- **Current**: Abilities hardcoded in `EnemyBridge` with 649-line switch statements
- **Issue**: Adding abilities requires modifying core bridge code
- **Solution**: Modular ability resources that any enemy can use

### 3. **Debug/Testing Problem**
- **Current**: Basic keyboard shortcuts (Alt+1 spawns rats, etc.)
- **Issue**: Can't inspect state, trigger abilities, or test specific scenarios
- **Solution**: Comprehensive debug UI with inspection and control

## Proposed Solution

### Phase 1: Resource-Based Enemy System

#### Enemy Resource (.tres)
```gdscript
# res://resources/enemies/rat.tres
extends Resource
class_name EnemyResource

@export var enemy_id: String = "rat"
@export var display_name: String = "Rat"
@export var spawn_type: String = "multimesh"  # "multimesh" or "node"

# Stats
@export var health: float = 10.0
@export var speed: float = 80.0
@export var damage: float = 1.0
@export var scale: float = 1.6
@export var xp_value: int = 1

# Abilities (array of AbilityResource)
@export var abilities: Array[Resource] = []

# Visual
@export var texture: Texture2D
@export var mesh_scene: PackedScene  # For multimesh
@export var node_scene: PackedScene  # For node-based

# Spawning
@export var spawn_weight: int = 100  # For ticket system
```

#### Ability Resource (.tres)
```gdscript
# res://resources/abilities/explode.tres
extends Resource
class_name AbilityResource

@export var ability_id: String = "explode"
@export var display_name: String = "Explode"
@export var ability_type: String = "instant"  # "instant", "projectile", "channel", "aura"

# Trigger conditions
@export var trigger_mode: String = "manual"  # "manual", "on_death", "on_spawn", "proximity"
@export var trigger_range: float = 0.0
@export var trigger_chance: float = 1.0

# Core stats
@export var damage: float = 20.0
@export var range: float = 80.0
@export var cooldown: float = 5.0

# Effects
@export var effect_scene: PackedScene
@export var projectile_scene: PackedScene
@export var sound: AudioStream

# Modifiers (affected by player upgrades)
@export var scales_with_aoe: bool = true
@export var scales_with_damage: bool = true
```

### Phase 2: Unified Spawn System

#### SpawnManager (New)
```gdscript
extends Node
class_name SpawnManager

static var instance: SpawnManager

# Resource cache
var enemy_resources: Dictionary = {}  # id -> EnemyResource
var ability_resources: Dictionary = {}  # id -> AbilityResource

func _ready():
    _load_all_resources()

func spawn_enemy(resource_id: String, position: Vector2, owner: String = "") -> int:
    var resource = enemy_resources.get(resource_id)
    if not resource:
        push_error("Unknown enemy: " + resource_id)
        return -1
    
    match resource.spawn_type:
        "multimesh":
            return _spawn_multimesh_enemy(resource, position, owner)
        "node":
            return _spawn_node_enemy(resource, position, owner)

func _spawn_multimesh_enemy(resource: EnemyResource, pos: Vector2, owner: String) -> int:
    # Delegate to EnemyManager but with resource data
    var id = EnemyManager.instance.get_next_free_id()
    
    # Apply resource stats
    EnemyManager.instance.positions[id] = pos
    EnemyManager.instance.healths[id] = resource.health
    EnemyManager.instance.max_healths[id] = resource.health
    EnemyManager.instance.move_speeds[id] = resource.speed
    EnemyManager.instance.attack_damages[id] = resource.damage
    EnemyManager.instance.scales[id] = resource.scale
    EnemyManager.instance.chatter_usernames[id] = owner
    
    # Register abilities
    for ability_res in resource.abilities:
        AbilityManager.instance.register_entity_ability(id, ability_res)
    
    return id

func _spawn_node_enemy(resource: EnemyResource, pos: Vector2, owner: String) -> Node:
    # Delegate to BossFactory but with resource data
    var instance = resource.node_scene.instantiate()
    instance.global_position = pos
    instance.enemy_resource = resource
    instance.owner_username = owner
    
    # Let the node initialize itself from resource
    GameController.instance.add_child(instance)
    return instance
```

### Phase 3: Modular Ability System

#### AbilityExecutor (New)
```gdscript
extends Node
class_name AbilityExecutor

static var instance: AbilityExecutor

func execute_ability(entity_id: int, ability_res: AbilityResource, target_data: Dictionary = {}):
    # Check cooldown
    if not _check_cooldown(entity_id, ability_res.ability_id):
        return
    
    # Execute based on type
    match ability_res.ability_type:
        "instant":
            _execute_instant(entity_id, ability_res, target_data)
        "projectile":
            _execute_projectile(entity_id, ability_res, target_data)
        "channel":
            _execute_channel(entity_id, ability_res, target_data)
        "aura":
            _execute_aura(entity_id, ability_res, target_data)
    
    # Set cooldown
    _set_cooldown(entity_id, ability_res.ability_id, ability_res.cooldown)

func _execute_instant(entity_id: int, ability: AbilityResource, _target_data: Dictionary):
    var pos = _get_entity_position(entity_id)
    
    # Spawn effect
    if ability.effect_scene:
        var effect = ability.effect_scene.instantiate()
        effect.global_position = pos
        
        # Apply scaling
        if ability.scales_with_aoe:
            var aoe_scale = _get_entity_aoe_scale(entity_id)
            effect.scale *= aoe_scale
        
        if ability.scales_with_damage:
            var damage_mult = _get_entity_damage_mult(entity_id)
            if effect.has_property("damage"):
                effect.damage = ability.damage * damage_mult
        
        GameController.instance.add_child(effect)
    
    # Play sound
    if ability.sound:
        AudioManager.play_sound_at(ability.sound, pos)
```

### Phase 4: Debug System

#### DebugUI Structure
```
┌─────────────────────────────────────────────┐
│ Debug Mode (F12)                            │
├─────────────────────────────────────────────┤
│ [Enemy Spawner]                             │
│ Enemy: [Dropdown: All loaded .tres files]   │
│ [Spawn at Cursor] [Spawn at Player]        │
│ Count: [1] [10] [100]                      │
├─────────────────────────────────────────────┤
│ [Inspector] - Click enemy to select         │
│ Selected: Succubus #42                      │
│ Owner: testuser123                          │
│ Health: 45/50 [Set: ___] [Kill]            │
│ Speed: 180 [Set: ___]                      │
│ Damage: 10 [Set: ___]                      │
│                                             │
│ Abilities:                                  │
│ • Suction (Ready) [Trigger]                │
│ • Heart Projectile (CD: 1.2s) [Trigger]    │
│ • Explode (Ready) [Trigger]                │
├─────────────────────────────────────────────┤
│ [System]                                    │
│ □ Disable Twitch Spawning                  │
│ □ Show Collision Shapes                    │
│ □ Show Flow Field                          │
│ □ Show Performance Stats                   │
│ [Clear All] [Reload Resources]             │
└─────────────────────────────────────────────┘
```

#### DebugManager
```gdscript
extends Node
class_name DebugManager

static var instance: DebugManager

var debug_ui: Control
var selected_entity_id: int = -1
var is_debug_mode: bool = false

func toggle_debug_mode():
    is_debug_mode = !is_debug_mode
    
    if is_debug_mode:
        # Disable normal spawning
        TicketSpawnManager.instance.enabled = false
        
        # Show debug UI
        _show_debug_ui()
        
        # Enable click selection
        _enable_entity_selection()
    else:
        # Re-enable normal systems
        TicketSpawnManager.instance.enabled = true
        
        # Hide debug UI
        _hide_debug_ui()

func _on_entity_clicked(entity_id: int):
    selected_entity_id = entity_id
    _update_inspector()

func _update_inspector():
    if selected_entity_id < 0:
        return
    
    # Get entity data
    var data = _get_entity_data(selected_entity_id)
    
    # Update UI
    debug_ui.get_node("Inspector/Name").text = data.name
    debug_ui.get_node("Inspector/Health").text = "%d/%d" % [data.health, data.max_health]
    debug_ui.get_node("Inspector/Speed").text = str(data.speed)
    
    # Update abilities
    var ability_list = debug_ui.get_node("Inspector/Abilities")
    ability_list.clear()
    for ability in data.abilities:
        var item = ability_list.add_item(ability.name)
        item.set_meta("ability_id", ability.id)

func trigger_selected_ability(ability_id: String):
    if selected_entity_id < 0:
        return
    
    var ability_res = SpawnManager.instance.ability_resources.get(ability_id)
    if ability_res:
        AbilityExecutor.instance.execute_ability(selected_entity_id, ability_res, {})
```

## Migration Path

### Step 1: Create Resource Classes (Week 1)
1. Create `EnemyResource` and `AbilityResource` classes
2. Convert existing enemies to .tres files
3. Create resource loading system

### Step 2: Build Core Systems (Week 1-2)
1. Implement `SpawnManager` with dual delegation
2. Create `AbilityExecutor` for modular abilities
3. Update `EnemyManager` to work with resources

### Step 3: Debug System (Week 2-3)
1. Build debug UI scene
2. Implement `DebugManager`
3. Add entity selection and inspection
4. Add ability triggering

### Step 4: Integration (Week 3-4)
1. Update `CommandProcessor` to use new systems
2. Migrate `EnemyBridge` functionality to `AbilityExecutor`
3. Update evolution system to use resources
4. Full testing

## Benefits

### For Development
- **Add enemies**: Create a .tres file, no code changes
- **Add abilities**: Create a .tres file, works on any enemy
- **Test easily**: Debug UI shows everything, trigger anything

### For Performance
- **Preserved**: Dual system (multimesh/node) remains
- **Improved**: Resources cached, less runtime allocation
- **Scalable**: Easy to add pooling, LOD, etc.

### For Maintenance
- **Modular**: Each system has one job
- **Data-driven**: Configuration separate from logic
- **Debuggable**: Full visibility into runtime state

## Example: Adding a New Enemy

### Old Way (Current)
1. Edit `EnemyConfigManager` to add dictionary entry
2. Edit `EnemyBridge` to add ability handling
3. Edit `EnemyManager` to add type constant
4. Create texture/mesh files
5. Test with keyboard shortcuts

### New Way (Proposed)
1. Create `zombie.tres` with stats and abilities
2. Drop in `res://resources/enemies/` folder
3. Done - appears in debug UI, spawn system, everything

## Example: Adding a New Ability

### Old Way (Current)
1. Edit `EnemyBridge._execute_ability()` switch statement
2. Add ability config in `EnemyConfigManager`
3. Create effect scene
4. Add to specific enemy types

### New Way (Proposed)
1. Create `lightning_strike.tres` with parameters
2. Add to any enemy's ability array
3. Done - works automatically

## Redundancies Found in Current Codebase

### IMPORTANT: Consult before making changes
**⚠️ Always confirm with the developer which system to keep before removing any redundancies to ensure the correct implementation is preserved.**

### 1. **Multiple Ability Systems**
- **KEEP:** `ability_system/` - Modern modular system with `BaseAbility`
- **REMOVE:** 
  - `EnemyBridge` ability execution (649-line switch statements)
  - `V2AbilityProxy` ability bridging
  - Duplicate abilities (e.g., `suction_ability.gd` vs `suction_ability_v2.gd`)

### 2. **Multiple Movement Controllers**
- **KEEP:** To be determined - consult which movement system works best
- **REDUNDANT:**
  - `ai_movement_controller.gd`
  - `simple_ai_movement_controller.gd`
  - `proper_ai_movement_controller.gd`
  - `zombie_movement_controller.gd`
  - Movement logic in `EnemyManager`

### 3. **Boss Configuration Systems**
- **KEEP:** Convert to resource-based system
- **REMOVE:**
  - `boss_spawner/BossConfig` (convert to .tres)
  - `BossFactory.BOSS_CONFIGS` dictionary
  - Boss configs in `EnemyConfigManager`

### 4. **Debug/Testing Systems**
- **KEEP:** New `DebugManager` system
- **REMOVE:**
  - `CheatManager` entirely
  - `debug/debug_settings.gd`
  - Cheat handling in `InputManager`
  - Mock chat in `TwitchBot`
  - Scattered debug code

### 5. **Enemy Stats Storage**
- **KEEP:** New `EnemyResource` system
- **REMOVE/REFACTOR:**
  - `EnemyConfigManager` dictionaries
  - Hardcoded stats in boss scripts
  - Consolidate with `NPCRarity` multipliers

### 6. **Ability Definitions**
- **KEEP:** `ability_system/abilities/` with BaseAbility
- **REMOVE:**
  - Hardcoded abilities in `EnemyBridge`
  - Ability configs in `EnemyConfigManager`
  - Duplicate ability implementations

### 7. **Bridge/Proxy Patterns**
- **KEEP:** Direct integration patterns
- **REMOVE:**
  - `EnemyBridge` (refactor to use ability system directly)
  - `V2AbilityProxy` (unnecessary with proper ability system)
  - Evaluate `bridge/` folder components

## Consolidation Strategy

### Phase 0: Consultation (Before Any Changes)
1. **Review redundancies** with developer
2. **Identify which systems** are actively used vs legacy
3. **Confirm removal list** before proceeding
4. **Document decisions** for future reference

### Phase 1: Ability System Consolidation
1. Migrate all abilities to `BaseAbility` pattern
2. Remove duplicate ability implementations
3. Refactor `EnemyBridge` to use ability system directly

### Phase 2: Configuration Consolidation  
1. Create unified `EnemyResource` system
2. Migrate all enemy configs to .tres files
3. Remove redundant config managers

### Phase 3: Debug System Unification
1. Implement new `DebugManager`
2. Remove all old cheat systems
3. Consolidate debug functionality

### Phase 4: Movement System Cleanup
1. Evaluate which movement controller to keep
2. Consolidate movement logic
3. Remove redundant controllers

## Conclusion

This architecture:
- **Solves the scalability problem** with resource-based configuration
- **Solves the modularity problem** with separated ability system
- **Solves the testing problem** with comprehensive debug UI
- **Eliminates redundancies** through consolidation
- **Preserves performance** by keeping the dual system
- **Enables rapid iteration** through data-driven design