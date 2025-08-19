# Common Godot Errors and Fixes

## Overview
This document catalogs common Godot errors encountered in the project and their solutions.

## Error: "Identifier not declared in the current scope"

### Example
```
Line 315: Identifier "NOTIFICATION_INTERNAL_PROCESS" not declared in the current scope.
```

### Cause
Trying to use internal Godot constants or notifications that aren't exposed to GDScript.

### Solution
Don't use internal notifications. Use alternative approaches:

**BAD:**
```gdscript
if audio_player.has_method("_notification"):
    audio_player._notification(NOTIFICATION_INTERNAL_PROCESS)
```

**GOOD:**
```gdscript
# Just use the standard stop methods
audio_player.stop()
audio_player.playing = false
audio_player.stream_paused = true
```

## Error: "Invalid get index" on null instance

### Cause
Trying to access properties or methods on a null or freed object.

### Solution
Always check validity before accessing:

```gdscript
if target and is_instance_valid(target):
    var pos = target.global_position
```

## Error: "Attempt to call function on a null instance"

### Cause
Calling methods on objects that don't exist or have been freed.

### Solution
Use safe navigation patterns:

```gdscript
# Check if node exists
var audio_player = get_node_or_null("AudioPlayer")
if audio_player:
    audio_player.stop()

# Check if object has method
if entity.has_method("take_damage"):
    entity.take_damage(10)
```

## Error: Audio continues playing after entity death

### Cause
Audio players not being properly cleaned up when entities are freed.

### Solution
Override die() and _exit_tree() to clean up audio:

```gdscript
func die():
    # Stop all audio
    var audio_player = get_node_or_null("AudioPlayer")
    if audio_player:
        audio_player.stop()
        audio_player.stream = null
    super.die()

func _exit_tree():
    # Clean up audio players
    if audio_player:
        audio_player.queue_free()
```

## Error: "Cyclic reference" or memory leaks

### Cause
Circular references between objects preventing garbage collection.

### Solution
- Use `weakref()` for back-references
- Clear references in cleanup functions
- Remove signal connections when done

```gdscript
func _exit_tree():
    # Disconnect signals
    if target_enemy:
        if target_enemy.died.is_connected(_on_target_died):
            target_enemy.died.disconnect(_on_target_died)
    
    # Clear references
    target_enemy = null
    owner_entity = null
```

## Error: Tweens not stopping/continuing after pause

### Cause
Tweens not respecting pause state or not being killed properly.

### Solution
Always kill tweens before creating new ones:

```gdscript
func start_animation():
    # Kill existing tween
    if tween:
        tween.kill()
    
    # Create new tween
    tween = create_tween()
    tween.set_loops()
    # ...
```

## Error: "Physics body moved by code" warnings

### Cause
Moving physics bodies outside of physics process.

### Solution
Only modify physics body positions in `_physics_process()`:

```gdscript
# BAD - in _ready() or _process()
position = Vector2(100, 100)

# GOOD - in _physics_process()
func _physics_process(delta):
    position = Vector2(100, 100)
    # or use physics methods
    move_and_slide()
```

## Error: Signals not connecting

### Cause
Trying to connect signals before nodes are ready.

### Solution
Use `call_deferred()` or await ready:

```gdscript
func _ready():
    # Defer connection
    call_deferred("_setup_connections")

func _setup_connections():
    ability.request_move.connect(_on_request_move)

# Or use await
func _ready():
    await get_tree().process_frame
    ability.request_move.connect(_on_request_move)
```

## Best Practices to Avoid Errors

1. **Always check validity**: Use `is_instance_valid()` before accessing objects
2. **Clean up properly**: Override `_exit_tree()` and `die()` for cleanup
3. **Use safe navigation**: Check for null with `get_node_or_null()`
4. **Kill tweens**: Always kill existing tweens before creating new ones
5. **Defer when needed**: Use `call_deferred()` for operations that need to happen after current frame
6. **Clear references**: Set object references to null when done
7. **Disconnect signals**: Always disconnect signals when objects are freed

## Debugging Tips

1. **Enable Debug Collision Shapes**: Project Settings → Debug → Settings → Visible Collision Shapes
2. **Use Print Statements**: Liberal use of `print()` to track execution flow
3. **Check Remote Inspector**: Use the remote inspector to see live scene tree
4. **Monitor Performance**: Use the Profiler to identify performance issues
5. **Enable Verbose Output**: Project Settings → Debug → Settings → Verbose stdout