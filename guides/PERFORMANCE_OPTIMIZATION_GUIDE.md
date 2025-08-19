# Performance Optimization Guide

## Core Principles

### 1. Algorithmic Complexity
- **Target**: O(n) or O(n·k) operations, NEVER O(n²)
- **Spatial partitioning**: Use grids/quadtrees for neighbor queries
- **Caching**: Store expensive calculations between frames

### 2. Frame Budget Management
- **Cadence**: Spread expensive operations across frames
- **Prioritization**: Update visible/nearby entities more frequently
- **LOD**: Reduce fidelity for distant/numerous entities

## V2 Performance Refactor Improvements

### Force Slicing Pattern
The v2 refactor introduces force slicing to eliminate O(n²) hot paths:

```gdscript
# Each entity assigned to slice based on instance ID
var entity_slice = entity.get_instance_id() % force_slices
var current_slice = Engine.get_physics_frames() % force_slices

# Only update if it's this entity's turn
if entity_slice == current_slice:
    _calculate_flocking_forces(entity)
```

Benefits:
- Reduces per-frame calculations by factor of N (force_slices)
- Maintains smooth behavior with cached forces
- Scales better with high entity counts

### Radius-Gated Neighbor Lookup
Early exit optimization for neighbor queries:

```gdscript
func _get_nearby_entities(entity: Node2D) -> Array:
    var out: Array = []
    var r2 := neighbor_radius * neighbor_radius
    
    for other in bucket:
        if out.size() >= max_neighbors_check:
            break  # Early exit - no sorting needed!
        
        var d2 := entity.global_position.distance_squared_to(other.global_position)
        if d2 < r2:
            out.append(other)
    
    return out
```

## Optimization Patterns

### Cadence Pattern
Distribute expensive operations across multiple frames:

```gdscript
# PATTERN 1: Frame-based cadence
@export var update_every_n_frames: int = 3

func _physics_process(delta):
    var should_update = (Engine.get_physics_frames() + get_instance_id()) % update_every_n_frames == 0
    if should_update:
        _expensive_operation()
```

```gdscript
# PATTERN 2: Timer-based cadence
@export var update_interval: float = 0.3
var _update_timer: float = 0.0

func _physics_process(delta):
    _update_timer -= delta
    if _update_timer <= 0.0:
        _expensive_operation()
        _update_timer = update_interval
```

### Spatial Grid Pattern
Replace O(n) searches with O(k) grid lookups:

```gdscript
# WRONG - O(n) for every query
func find_nearby(pos: Vector2, radius: float) -> Array:
    var result = []
    for entity in get_tree().get_nodes_in_group("entities"):
        if entity.global_position.distance_to(pos) < radius:
            result.append(entity)
    return result

# CORRECT - O(k) grid lookup
func find_nearby(pos: Vector2, radius: float) -> Array:
    return spatial_grid.get_neighbors_in_radius(pos, radius)
```

### Caching Pattern
Store results between expensive updates:

```gdscript
var _cached_result: Vector2
var _cache_dirty: bool = true

func get_expensive_calculation() -> Vector2:
    if _cache_dirty:
        _cached_result = _perform_expensive_calculation()
        _cache_dirty = false
    return _cached_result
```

## System-Specific Optimizations

### Flocking System (v2 Optimizations)
- **Grid size**: 100-150 units (tune based on entity density)
- **Update interval**: 0.15s (reduced frequency with force slicing)
- **Max neighbors**: 4 (radius-gated, no sorting for performance)
- **Force slices**: 3 (only 1/3 of entities update per tick)
- **Neighbor radius**: 96.0 units (early exit optimization)

### Movement Controllers

#### Raycasting Optimization
```gdscript
@export var raycast_every_n_frames: int = 2  # 30 FPS for obstacle detection

# Stagger updates across entities
var frame_offset = get_instance_id() % raycast_every_n_frames
var should_raycast = (Engine.get_physics_frames() + frame_offset) % raycast_every_n_frames == 0
```

#### Pathfinding Optimization
```gdscript
@export var path_update_interval: float = 0.3  # ~3 updates per second
@export var path_recalc_distance: float = 50.0  # Only update if target moved significantly

# Don't recalculate if target hasn't moved much
if target_position.distance_to(last_target_position) > path_recalc_distance:
    navigation_agent.target_position = target_position
```

### Entity Updates

#### Visibility-Based LOD
```gdscript
func _physics_process(delta):
    var on_screen = get_viewport_rect().has_point(global_position)
    
    if on_screen:
        _full_update(delta)
    else:
        _reduced_update(delta)  # Skip animations, effects, etc.
```

#### Distance-Based Updates
```gdscript
var player_distance = global_position.distance_to(player.global_position)

if player_distance < 500:
    update_interval = 0.1  # Close: High frequency
elif player_distance < 1000:
    update_interval = 0.3  # Medium: Normal frequency
else:
    update_interval = 1.0  # Far: Low frequency
```

## Common Performance Killers

### ❌ Global Group Iterations
```gdscript
# NEVER do this per frame
func _physics_process(delta):
    for enemy in get_tree().get_nodes_in_group("enemies"):
        for other in get_tree().get_nodes_in_group("enemies"):
            # O(n²) disaster!
```

### ❌ Uncached Calculations
```gdscript
# WRONG - Recalculating every frame
func _physics_process(delta):
    var complex_value = calculate_complex_thing()  # Same result every time!
```

### ❌ Synchronous Operations
```gdscript
# WRONG - Everything updates at once
if Engine.get_physics_frames() % 10 == 0:
    for entity in all_entities:
        entity.expensive_update()  # Frame spike!
```

### ✅ Staggered Updates
```gdscript
# CORRECT - Spread across frames
var update_group = entity.get_instance_id() % 10
if Engine.get_physics_frames() % 10 == update_group:
    entity.expensive_update()  # Load distributed
```

## Profiling & Metrics

### Key Metrics to Monitor
1. **Frame time**: Keep under 16ms (60 FPS) or 33ms (30 FPS)
2. **Script time**: Should scale linearly with entity count
3. **Physics time**: Watch for collision pair explosions
4. **Draw calls**: Batch where possible

### Godot Profiler Usage
1. Enable profiler in Editor
2. Run scene with 50/100/200 entities
3. Check "Scripts" tab for hot spots
4. Look for functions taking >1ms

### Performance Targets
| Entity Count | Target FPS | Max Frame Time |
|-------------|------------|----------------|
| 50          | 60         | 16ms           |
| 100         | 60         | 16ms           |
| 200         | 30-60      | 33ms           |
| 500         | 30         | 33ms           |

## Implementation Checklist

Before committing any new system:

- [ ] No O(n²) algorithms in per-frame code
- [ ] Expensive operations use cadence pattern
- [ ] Spatial queries use grid/partitioning
- [ ] Results cached where appropriate
- [ ] Tested with 200+ entities
- [ ] Profiled for hot spots
- [ ] Frame time stays under budget
- [ ] Updates staggered across frames