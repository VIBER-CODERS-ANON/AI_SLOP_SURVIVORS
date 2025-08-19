# Movement Controller Architecture Guide

## Overview
Movement controllers handle input and steering for entities. They follow strict architectural rules to maintain performance and consistency.

## Core Architecture Rules

### 1. Single Velocity Owner
**BaseEntity** is the ONLY class that:
- Sets the `velocity` property
- Calls `move_and_slide()`
- Combines all velocity components

Controllers only:
- Return steering vectors via `_get_movement_input()`
- Modify `entity.movement_velocity`
- NEVER touch `velocity` directly

### 2. No Separation Logic
**FlockingSystem** handles ALL:
- Separation (personal space)
- Alignment (matching neighbors' direction)
- Cohesion (staying with the group)

Controllers MUST NOT:
- Calculate their own separation
- Iterate through entity groups for spacing
- Have a `separation_force` property

### 3. Performance Patterns
All controllers MUST implement:
- Cadence for expensive operations
- Grid-based neighbor queries (if needed)
- Cached results between updates

## Controller Types

### Base MovementController
```gdscript
extends Node
class_name MovementController

# Core properties
@export var acceleration: float = 2000.0
@export var friction: float = 1500.0

# Returns steering direction (normalized)
func _get_movement_input() -> Vector2:
    return Vector2.ZERO  # Override in subclasses

# Modifies entity.movement_velocity based on input
func _physics_process(delta):
    var input = _get_movement_input()
    # Apply acceleration/friction to entity.movement_velocity
```

### ZombieMovementController
Specialized for zombie horde behavior:
```gdscript
extends MovementController

# Properties (NO separation_force!)
@export var arrival_distance: float = 30.0
@export var avoidance_force: float = 2.0
@export var raycast_every_n_frames: int = 2  # Cadence

# Just handles goal seeking + obstacle avoidance
func _get_movement_input() -> Vector2:
    # Calculate path to target
    # Apply obstacle avoidance (with cadence)
    # Return normalized direction
    # NO SEPARATION CALCULATION
```

### AIMovementController
Advanced pathfinding with NavigationAgent2D:
```gdscript
extends MovementController

# Pathfinding cadence
@export var path_update_interval: float = 0.3
var _pf_timer: float = 0.0

# Grid-based neighbor queries
func _get_nearby_entities(radius: float) -> Array:
    if FlockingSystem.instance:
        return FlockingSystem.instance.get_neighbors(entity, max_neighbors)
    # Fallback only
```

### SimpleAIMovementController
Lightweight for testing/simple enemies:
```gdscript
extends MovementController

# Raycast cadence for obstacles
@export var raycast_every_n_frames: int = 2
var last_avoidance_direction: Vector2  # Cache between frames
```

## Implementation Patterns

### Pattern 1: Raycast Cadence
```gdscript
@export var raycast_every_n_frames: int = 2

func _get_movement_input() -> Vector2:
    # Stagger updates across entities
    var do_raycast = (raycast_every_n_frames <= 1) or 
        ((Engine.get_physics_frames() + entity.get_instance_id()) % raycast_every_n_frames == 0)
    
    if do_raycast:
        # Perform expensive raycasts
        last_result = perform_raycasts()
    
    # Use cached result
    return process_with_result(last_result)
```

### Pattern 2: Timer-Based Updates
```gdscript
@export var update_interval: float = 0.3
var _timer: float = 0.0

func _physics_process(delta):
    _timer -= delta
    if _timer <= 0.0:
        expensive_update()
        _timer = update_interval
```

### Pattern 3: Grid Neighbor Queries
```gdscript
# NEVER do this:
var all_entities = get_tree().get_nodes_in_group("entities")  # O(n)

# ALWAYS do this:
var neighbors = FlockingSystem.instance.get_neighbors(entity, 8)  # O(k)
```

## Common Mistakes & Fixes

### ❌ Mistake: Adding Separation
```gdscript
# WRONG - Duplicates flocking system
var separation = Vector2.ZERO
for enemy in get_tree().get_nodes_in_group("enemies"):
    var distance = position.distance_to(enemy.position)
    if distance < 50:
        separation -= (enemy.position - position).normalized()
steering += separation
```

### ✅ Fix: Trust FlockingSystem
```gdscript
# CORRECT - Let flocking handle it
func _get_movement_input() -> Vector2:
    return direction_to_target  # Just goal seeking
```

### ❌ Mistake: Setting Velocity
```gdscript
# WRONG - Controller shouldn't set velocity
entity.velocity = movement_direction * speed
entity.move_and_slide()
```

### ✅ Fix: Modify movement_velocity
```gdscript
# CORRECT - Let BaseEntity handle velocity
entity.movement_velocity = movement_direction * speed
# BaseEntity will combine all velocities and call move_and_slide()
```

### ❌ Mistake: Every-Frame Raycasts
```gdscript
# WRONG - Too expensive
func _physics_process(delta):
    for i in 8:
        var ray_result = space_state.intersect_ray(...)  # Every frame!
```

### ✅ Fix: Use Cadence
```gdscript
# CORRECT - Spread load
if should_raycast_this_frame():
    perform_raycasts()
else:
    use_cached_results()
```

## Creating New Controllers

### Step 1: Extend Base
```gdscript
extends MovementController
class_name MyCustomController
```

### Step 2: Add Cadence
```gdscript
@export var expensive_op_interval: float = 0.2
var _op_timer: float = 0.0
```

### Step 3: Implement Steering
```gdscript
func _get_movement_input() -> Vector2:
    # NO separation calculation
    # NO global entity scans
    # Return normalized direction
    return steering_direction.normalized()
```

### Step 4: No Velocity Setting
```gdscript
# Let BaseEntity handle this
# Just modify entity.movement_velocity
```

## Testing Checklist

Before deploying any controller:

- [ ] No `separation_force` property
- [ ] No separation calculation in code
- [ ] No `get_tree().get_nodes_in_group()` per frame
- [ ] Expensive operations use cadence
- [ ] Only returns normalized directions
- [ ] Never sets velocity directly
- [ ] Never calls move_and_slide()
- [ ] Uses FlockingSystem.get_neighbors() if needed
- [ ] Tested with 100+ entities
- [ ] Performance scales linearly

## Integration with BaseEnemy

BaseEnemy automatically:
1. Creates appropriate controller (usually ZombieMovementController)
2. Sets controller properties (arrival_distance, etc.)
3. Does NOT set separation_force (removed property)
4. Updates target position based on AI behavior

Example from base_enemy.gd:
```gdscript
var ai_controller = ZombieMovementController.new()
ai_controller.arrival_distance = attack_range * 0.8
ai_controller.avoidance_force = 2.0
# NO separation_force setting - doesn't exist!
add_child(ai_controller)
```