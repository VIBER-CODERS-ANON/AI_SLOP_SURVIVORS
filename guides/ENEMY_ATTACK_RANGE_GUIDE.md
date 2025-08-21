# Enemy Attack Range & Movement Guide

## Overview
This guide explains how the enemy attack range and stop-at-range mechanics work for data-oriented (V2) enemies.

## Key Components

### 1. Attack Detection (`PlayerCollisionDetector`)
- **Detection Radius**: 20 pixels from player's capsule edge
- **Player Capsule**: 16px radius, 60px height
- **Total Attack Range**: ~36 pixels from player center

### 2. Movement Stopping (`EnemyManager`)
Enemies stop moving when they reach attack range:
```gdscript
# In _update_enemy_movement():
var distance_to_edge = PlayerCollisionDetector.get_distance_to_player_capsule_edge(player_position, current_pos)
if distance_to_edge <= ATTACK_DETECTION_RADIUS:
    velocities[id] = Vector2.ZERO
    return  # Skip all other movement logic
```

### 3. Capsule Edge Detection
Shared static function in `PlayerCollisionDetector`:
```gdscript
static func get_distance_to_player_capsule_edge(capsule_center: Vector2, point: Vector2) -> float
```
This calculates the exact distance from any point to the edge of the player's capsule-shaped hitbox.

## How It Works

1. **Enemy Movement Phase**:
   - Enemy uses flow-field or direct pursuit to move toward player
   - Before applying movement, checks distance to player's capsule edge
   - If within 20px of edge, sets velocity to zero and skips movement

2. **Attack Detection Phase**:
   - PlayerCollisionDetector checks all nearby enemies each frame
   - Uses same capsule edge detection for consistency
   - If enemy within 20px, applies damage based on enemy's attack cooldown

## Benefits

- **Consistent Range**: Same detection from all angles (no pill-shape issues)
- **No Overlap**: Enemies stop exactly at attack range
- **Performance**: Early exit from movement logic when in range
- **Clean Code**: Shared capsule detection function, no duplicate logic

## Configuration

- **Attack Range**: `ATTACK_DETECTION_RADIUS = 20.0` in both files
- **Player Capsule**: Constants in `PlayerCollisionDetector`
  - `CAPSULE_RADIUS = 16.0`
  - `CAPSULE_HEIGHT = 60.0`

## Troubleshooting

### Enemies Not Stopping
- Check that `enable_flow_field` is true in EnemyManager
- Verify player_position is being updated correctly
- Ensure enemy is in alive state (`alive_flags[id] == 1`)

### Enemies Stopping Too Far/Close
- Adjust `ATTACK_DETECTION_RADIUS` constant
- Remember total distance is detection_radius + capsule_radius

### Performance Issues
- The capsule edge calculation is optimized but still has a sqrt
- For extreme enemy counts (5000+), consider using simple circle approximation

## Code Cleanup Notes

Removed unnecessary code:
- Old arrive/stop mechanics (`STOP_DISTANCE`, `ARRIVE_RADIUS`, `_arrive_scale()`)
- Duplicate attack logic in `_update_enemy_attack()`
- Unused `last_attack_times` array
- All attack damage is handled by PlayerCollisionDetector