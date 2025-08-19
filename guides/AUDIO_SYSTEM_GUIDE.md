# Audio System Guide

## Overview
This guide covers best practices for implementing audio in abilities and entities, particularly for looping sounds and channeled abilities.

## Key Principles

### 1. Audio Player Creation
Create audio players during ability/entity initialization:
```gdscript
func on_added(holder) -> void:
    var entity = holder
    if holder.has_method("get_entity_node"):
        entity = holder.get_entity_node()
    if entity:
        succ_audio_player = AudioStreamPlayer2D.new()
        succ_audio_player.name = "SuccAudioPlayer"
        succ_audio_player.stream = load(audio_path)
        succ_audio_player.bus = "SFX"
        succ_audio_player.volume_db = -5.0
        entity.add_child(succ_audio_player)
```

### 2. Looping Audio for Channeled Abilities

#### DO: Start Audio After Validation
Start audio in the update loop after confirming the channel is valid:
```gdscript
func _update_channel(delta: float, holder) -> void:
    # Validate entity and target first
    if not entity or not is_instance_valid(channel_target):
        _end_channel()
        return
    
    # Start audio on first valid frame
    if succ_audio_player and not succ_audio_player.playing:
        var audio_stream = succ_audio_player.stream.duplicate()
        audio_stream.loop = true
        succ_audio_player.stream = audio_stream
        succ_audio_player.play()
```

#### DON'T: Start Audio Immediately
Never start audio in `_execute_ability()` as the channel might be cancelled instantly.

### 3. Stopping Audio Immediately

Use multiple redundant methods to ensure audio stops instantly:
```gdscript
func _stop_audio_immediately():
    if audio_player and is_instance_valid(audio_player):
        # Multiple methods to ensure immediate stop
        audio_player.stop()
        audio_player.playing = false
        audio_player.stream_paused = true
        
        # Clear stream entirely
        audio_player.stream = null
        
        # Reload non-looping version for next use
        if audio_path != "":
            var fresh_stream = load(audio_path)
            if fresh_stream:
                fresh_stream.loop = false
                audio_player.stream = fresh_stream
```

### 4. Cleanup on Removal
Always clean up audio players when abilities are removed:
```gdscript
func on_removed(holder) -> void:
    if is_channeling:
        _end_channel()
    
    if audio_player:
        audio_player.stop()
        audio_player.stream = null
        if audio_player.is_inside_tree():
            audio_player.get_parent().remove_child(audio_player)
        audio_player.queue_free()
        audio_player = null
    
    super.on_removed(holder)
```

## Common Issues and Solutions

### Issue: Audio continues playing after entity dies
**Solution**: Override die() to stop audio:
```gdscript
func die():
    var audio_player = get_node_or_null("AudioPlayerName")
    if audio_player:
        audio_player.stop()
        audio_player.playing = false
        audio_player.stream_paused = true
        audio_player.stream = null
    super.die()
```

### Issue: Audio plays for one frame when ability is cancelled
**Solution**: Start audio in update loop, not in execute function

### Issue: Looped audio doesn't stop when expected
**Solution**: Set stream to null after stopping, then reload a non-looping version

## Best Practices

1. **Duplicate Streams for Looping**: Always duplicate the stream before setting loop = true
2. **Use AudioStreamPlayer2D**: For positional audio in 2D games
3. **Set Appropriate Bus**: Use "SFX" bus for sound effects, "Music" for music
4. **Volume Control**: Start with reasonable defaults (-5.0 to 0.0 db)
5. **Null Checks**: Always check is_instance_valid() before accessing audio players
6. **Immediate Stops**: Use multiple stop methods for critical audio stops

## Audio Implementation Checklist

When implementing audio for an ability:
- [ ] Create AudioStreamPlayer2D in on_added()
- [ ] Load audio stream from resource path
- [ ] Set appropriate bus and volume
- [ ] Start audio after validation (not immediately)
- [ ] Duplicate stream before setting loop = true
- [ ] Stop audio using multiple methods
- [ ] Clean up in on_removed()
- [ ] Handle entity death cases