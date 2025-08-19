# Damage Feedback System Guide

## Overview
The damage feedback system provides visual indication when NPCs (twitch chatters) take damage by flashing them white briefly. This improves game feel and player feedback.

## Implementation Details

### How It Works
1. When an enemy takes damage via `damage_enemy()`, a flash timer is set
2. The flash timer counts down each frame during position integration
3. During rendering, enemies with active flash timers are rendered with a white color modulation
4. The intensity of the white flash fades over the duration (0.15 seconds)

### Key Components

#### Flash Timer System
- `flash_timers: PackedFloat32Array` - Stores flash timer for each enemy
- `FLASH_DURATION: float = 0.15` - Duration of the white flash effect

#### Flash Trigger
```gdscript
func _flash_enemy_white(enemy_id: int):
    if enemy_id < 0 or enemy_id >= flash_timers.size():
        return
    flash_timers[enemy_id] = FLASH_DURATION
```

#### Color Modulation During Rendering
The flash effect is applied during MultiMesh rendering:
```gdscript
var color = Color.WHITE
if flash_timers[enemy_id] > 0.0:
    var flash_intensity = flash_timers[enemy_id] / FLASH_DURATION
    color = Color(1.0 + flash_intensity * 2.0, 1.0 + flash_intensity * 2.0, 1.0 + flash_intensity * 2.0, 1.0)
```

### MultiMesh Configuration
All MultiMesh instances must have `use_colors = true` enabled to support per-instance color modulation.

## Usage
The system automatically triggers when any enemy takes damage. No additional configuration is needed.

## Performance Considerations
- Flash timers are updated alongside other per-frame behaviors in `_integrate_positions_and_behaviors()`
- Color calculation only occurs for enemies actively being rendered (viewport culling applied)
- Uses efficient packed arrays for minimal memory overhead

## Troubleshooting

### Flash Not Visible
1. Ensure MultiMesh has `use_colors = true`
2. Check that flash_timers array is properly sized
3. Verify damage_enemy() is being called when damage occurs

### Performance Issues
- Adjust FLASH_DURATION if needed (shorter = less processing)
- The effect is lightweight and should not impact performance significantly

## Future Improvements
- Could add different flash colors for different damage types
- Could add intensity variation based on damage amount
- Could add particle effects on top of the flash for critical hits