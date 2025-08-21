# Comprehensive Ability Implementation Guide

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Creating a New Ability](#creating-a-new-ability)
4. [Targeting Systems](#targeting-systems)
5. [Resource Management](#resource-management)
6. [Integration](#integration)
7. [Best Practices](#best-practices)
8. [Examples](#examples)
9. [Troubleshooting](#troubleshooting)
10. [Checklist](#checklist)

## Overview

The A.S.S (AI SLOP SURVIVORS) ability system is designed to be:
- **Modular**: Each ability is self-contained
- **Flexible**: Works with any entity (player, NPC, item)
- **Extensible**: Easy to add new abilities without modifying core systems
- **Tag-Based**: Integrates with the game's tag system for dynamic interactions
- **Object-Oriented**: Follows OOP principles for maintainability

## Architecture

### ⚠️ CRITICAL PERFORMANCE WARNINGS

#### Flocking System Integration
- **NEVER** add separation logic in abilities or AI behaviors
- **NEVER** use `get_tree().get_nodes_in_group()` in per-frame ability code
- **FlockingSystem** is the ONLY source of separation/alignment/cohesion
- Use `FlockingSystem.instance.get_neighbors()` for grid-based lookups if needed

#### Movement Controller Rules
- Controllers must NOT set `separation_force` (property removed)
- Controllers must NOT compute their own crowd avoidance
- See `MOVEMENT_CONTROLLER_GUIDE.md` for details

### Core Components

1. **BaseAbility** (`systems/ability_system/core/base_ability.gd`)
   - Abstract base class for all abilities
   - Handles cooldowns, resource costs, and basic lifecycle
   - Provides hooks for customization

2. **AbilityManager** (`systems/ability_system/core/ability_manager.gd`)
   - Manages ability slots and keybindings
   - Handles ability execution and input
   - Updates ability states each frame

3. **AbilityHolderComponent** (`systems/ability_system/core/ability_holder_component.gd`)
   - Component that makes entities capable of using abilities
   - Provides entity stats and resources
   - Handles animations and visual feedback

4. **AbilityTargetData** (`systems/ability_system/targeting/ability_target_data.gd`)
   - Encapsulates targeting information
   - Supports various targeting types

### Flow Diagram

```
User Input → AbilityManager → BaseAbility.can_execute() → BaseAbility.execute()
                                    ↓                              ↓
                              Check Resources              _execute_ability()
                              Check Cooldown                      ↓
                              Check Status               Spawn Effects/Damage
                                                                 ↓
                                                         Start Cooldown
```

## Creating a New Ability

### Step 1: Create the Ability Class

Create a new file in `systems/ability_system/abilities/` named `your_ability.gd`:

```gdscript
class_name YourAbility
extends BaseAbility

## Brief description of what your ability does
## Include any special mechanics or interactions

# Ability-specific properties
@export_group("Ability Properties")
@export var damage: float = 10.0
@export var effect_radius: float = 100.0
@export var duration: float = 5.0

# Visual/Audio
@export_group("Visual and Audio")
@export var effect_scene_path: String = ""
@export var ability_sound_path: String = ""
@export var cast_animation: String = "cast"

# Cached resources
var effect_scene: PackedScene
var ability_sound: AudioStream

func _init() -> void:
    # REQUIRED: Set unique ability ID
    ability_id = "your_ability_id"
    ability_name = "Your Ability Name"
    ability_description = "What this ability does"
    
    # REQUIRED: Set ability tags for interactions
    ability_tags = ["Type1", "Type2"]  # e.g., ["Fire", "AoE", "DoT"]
    
    # REQUIRED: Set ability type
    ability_type = 0  # 0 = ACTIVE, 1 = PASSIVE, 2 = TOGGLE
    
    # REQUIRED: Set cooldown
    base_cooldown = 5.0  # seconds
    
    # OPTIONAL: Set resource costs
    resource_costs = {
        "mana": 20.0,
        "health": 0.0
    }
    
    # REQUIRED: Set targeting type
    targeting_type = 0  # See Targeting Systems section
    base_range = 500.0  # For ranged abilities

func on_added(holder) -> void:
    super.on_added(holder)
    
    # Preload resources
    if effect_scene_path != "":
        effect_scene = load(effect_scene_path)
    if ability_sound_path != "":
        ability_sound = load(ability_sound_path)
    
    # Log for debugging
    print("✨ ", ability_name, " added to ", _get_entity_name(holder))

func can_execute(holder, target_data) -> bool:
    # Always call parent first
    if not super.can_execute(holder, target_data):
        return false
    
    # Add custom checks
    var entity = _get_entity(holder)
    if not entity:
        return false
    
    # Check if entity is alive
    if entity.has_method("is_alive") and not entity.is_alive:
        return false
    
    # Add your custom conditions here
    # Example: Check if target is in range
    # Example: Check if entity has required buff
    
    return true

func _execute_ability(holder, target_data) -> void:
    var entity = _get_entity(holder)
    if not entity:
        return
    
    # Report to action feed for chatters
    _report_to_action_feed(entity)
    
    # Play sound
    _play_ability_sound(entity)
    
    # Play animation
    _play_animation(holder, cast_animation)
    
    # Execute ability logic
    _perform_ability_logic(entity, holder, target_data)
    
    # Start cooldown
    _start_cooldown(holder)
    
    # Notify systems
    holder.on_ability_executed(self)
    executed.emit(target_data)

# Helper methods
func _get_entity(holder):
    if holder.has_method("get_entity_node"):
        return holder.get_entity_node()
    return holder

func _get_entity_name(holder) -> String:
    var entity = _get_entity(holder)
    if entity:
        return entity.name
    return "Unknown"

func _report_to_action_feed(entity) -> void:
    # For chatter entities
    if entity.has_method("get_chatter_username") and GameController.instance:
        var action_feed = GameController.instance.get_action_feed()
        if action_feed and action_feed.has_method("custom_ability"):
            action_feed.custom_ability(entity.get_chatter_username(), ability_name)

func _play_ability_sound(entity) -> void:
    if ability_sound and AudioManager.instance:
        AudioManager.instance.play_sfx_on_node(
            ability_sound,
            entity,
            0.0,  # pitch variation
            1.0   # volume
        )

func _play_animation(holder, anim_name: String) -> void:
    if holder.has_method("play_animation"):
        holder.play_animation(anim_name)

func _perform_ability_logic(entity, holder, target_data) -> void:
    # IMPLEMENT YOUR ABILITY LOGIC HERE
    pass

# Override for abilities that need custom range display
func get_range() -> float:
    return base_range  # or effect_radius for AoE abilities
```

### Step 2: Implement Ability Logic

Based on your ability type, implement the `_perform_ability_logic` method:

#### Example: Projectile Ability
```gdscript
func _perform_ability_logic(entity, holder, target_data) -> void:
    if not projectile_scene:
        return
    
    var projectile = projectile_scene.instantiate()
    
    # Set projectile properties
    projectile.damage = get_modified_value(damage, "spell_power", holder)
    projectile.speed = projectile_speed
    projectile.direction = target_data.target_direction
    projectile.source_entity = entity
    
    # Add tags
    if projectile.has_method("add_tag"):
        for tag in ability_tags:
            projectile.add_tag(tag)
    
    # Add to scene
    entity.get_parent().add_child(projectile)
    projectile.global_position = entity.global_position
```

#### Example: Area Effect Ability
```gdscript
func _perform_ability_logic(entity, holder, target_data) -> void:
    # ⚠️ PERFORMANCE: Use physics queries, NOT group iterations!
    # NEVER do: for enemy in get_tree().get_nodes_in_group("enemies")
    
    var space_state = entity.get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = effect_radius
    
    query.shape = circle
    query.transform = Transform2D(0, entity.global_position)
    query.collision_mask = 2  # Enemy layer
    
    var results = space_state.intersect_shape(query)
    
    for result in results:
        var target = result.collider
        if target.has_method("take_damage"):
            var final_damage = get_modified_value(damage, "spell_power", holder)
            target.take_damage(final_damage, entity, ability_tags)
```

#### Example: Buff/Debuff Ability
```gdscript
func _perform_ability_logic(entity, holder, target_data) -> void:
    # Apply buff to self
    if entity.has_method("add_status_effect"):
        var buff = preload("res://buffs/your_buff.gd").new()
        buff.duration = duration
        entity.add_status_effect(buff)
    
    # Or apply debuff to target
    if target_data.primary_target and target_data.primary_target.has_method("add_status_effect"):
        var debuff = preload("res://debuffs/your_debuff.gd").new()
        debuff.duration = duration
        target_data.primary_target.add_status_effect(debuff)
```

## Targeting Systems

The `targeting_type` property determines how the ability targets:

| Type | Value | Description | Example |
|------|-------|-------------|---------|
| SELF | 0 | Targets the caster | Heal, Buff |
| SINGLE_TARGET | 1 | Targets one entity | Fireball |
| MULTI_TARGET | 2 | Targets multiple entities | Chain Lightning |
| AREA | 3 | Targets a ground area | Meteor |
| DIRECTION | 4 | Fires in a direction | Dash, Projectile |
| AREA_AROUND_SELF | 5 | AoE centered on caster | Explosion, Aura |

### Creating Target Data

```gdscript
# Self target
var target_data = AbilityTargetData.create_self_target(entity)

# Direction target (for movement abilities)
var direction = entity.get_facing_direction()
var target_data = AbilityTargetData.create_direction_target(
    entity.global_position,
    direction
)
```

## Resource Management

### Checking Resources

Override `can_execute` to check custom resources:

```gdscript
func can_execute(holder, target_data) -> bool:
    if not super.can_execute(holder, target_data):
        return false
    
    var entity = _get_entity(holder)
    
    # Check mana
    if resource_costs.has("mana"):
        var mana_cost = resource_costs["mana"]
        if entity.get("current_mana", 0) < mana_cost:
            return false
    
    # Check custom resource
    if entity.has_method("has_resource"):
        if not entity.has_resource("rage", 50):
            return false
    
    return true
```

### Consuming Resources

In `_execute_ability`:

```gdscript
func _execute_ability(holder, target_data) -> void:
    var entity = _get_entity(holder)
    
    # Consume mana
    if resource_costs.has("mana") and entity.has_method("consume_mana"):
        entity.consume_mana(resource_costs["mana"])
    
    # Continue with ability execution...
```

## Integration

### Adding to Player

In `player.gd`:

```gdscript
func _ready():
    # Add ability holder component
    var ability_holder = AbilityHolderComponent.new()
    add_child(ability_holder)
    
    # Add ability manager
    var ability_mgr = AbilityManager.new()
    add_child(ability_mgr)
    
    # Create and add ability
    var new_ability = YourAbility.new()
    add_ability(new_ability)
    
    # Set keybind (optional)
    ability_mgr.set_ability_keybind(0, "ability_1")  # Q key
```

### Adding to NPCs/Enemies

In enemy script:

```gdscript
func _ready():
    # Same as player setup
    var ability_holder = AbilityHolderComponent.new()
    add_child(ability_holder)
    
    var ability_mgr = AbilityManager.new()
    add_child(ability_mgr)
    
    # Add abilities
    var explode = ExplosionAbility.new()
    add_ability(explode)
    
    # Trigger in AI
    if should_use_ability():
        ability_mgr.execute_ability_by_id("explosion")
```

### Adding to Items

Items can grant abilities when equipped:

```gdscript
func on_equipped(entity):
    var ability = YourAbility.new()
    entity.add_ability(ability)
    stored_ability_id = ability.ability_id

func on_unequipped(entity):
    entity.remove_ability(stored_ability_id)
```

## Best Practices

### 1. Use the Tag System

Always tag your abilities and effects:

```gdscript
ability_tags = ["Fire", "DoT", "AoE"]

# In projectiles/effects
projectile.add_tag("Fire")
projectile.add_tag("Projectile")
```

### 2. Proper Death Attribution

Always ensure projectiles, effects, and damage sources properly attribute kills to the original caster:

#### For Projectiles
```gdscript
# In projectile setup
func setup(direction: Vector2, damage: float, owner: Node):
    self.owner_entity = owner
    # Store reference for attribution
    set_meta("original_owner", owner)

# In damage application - pass projectile as source, not owner
func _on_body_entered(body):
    if body.has_method("take_damage"):
        body.take_damage(damage, self)  # Pass self, not owner_entity

# Add attribution methods
func get_killer_display_name() -> String:
    if owner_entity and is_instance_valid(owner_entity):
        if owner_entity.has_method("get_killer_display_name"):
            return owner_entity.get_killer_display_name()
        elif owner_entity.has_method("get_chatter_username"):
            return owner_entity.get_chatter_username()
    return "Someone"

func get_attack_name() -> String:
    return "projectile name"
```

#### For Area Effects (DoT, AoE)
```gdscript
# Store spawner reference
func _ready():
    var spawner = get_meta("spawner", null)
    if spawner:
        set_meta("original_spawner", spawner)
        # Get display name immediately
        if spawner.has_method("get_chatter_username"):
            set_meta("source_name", spawner.get_chatter_username())

# When dealing damage - pass self as source
player.take_damage(damage, self, damage_tags)

# Add attribution methods
func get_killer_display_name() -> String:
    if has_meta("original_spawner"):
        var spawner = get_meta("original_spawner")
        if spawner and is_instance_valid(spawner):
            if spawner.has_method("get_killer_display_name"):
                return spawner.get_killer_display_name()
    return get_meta("source_name", "Someone")
```

#### For Direct Damage
```gdscript
# When entity deals damage directly, pass self
target.take_damage(damage, self, damage_tags)
```

#### For Channeled/Persistent Abilities (Resource-based)
```gdscript
# Abilities that extend Resource cannot be passed as damage source
# Instead, pass the entity with temporary metadata
entity.set_meta("active_ability_name", "life drain")
target.take_damage(damage, entity, damage_tags)
entity.remove_meta("active_ability_name")

# Alternative: Create a proxy Node
var damage_source = Node2D.new()
damage_source.name = "LifeDrain"
damage_source.set_meta("owner_entity", entity)
entity.add_child(damage_source)
target.take_damage(damage, damage_source, damage_tags)
damage_source.queue_free()
```

### 3. Move-to-Range Pattern

For abilities that require being in range, use the request pattern:

```gdscript
# In your ability
signal request_move_to_target(target: Node, desired_range: float)

func _execute_ability(holder, target_data) -> void:
    var entity = holder
    if holder.has_method("get_entity_node"):
        entity = holder.get_entity_node()
    
    var target = target_data.target_enemy
    var distance = entity.global_position.distance_to(target.global_position)
    
    if distance > ability_range:
        # Request movement instead of failing
        request_move_to_target.emit(target, ability_range * 0.9)
        return
    
    # Execute ability when in range
    _start_ability_logic()
```

Then in the entity:
```gdscript
# Connect to the signal
ability.request_move_to_target.connect(_on_ability_request_move)

var move_target: Node = null
var move_range: float = 0.0

func _on_ability_request_move(target: Node, desired_range: float):
    move_target = target
    move_range = desired_range

func _physics_process(delta):
    if move_target and is_instance_valid(move_target):
        var distance = global_position.distance_to(move_target.global_position)
        if distance <= move_range:
            # Try ability again
            execute_ability("ability_name", create_target_data(move_target))
            move_target = null
        else:
            # Move towards target
            var direction = (move_target.global_position - global_position).normalized()
            movement_velocity = direction * move_speed
```

### 4. Scale with Entity Stats

Use `get_modified_value` for scaling:

```gdscript
var final_damage = get_modified_value(base_damage, "spell_power", holder)
var final_radius = get_modified_value(base_radius, "aoe_size", holder)
```

### 4. Handle Entity Death

Always check if entities are valid:

```gdscript
if is_instance_valid(target) and target.has_method("is_alive") and target.is_alive:
    # Safe to use target
```

### 5. Clean Up Resources

In `on_removed`:

```gdscript
func on_removed(holder) -> void:
    # Clean up any persistent effects
    if persistent_effect:
        persistent_effect.queue_free()
    
    # Disconnect signals
    if connected_signal:
        connected_signal.disconnect(callback)
```

### 6. Provide Visual Feedback

Always include visual/audio feedback:

```gdscript
# Screen shake for impactful abilities
if entity.has_method("shake_camera"):
    entity.shake_camera(0.5, 10)

# Particle effects
if effect_scene:
    var effect = effect_scene.instantiate()
    entity.get_parent().add_child(effect)
    effect.global_position = target_position

# Sound effects
_play_ability_sound(entity)
```

### 7. Use Action Feed for Chatters

Report ability usage for Twitch integration:

```gdscript
if entity.has_method("get_chatter_username") and GameController.instance:
    var action_feed = GameController.instance.get_action_feed()
    if action_feed:
        # Use existing methods or add custom ones
        action_feed.chatter_used_ability(entity.get_chatter_username(), ability_name)
```

### 8. Consider Performance

For AoE abilities, limit targets:

```gdscript
var max_targets = 10
var targets_hit = 0

for result in results:
    if targets_hit >= max_targets:
        break
    # Process target
    targets_hit += 1
```

## Buff System (Temporary Effects)

### Overview
Buffs are temporary modifications to entity stats that expire after a duration. The first implemented buff is the `!boost` command.

### Implementation Pattern

#### For Data-Oriented Enemies (V2)
Buffs are tracked using parallel arrays in EnemyManager:
- Cooldown tracking array (when last used)
- Active buff value array (current bonus)
- Expiry time array (when buff ends)

#### Example: Boost Buff Implementation

```gdscript
# In EnemyManager
var last_boost_times: PackedFloat32Array
var temporary_speed_boosts: PackedFloat32Array  
var boost_end_times: PackedFloat32Array

const BOOST_COOLDOWN: float = 60.0
const BOOST_FLAT_BONUS: float = 500.0
const BOOST_DURATION: float = 1.0

# In spawn_enemy - buff available on spawn
last_boost_times[id] = -BOOST_COOLDOWN  

# In movement calculation
var effective_speed = move_speeds[id] + temporary_speed_boosts[id]

# In physics process - check expiry
if boost_end_times[id] > 0 and current_time >= boost_end_times[id]:
    temporary_speed_boosts[id] = 0.0
    boost_end_times[id] = 0.0
```

### Creating a Buff Ability

```gdscript
class_name BoostBuffAbility
extends BaseAbility

func _init() -> void:
    ability_tags = ["Buff", "Duration", "Movement", "Speed", "Temporary", "Command"]
    base_cooldown = 60.0  # Per-entity cooldown
    resource_costs = {}  # Free command
```

### Key Considerations
1. **Per-Entity Cooldowns**: Each entity tracks its own cooldown
2. **Initialization**: Set cooldown to negative value for immediate availability
3. **Visual Feedback**: Flash effects to indicate active buffs
4. **Activity Feed**: Report buff usage for player awareness
5. **Command Routing**: Use trigger_ prefix pattern for chat commands

## Examples

### Example 1: Fireball (Projectile)

```gdscript
class_name FireballAbility
extends BaseAbility

@export var damage: float = 30.0
@export var projectile_speed: float = 500.0
@export var explosion_radius: float = 50.0
@export var projectile_scene_path: String = "res://entities/projectiles/fireball.tscn"

var projectile_scene: PackedScene

func _init() -> void:
    ability_id = "fireball"
    ability_name = "Fireball"
    ability_description = "Launches a fireball that explodes on impact"
    ability_tags = ["Fire", "Projectile", "AoE"]
    ability_type = 0  # ACTIVE
    base_cooldown = 2.0
    resource_costs = {"mana": 15.0}
    targeting_type = 4  # DIRECTION
    base_range = 800.0

func _perform_ability_logic(entity, holder, target_data) -> void:
    if not projectile_scene:
        return
    
    var fireball = projectile_scene.instantiate()
    fireball.damage = get_modified_value(damage, "spell_power", holder)
    fireball.speed = projectile_speed
    fireball.explosion_radius = explosion_radius
    fireball.direction = target_data.target_direction
    fireball.source_entity = entity
    
    # Add ability tags to projectile
    for tag in ability_tags:
        fireball.add_tag(tag)
    
    entity.get_parent().add_child(fireball)
    fireball.global_position = entity.global_position + target_data.target_direction * 20
```

### Example 2: Heal (Self/Target)

```gdscript
class_name HealAbility
extends BaseAbility

@export var heal_amount: float = 50.0
@export var can_target_others: bool = true
@export var heal_effect_scene_path: String = "res://entities/effects/heal_effect.tscn"

func _init() -> void:
    ability_id = "heal"
    ability_name = "Heal"
    ability_description = "Restores health to target"
    ability_tags = ["Holy", "Restoration"]
    ability_type = 0  # ACTIVE
    base_cooldown = 5.0
    resource_costs = {"mana": 25.0}
    targeting_type = 1 if can_target_others else 0  # SINGLE_TARGET or SELF
    base_range = 300.0

func _perform_ability_logic(entity, holder, target_data) -> void:
    var target = target_data.primary_target if target_data.primary_target else entity
    
    if not target or not target.has_method("heal"):
        return
    
    var heal_value = get_modified_value(heal_amount, "healing_power", holder)
    target.heal(heal_value, entity)
    
    # Visual effect
    if heal_effect_scene:
        var effect = heal_effect_scene.instantiate()
        target.add_child(effect)
        effect.position = Vector2.ZERO
```

### Example 3: Lightning Strike (Targeted AoE)

```gdscript
class_name LightningStrikeAbility
extends BaseAbility

@export var damage: float = 100.0
@export var strike_radius: float = 150.0
@export var strike_delay: float = 0.5
@export var lightning_scene_path: String = "res://entities/effects/lightning_strike.tscn"

func _init() -> void:
    ability_id = "lightning_strike"
    ability_name = "Lightning Strike"
    ability_description = "Calls down lightning at target location"
    ability_tags = ["Lightning", "AoE", "Elemental"]
    ability_type = 0  # ACTIVE
    base_cooldown = 8.0
    resource_costs = {"mana": 40.0}
    targeting_type = 3  # AREA
    base_range = 600.0

func _perform_ability_logic(entity, holder, target_data) -> void:
    # Create telegraph
    var telegraph = create_telegraph(target_data.target_position, strike_radius)
    entity.get_parent().add_child(telegraph)
    
    # Delay the actual strike
    await entity.get_tree().create_timer(strike_delay).timeout
    
    # Remove telegraph
    telegraph.queue_free()
    
    # Create lightning effect and damage
    if lightning_scene:
        var lightning = lightning_scene.instantiate()
        lightning.damage = get_modified_value(damage, "spell_power", holder)
        lightning.radius = strike_radius
        lightning.source_entity = entity
        lightning.ability_tags = ability_tags
        
        entity.get_parent().add_child(lightning)
        lightning.global_position = target_data.target_position
```

## Death Attribution System - CRITICAL

### Overview
The death attribution system ensures that when a player dies, the death screen correctly shows:
1. **WHO** killed them (Twitch username with their chat color)
2. **HOW** they died (ability/attack name)

### Key Lessons from Implementation

#### 1. Resources Cannot Be Damage Sources
**Problem**: Abilities that extend `Resource` (like `BaseAbility`) cannot be passed to `take_damage()` as the source parameter.
```gdscript
# ❌ WRONG - Causes crash!
# "Invalid type in function 'take_damage'... Resource is not a subclass of Node"
target.take_damage(damage, self, tags)  # self is a Resource

# ✅ CORRECT - Use entity with metadata
entity.set_meta("active_ability_name", "life drain")
target.take_damage(damage, entity, tags)
entity.remove_meta("active_ability_name")
```

#### 2. Proper Attribution Chain
Every damage-dealing entity must implement or delegate attribution methods:

**For Entities (Enemies/NPCs):**
```gdscript
func get_killer_display_name() -> String:
    return chatter_username  # Return the Twitch username

func get_chatter_color() -> Color:
    return chatter_color  # Return their Twitch chat color

func get_attack_name() -> String:
    return "basic attack"  # Or specific attack name
```

**For Projectiles/Effects:**
```gdscript
# Store owner reference
func setup(owner: Node):
    self.owner_entity = owner
    set_meta("original_owner", owner)

# Pass SELF as damage source (not owner)
func _on_hit(target):
    target.take_damage(damage, self, tags)  # Pass projectile, not owner

# Delegate attribution to owner
func get_killer_display_name() -> String:
    if owner_entity and is_instance_valid(owner_entity):
        if owner_entity.has_method("get_killer_display_name"):
            return owner_entity.get_killer_display_name()
    return "Someone"

func get_chatter_color() -> Color:
    if owner_entity and is_instance_valid(owner_entity):
        if owner_entity.has_method("get_chatter_color"):
            return owner_entity.get_chatter_color()
    return Color.WHITE
```

#### 3. Signal Changes
The `died` signal now passes attribution information:
```gdscript
# Old (causes errors)
signal died()
func _on_enemy_died():  # Method expected 1 argument, but called with 3

# New (correct)
signal died(killer_name: String, death_cause: String)
func _on_enemy_died(_killer_name: String, _death_cause: String):
    # Use _ prefix for unused parameters to avoid warnings
```

### Death Attribution Checklist

Before your ability is complete, verify:

- [ ] **Projectiles/Effects pass themselves** as damage source, not their owner
- [ ] **All damage sources implement** `get_killer_display_name()` and `get_attack_name()`
- [ ] **Chatter entities implement** `get_chatter_color()` for colored names
- [ ] **Resource-based abilities** use metadata approach (can't pass self)
- [ ] **Area effects store** spawner reference immediately (in case spawner is freed)
- [ ] **All died signal handlers** accept the new parameters

### Common Patterns

#### Pattern 1: Direct Entity Damage
```gdscript
# Entity deals damage directly
target.take_damage(damage, self, ["Melee", "Physical"])
```

#### Pattern 2: Projectile Damage
```gdscript
# In projectile
func _on_body_entered(body):
    if body.has_method("take_damage"):
        body.take_damage(damage, self)  # Pass projectile, not owner

func get_killer_display_name() -> String:
    # Delegate to owner
    if owner_entity and owner_entity.has_method("get_killer_display_name"):
        return owner_entity.get_killer_display_name()
    return "Someone"
```

#### Pattern 3: Persistent Effect (DoT/AoE)
```gdscript
# In effect _ready()
var spawner = get_meta("spawner", null)
if spawner:
    set_meta("original_spawner", spawner)
    # Store name immediately in case spawner is freed
    set_meta("source_name", spawner.get_chatter_username())

# When dealing damage
target.take_damage(damage, self, tags)

# Attribution methods delegate to spawner
func get_killer_display_name() -> String:
    if has_meta("original_spawner"):
        var spawner = get_meta("original_spawner")
        if spawner and is_instance_valid(spawner):
            return spawner.get_killer_display_name()
    return get_meta("source_name", "Someone")
```

#### Pattern 4: Resource-Based Abilities
```gdscript
# In ability update/execute
entity.set_meta("active_ability_name", "life drain")
target.take_damage(damage, entity, tags)
entity.remove_meta("active_ability_name")
```

**IMPORTANT**: The `active_ability_name` metadata takes priority over entity's `get_attack_name()` method. This allows abilities to override the default attack name (e.g., "life drain" instead of "bite").

## Troubleshooting

### Common Issues

1. **Ability not executing**
   - Check if ability_holder is properly set up
   - Verify cooldown is not active
   - Ensure can_execute returns true
   - Check resource requirements

2. **Ability not found**
   - Verify ability_id is set and unique
   - Check if ability was properly added to manager

3. **"Nonexistent function 'has'" error**
   - Abilities are Resources, not Nodes
   - Use `"property_name" in ability` to check properties
   - NEVER use `ability.has("property_name")`
   ```gdscript
   # WRONG - Resources don't have has() method
   if ability.has("ability_id"):
       pass
   
   # CORRECT - Use 'in' operator for Resources
   if "ability_id" in ability and ability.ability_id == "suicide_bomb":
       pass
   ```
   - Ensure ability instance isn't null

3. **Visual effects not appearing**
   - Verify scene paths are correct
   - Check if effect is added to proper parent
   - Ensure position is set correctly

4. **Damage not applying**
   - Verify target has take_damage method
   - Check collision layers/masks
   - Ensure damage tags are properly set

### Debug Tips

Add debug prints:

```gdscript
func _ready():
    print("[ABILITY_DEBUG] ", ability_name, " initialized")

func can_execute(holder, target_data) -> bool:
    print("[ABILITY_DEBUG] Checking can_execute for ", ability_name)
    print("[ABILITY_DEBUG] - Cooldown: ", is_on_cooldown)
    print("[ABILITY_DEBUG] - Resources: ", resource_costs)
    return super.can_execute(holder, target_data)
```

## Checklist

### New Ability Checklist

- [ ] Created new ability file in `systems/ability_system/abilities/`
- [ ] Extended `BaseAbility` class
- [ ] Set unique `ability_id`
- [ ] Set `ability_name` and `ability_description`
- [ ] Added appropriate `ability_tags`
- [ ] Set `ability_type` (ACTIVE/PASSIVE/TOGGLE)
- [ ] Set `base_cooldown`
- [ ] Set `targeting_type` and `base_range`
- [ ] Defined `resource_costs` (if any)
- [ ] Implemented `_init()` method
- [ ] Implemented `on_added()` method
- [ ] Implemented `can_execute()` override (if needed)
- [ ] Implemented `_execute_ability()` method
- [ ] Implemented `_perform_ability_logic()` method
- [ ] Added visual effects
- [ ] Added sound effects
- [ ] Added animations
- [ ] Integrated with action feed (for chatters)
- [ ] Handled entity death/cleanup
- [ ] Added to relevant entities (player/NPC/item)
- [ ] Set up keybindings (if player ability)
- [ ] Tested ability execution
- [ ] Tested cooldown system
- [ ] Tested resource consumption
- [ ] Tested with different entity types
- [ ] Tested visual/audio feedback
- [ ] Verified performance with many entities
- [ ] Added documentation comments

### Integration Checklist

- [ ] Entity has `AbilityHolderComponent`
- [ ] Entity has `AbilityManager`
- [ ] Ability properly instantiated
- [ ] Ability added to manager
- [ ] Keybinds configured (if applicable)
- [ ] AI can trigger ability (if NPC)
- [ ] Item grants/removes ability (if item-based)

## Advanced Topics

### AI-Activated Abilities (Proximity Activation)

For abilities that AI entities should automatically use based on proximity:

```gdscript
# In your ability class
@export var activation_range: float = 80.0
@export var activation_chance_per_frame: float = 0.15
@export var auto_activate_on_proximity: bool = true

func on_update(holder, _delta: float) -> void:
    if not auto_activate_on_proximity:
        return
    
    var entity = _get_entity(holder)
    if not entity or not entity.is_in_group("ai_controlled"):
        return
    
    # Check proximity to target
    var target = entity.target_player if entity.has("target_player") else null
    if target:
        var distance = entity.global_position.distance_to(target.global_position)
        if distance <= activation_range:
            var proximity_factor = (activation_range - distance) / activation_range
            if randf() < proximity_factor * activation_chance_per_frame:
                execute(holder, {"position": entity.global_position})
```

This pattern is used by the **Suicide Bomb** ability, allowing any AI entity to automatically trigger abilities when near their target.

### Custom Targeting

For complex targeting, extend `AbilityTargetData`:

```gdscript
class CustomTargetData extends AbilityTargetData:
    var target_pattern: Array = []  # Custom pattern
    var charge_time: float = 0.0    # Charged abilities
    
    static func create_pattern_target(origin: Vector2, pattern: Array) -> CustomTargetData:
        var data = CustomTargetData.new()
        data.target_position = origin
        data.target_pattern = pattern
        return data
```

### Combo Abilities

Track ability sequences:

```gdscript
var combo_window: float = 2.0
var last_ability_time: float = 0.0
var combo_stack: int = 0

func can_execute(holder, target_data) -> bool:
    var current_time = holder.get_tree().get_current_time()
    if current_time - last_ability_time > combo_window:
        combo_stack = 0
    return super.can_execute(holder, target_data)

func _execute_ability(holder, target_data) -> void:
    combo_stack += 1
    last_ability_time = holder.get_tree().get_current_time()
    
    # Enhance ability based on combo
    var damage_multiplier = 1.0 + (combo_stack * 0.5)
    # ... rest of execution
```

### Channeled Abilities

For abilities that require channeling:

```gdscript
var is_channeling: bool = false
var channel_time: float = 0.0
var max_channel_time: float = 3.0

func _execute_ability(holder, target_data) -> void:
    is_channeling = true
    channel_time = 0.0
    
    # Disable movement
    if holder.has_method("set_can_move"):
        holder.set_can_move(false)

func update(delta: float, holder) -> void:
    super.update(delta, holder)
    
    if is_channeling:
        channel_time += delta
        
        # Channel tick effects
        if fmod(channel_time, 0.5) < delta:
            _channel_tick(holder)
        
        # Complete channel
        if channel_time >= max_channel_time:
            _complete_channel(holder)
```

### Persistent Effects

For abilities that create persistent effects:

```gdscript
var active_effects: Array = []

func _perform_ability_logic(entity, holder, target_data) -> void:
    var effect = create_persistent_effect()
    active_effects.append(effect)
    
    # Clean up old effects
    active_effects = active_effects.filter(func(e): return is_instance_valid(e))

func on_removed(holder) -> void:
    # Clean up all effects
    for effect in active_effects:
        if is_instance_valid(effect):
            effect.queue_free()
    active_effects.clear()
```

This guide should provide everything needed to create robust, modular abilities that integrate seamlessly with the A.S.S game systems.
