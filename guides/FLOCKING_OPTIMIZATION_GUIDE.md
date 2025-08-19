# Flocking System Optimization Guide

## Overview
The flocking system provides authoritative separation, alignment, and cohesion for AI-controlled entities. As of the latest refactor, it's the ONLY source of these behaviors - controllers must NOT implement their own.

## Architecture Rules

### 1. Authoritative Flocking
- **FlockingSystem** is the ONLY place where separation/alignment/cohesion are calculated
- Controllers must NEVER compute their own separation forces
- Controllers must NEVER iterate all entities for crowd forces

### 2. Single Velocity Owner
- **BaseEntity** is the ONLY script that sets velocity and calls move_and_slide()
- Controllers only return steering vectors via `_get_movement_input()`
- Controllers modify `entity.movement_velocity` but never `velocity` directly

### 3. No Global Scans in Controllers
- NEVER use `get_tree().get_nodes_in_group()` in per-frame movement code
- Use `FlockingSystem.instance.get_neighbors()` for grid-backed lookups
- Global scans are only allowed in initialization or debug paths

## Implementation Details

### FlockingSystem Public API

```gdscript
# Get cached flocking force (separation + alignment + cohesion)
func get_flocking_force(entity: Node2D) -> Vector2

# Get neighbors using spatial grid (O(k) instead of O(n))
func get_neighbors(entity: Node2D, cap: int = max_neighbors_check) -> Array

# Alias for clarity
func get_force(entity: Node2D) -> Vector2
```

### V2 Implementation Details

Key configuration (flocking_system.gd):
```gdscript
@export var force_slices: int = 3  # Split entities across 3 update buckets
@export var max_neighbors_check: int = 4  # Only check nearest 4 neighbors
@export var neighbor_radius: float = 96.0  # Radius gate for neighbors
@export var update_interval: float = 0.15  # Time between slice updates
```

Force slicing mechanism:
- Each entity assigned to one of N slices based on instance ID
- Per tick, only entities in current slice recalculate forces
- Forces persist in cache until next update cycle
- Reduces per-frame calculations by factor of N

### BaseEntity Integration

BaseEntity automatically:
1. Registers with FlockingSystem if in "ai_controlled" group
2. Pulls flocking force each physics frame
3. Sums all velocity components: `movement_velocity * modifier + knockback + flocking`
4. Applies final velocity via move_and_slide()

### Controller Patterns

#### ZombieMovementController
```gdscript
# CORRECT - No local separation
func _get_movement_input() -> Vector2:
    # Calculate steering to target
    # Apply obstacle avoidance with raycast cadence
    # Return normalized direction
    # NO SEPARATION CALCULATION HERE!
```

#### AIMovementController
```gdscript
# CORRECT - Uses flocking grid for neighbors
func _get_nearby_entities(radius: float) -> Array:
    if FlockingSystem.instance:
        return FlockingSystem.instance.get_neighbors(entity, max_neighbors)
    # Fallback only if no flocking system
```

## Performance Optimizations (v2 Refactor)

### Force Slicing
The v2 refactor adds force slicing to prevent O(n²) hot paths:
- Only 1/3 of entities update flocking forces per tick (configurable via `force_slices`)
- Each entity's forces persist until its next update
- Smooth behavior maintained with staggered updates

### Radius-Gated Neighbors
- Early exit when neighbor count reached (`max_neighbors_check`)
- No sorting - first K neighbors within radius are used
- Dramatically reduces inner loop iterations

### Cadence Patterns

1. **Flocking Updates**: Fixed interval (0.15s default) with force slicing
2. **Pathfinding Updates**: Timer-based (0.3s default)
3. **Obstacle Raycasts**: Every N frames (2 default)

Example raycast cadence:
```gdscript
@export var raycast_every_n_frames: int = 2

func _get_movement_input():
    var do_raycast := (raycast_every_n_frames <= 1) or 
        ((Engine.get_physics_frames() + int(entity.get_instance_id())) % raycast_every_n_frames == 0)
    
    if do_raycast:
        # Run expensive raycast operations
    else:
        # Use cached results
```

## Common Mistakes to Avoid

### ❌ DON'T: Add separation in controllers
```gdscript
# WRONG - This duplicates flocking system's work
var separation = Vector2.ZERO
for enemy in get_tree().get_nodes_in_group("enemies"):
    separation -= (enemy.position - position).normalized()
steering += separation
```

### ❌ DON'T: Set separation_force on controllers
```gdscript
# WRONG - This property doesn't exist anymore
ai_controller.separation_force = 0.6
```

### ❌ DON'T: Scan all entities per frame
```gdscript
# WRONG - O(n) operation every frame
func _physics_process(delta):
    var all_enemies = get_tree().get_nodes_in_group("enemies")
    for enemy in all_enemies:
        # Process...
```

### ✅ DO: Let FlockingSystem handle it
```gdscript
# CORRECT - Trust the authoritative system
func _get_movement_input():
    # Just handle goal seeking and obstacle avoidance
    return direction_to_target
```

### ✅ DO: Use grid-backed neighbors
```gdscript
# CORRECT - O(k) spatial lookup
if FlockingSystem.instance:
    var neighbors = FlockingSystem.instance.get_neighbors(entity, 5)
```

## Testing & Validation

### Performance Metrics
- With 50/100/200 enemies, script time should scale O(n·k) not O(n²)
- Monitor msec/frame in Godot profiler
- FlockingSystem should be the only significant per-frame cost

### Behavior Validation
- Enemies should maintain natural spacing (no overlapping)
- Coordinated movement in groups (alignment working)
- Stay together as a horde (cohesion working)
- No jittery separation behavior (single authoritative source)

## Migration Checklist

When adding new movement controllers:

- [ ] NO local separation calculation
- [ ] NO per-frame global entity scans
- [ ] Use FlockingSystem.get_neighbors() if needed
- [ ] Add raycast/update cadence for expensive operations
- [ ] Only modify entity.movement_velocity
- [ ] Never set velocity or call move_and_slide()
- [ ] Test with 100+ entities for performance