# Enemy Attack System Guide

## Overview

The game uses two separate attack systems depending on enemy type:

1. **Data-Oriented Minions** (rats, succubus, evolved forms) - Use PlayerCollisionDetector
2. **Node-Based Enemies** (bosses, special enemies) - Use BaseEnemy attack system

## Data-Oriented Minion Attacks (V2 System)

### How It Works

The V2 enemy system doesn't give each enemy its own collision body. Instead:

1. **Player has a detector** (`PlayerCollisionDetector`) that checks distances to all enemies
2. **EnemyManager stores attack data** in arrays (damage values, attack timers)
3. **Damage is applied** when enemies are within range and cooldown has expired

### Configuration

Edit `systems/detection/player_collision_detector.gd`:

```gdscript
# Attack configuration
var detection_radius: float = 20.0   # Attack range from player's edge in pixels
var damage_cooldown: float = 0.5     # Seconds between attacks (0.5 = 2 APS)

# Player capsule hitbox dimensions
var capsule_radius: float = 16.0     # Radius of the capsule shape
var capsule_height: float = 60.0     # Total height of the capsule
```

Also update `systems/core/enemy_manager.gd`:

```gdscript
const ATTACK_REACH: float = 20.0  # Should match detection_radius
```

### Current Settings

- **Attack Range**: 20 pixels from player's capsule EDGE (not center)
- **Attack Rate**: 2 attacks per second per enemy
- **Damage**: Varies by enemy type (stored in EnemyManager arrays)
- **Edge-Based Detection**: Calculates distance to the edge of player's pill-shaped hitbox

## Node-Based Boss Attacks

Bosses use the traditional `BaseEnemy` system:

### Configuration

Edit individual boss scenes or `entities/enemies/base_enemy.gd`:

```gdscript
@export var attack_range: float = 150.0   # Attack range for bosses
@export var attack_cooldown: float = 0.5  # Time between attacks
@export var damage: float = 10.0          # Damage per attack
```

### How It Works

1. Boss has its own CharacterBody2D with collision
2. Boss checks distance to player each frame
3. When in range and cooldown expired, calls `player.take_damage()`

## Edge-Based Collision Detection

The attack system uses **edge-based detection** for the player's capsule hitbox:

### How It Works

Instead of measuring center-to-center distance, the system:
1. Finds the closest point on the player's capsule centerline to the enemy
2. Calculates distance from that point to the enemy
3. Subtracts the capsule radius to get distance to edge

This solves the "pill-shaped hitbox problem" where enemies couldn't hit from below/above as easily as from the sides.

### Implementation

```gdscript
func _get_distance_to_capsule_edge(capsule_center: Vector2, point: Vector2) -> float:
    # Get the rectangular part height (excluding radius caps)
    var half_rect_height = (capsule_height - capsule_radius * 2) / 2.0
    
    # Get point relative to capsule center
    var relative_point = point - capsule_center
    
    # Clamp Y to the rectangular part of the capsule
    var clamped_y = clamp(relative_point.y, -half_rect_height, half_rect_height)
    
    # Find closest point on centerline
    var closest_on_centerline = Vector2(0, clamped_y)
    
    # Calculate distance to edge
    var dist_to_centerline = relative_point.distance_to(closest_on_centerline)
    return max(0, dist_to_centerline - capsule_radius)
```

## Player Collision Settings

The player uses a **one-way pushing system**:

- Player `collision_mask = 1` (only collides with walls/obstacles)
- Enemies are on layer 2 (player doesn't collide with them)
- Player has a `_push_nearby_enemies()` function that manually pushes enemies away

This allows the player to walk through enemies while still pushing them, preventing body-blocking.

## Troubleshooting

### Enemies Not Attacking

1. Check `detection_radius` in PlayerCollisionDetector (current: 20 pixels from edge)
2. Check `damage_cooldown` (lower = faster attacks, current: 0.5s)
3. Verify enemies are spawned via EnemyManager (V2 system)
4. Check EnemyManager `ATTACK_REACH` matches detection_radius
5. Remember: Distance is from player's EDGE, not center!

### Enemies Attacking Too Slowly

- Reduce `damage_cooldown` in PlayerCollisionDetector
- Default is 0.5 seconds (2 APS)
- Try 0.25 for 4 attacks per second

### Wrong Attack System Being Used

- V2 enemies (spawned via EnemyManager) always use PlayerCollisionDetector
- Only bosses and special enemies use BaseEnemy attack system
- BaseCreature is deprecated and not used by V2 system

## Adding New Attack Behavior

### For V2 Minions

Modify PlayerCollisionDetector:

```gdscript
func _calculate_enemy_damage(enemy_id: int) -> float:
    var enemy_manager = EnemyManager.instance
    var base_damage = enemy_manager.attack_damages[enemy_id]
    
    # Add your modifiers here
    # Example: Double damage for elite enemies
    if enemy_manager.entity_types[enemy_id] == ELITE_TYPE:
        base_damage *= 2.0
    
    return base_damage
```

### For Bosses

Override `_perform_attack()` in the boss script:

```gdscript
func _perform_attack():
    # Custom attack logic
    if special_attack_ready:
        perform_special_attack()
    else:
        super._perform_attack()  # Normal attack
```

## Performance Notes

- PlayerCollisionDetector uses spatial grid for efficient lookups
- Only checks enemies in nearby grid cells
- Scales well to thousands of enemies
- No per-enemy collision bodies = better performance