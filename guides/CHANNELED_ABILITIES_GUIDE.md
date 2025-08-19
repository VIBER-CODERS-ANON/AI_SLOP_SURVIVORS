# Channeled Abilities Implementation Guide

## Overview
Channeled abilities are abilities that require continuous casting over a period of time. During channeling, entities should typically stop moving unless the ability specifically allows movement.

## Key Principles

### 1. Movement Should Stop During Channeling
By default, channeled abilities should stop the entity's movement to indicate they are focusing on the ability.

### 2. Implementation Pattern
```gdscript
func _entity_physics_process(delta):
    # Stop movement during channeling
    if [your_channeled_ability] and [your_channeled_ability].is_channeling:
        movement_velocity = Vector2.ZERO
    
    # Call super to handle other physics updates
    super._entity_physics_process(delta)
    
    # Rest of your logic...
```

### 3. Allow Movement Exceptions
Some channeled abilities might allow movement (e.g., a "run and gun" style ability). In these cases, document it clearly and don't set movement_velocity to zero.

## Current Channeled Abilities

### 1. SuctionAbility (Succubus)
- **File**: `systems/ability_system/abilities/suction_ability.gd`
- **Description**: Life-draining beam that channels for 3 seconds
- **Movement**: STOPPED during channel
- **Implementation**: Succubus sets `movement_velocity = Vector2.ZERO` when `suction_ability.is_channeling`
- **Damage Delay**: 800ms delay before damage starts applying
- **Move-to-Range**: Ability requests movement to range if target is too far

### 2. SummonSwarmAbility (Forsen Boss)
- **File**: `systems/ability_system/abilities/summon_swarm_ability.gd`
- **Description**: 10-second channel that allows chat to summon warriors
- **Movement**: STOPPED during channel
- **Implementation**: Forsen sets `movement_velocity = Vector2.ZERO` when `is_channeling_swarm`

### 3. SuicideBombAbility (Ugandan Warrior)
- **File**: `systems/ability_system/abilities/suicide_bomb_ability.gd`
- **Description**: Brief charge-up before explosion
- **Movement**: ALLOWED (warrior charges at target)
- **Note**: This is more of a charge-up than a continuous channel

## Implementation Checklist

When creating a new channeled ability:

- [ ] Add `is_channeling` boolean to track channel state
- [ ] Set `is_channeling = true` when channel starts
- [ ] Set `is_channeling = false` when channel ends/breaks
- [ ] Handle channel interruption cases (target dies, out of range, etc.)
- [ ] Stop movement in entity's `_entity_physics_process` if needed
- [ ] Add visual/audio feedback for channeling state
- [ ] Clean up effects when channel ends

## Example: Creating a New Channeled Ability

```gdscript
# In your ability class
class_name MeditationAbility
extends BaseAbility

var is_channeling: bool = false
var channel_duration: float = 5.0
var channel_time_remaining: float = 0.0

func _execute_ability(holder, target_data) -> void:
    is_channeling = true
    channel_time_remaining = channel_duration
    # Start visual effects, sounds, etc.

func update(delta: float, holder) -> void:
    super.update(delta, holder)
    
    if is_channeling:
        channel_time_remaining -= delta
        
        if channel_time_remaining <= 0:
            _complete_channel()
        
        # Check for interruption conditions
        if _should_interrupt():
            _interrupt_channel()

func _complete_channel():
    is_channeling = false
    # Apply effects

func _interrupt_channel():
    is_channeling = false
    # Clean up
```

```gdscript
# In your entity class
func _entity_physics_process(delta):
    # Stop movement during meditation
    if meditation_ability and meditation_ability.is_channeling:
        movement_velocity = Vector2.ZERO
    
    super._entity_physics_process(delta)
```

## Common Issues and Solutions

### Issue: Entity moves during channel
**Solution**: Ensure `movement_velocity = Vector2.ZERO` is set before calling `super._entity_physics_process(delta)`

### Issue: Channel doesn't break when target dies
**Solution**: Check `is_instance_valid(target)` in the ability's update function

### Issue: Visual effects persist after channel ends
**Solution**: Always clean up effects in both completion and interruption cases

### Issue: Audio plays even when channel is instantly cancelled
**Solution**: Start audio in `_update_channel()` on first valid frame, not in `_execute_ability()`

### Issue: Audio doesn't stop immediately when channel breaks
**Solution**: Use multiple stop methods:
```gdscript
succ_audio_player.stop()
succ_audio_player.playing = false
succ_audio_player.stream_paused = true
succ_audio_player.stream = null
```

### Issue: Godot error "NOTIFICATION_INTERNAL_PROCESS not declared"
**Solution**: Don't use internal Godot notifications. The audio stop methods above are sufficient.

## Best Practices

1. **Clear Visual Feedback**: Use animations, particle effects, or color changes to show channeling state
2. **Audio Cues**: Loop audio during channel, stop immediately when interrupted
3. **Progress Indication**: Consider showing a progress bar or timer for long channels
4. **Interrupt Conditions**: Clearly define what breaks the channel (damage, movement, range)
5. **Resource Management**: Don't forget to clean up tweens, audio players, and visual effects
6. **Damage Delays**: Use damage delays for channeled abilities to give visual warning
7. **Audio Timing**: Start audio after validation, not immediately on execution
8. **Move-to-Range**: Emit signals to request movement if target is out of range
