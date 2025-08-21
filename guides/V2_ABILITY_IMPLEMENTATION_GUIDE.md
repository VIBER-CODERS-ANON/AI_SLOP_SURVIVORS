# V2 Enemy Ability Implementation Guide

## Overview
This guide explains how to implement abilities for data-oriented (V2) enemies in AI SLOP SURVIVORS. V2 enemies store their state in arrays rather than nodes, requiring special patterns for ability execution.

## Two Patterns for V2 Abilities

### Pattern 1: Simple Effects (Recommended for most cases)
Use this for instant effects like explosions, spawning clouds, or one-shot damage.

```gdscript
func _trigger_explosion(enemy_id: int, pos: Vector2, config: Dictionary):
    # Get username for attribution
    var username = ""
    if enemy_manager and enemy_id >= 0 and enemy_id < enemy_manager.chatter_usernames.size():
        username = enemy_manager.chatter_usernames[enemy_id]
    
    # Create effect directly
    var explosion = load("res://entities/effects/explosion_effect.tscn").instantiate()
    explosion.global_position = pos
    explosion.source_name = username  # For death attribution
    explosion.set_meta("source_name", username)
    
    # Apply any upgrades
    if username != "" and ChatterEntityManager.instance:
        var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
        if chatter_data and chatter_data.upgrades.has("bonus_aoe"):
            explosion.applied_aoe_scale = (1.0 + chatter_data.upgrades.bonus_aoe)
    
    GameController.instance.add_child(explosion)
```

**When to use:**
- Instant damage effects
- Environmental hazards
- Simple projectiles
- Visual effects

### Pattern 2: V2AbilityProxy (For complex abilities)
Use this for abilities that need to track state, channel over time, or use existing ability classes.

```gdscript
func _start_suction_ability(enemy_id: int, pos: Vector2, config: Dictionary):
    # Get username for attribution
    var username = ""
    if enemy_manager and enemy_id >= 0 and enemy_id < enemy_manager.chatter_usernames.size():
        username = enemy_manager.chatter_usernames[enemy_id]
    
    # Create proxy
    var proxy = V2AbilityProxy.new()
    proxy.name = "AbilityProxy_%d" % enemy_id
    proxy.global_position = pos
    GameController.instance.add_child(proxy)
    
    # Setup proxy with enemy tracking
    proxy.setup(enemy_id, enemy_manager, username)
    
    # Create target data
    var target_data = {
        "target_enemy": GameController.instance.player,
        "target_position": GameController.instance.player.global_position
    }
    
    # Attach and execute ability
    if proxy.attach_ability(SuctionAbility, target_data):
        # Clean up when done
        if proxy.tracked_ability.has_signal("succ_ended"):
            proxy.tracked_ability.succ_ended.connect(func():
                proxy.queue_free()
            )
    else:
        proxy.queue_free()
```

**When to use:**
- Channeled abilities
- Abilities with complex state
- Reusing existing ability classes
- Abilities that need position tracking

## The V2AbilityProxy Class

The proxy handles:
- **Position tracking**: Follows the V2 enemy's position in arrays
- **Movement control**: Stops enemy movement during channels
- **Ability lifecycle**: Creates, updates, and cleans up ability instances
- **Attribution**: Provides methods for damage attribution
- **Cleanup**: Ensures proper cleanup if enemy dies

Key features:
```gdscript
class_name V2AbilityProxy

# Automatically tracks enemy position
func _update_position()
# Stops/restores movement for channeled abilities  
func _stop_movement() / _restore_movement()
# Provides interface for abilities
func get_chatter_username() -> String
func get_display_name() -> String
```

## Implementation Checklist

When adding a new V2 ability:

1. **Choose the pattern**:
   - Simple effect? → Direct instantiation
   - Complex/channeled? → V2AbilityProxy

2. **Get attribution data**:
   ```gdscript
   var username = enemy_manager.chatter_usernames[enemy_id]
   ```

3. **Apply upgrades** (if applicable):
   ```gdscript
   var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
   var aoe_scale = 1.0 + chatter_data.upgrades.get("bonus_aoe", 0.0)
   ```

4. **Set damage source** (for attribution):
   ```gdscript
   effect.source_name = username
   effect.set_meta("source_name", username)
   ```

5. **Handle cleanup**:
   - Simple effects clean themselves up
   - Proxy needs explicit cleanup on ability end

## Common Mistakes to Avoid

### 1. Over-engineering Simple Effects
```gdscript
# BAD - Using proxy for simple explosion
var proxy = V2AbilityProxy.new()
proxy.attach_ability(ExplosionAbility, ...)

# GOOD - Direct instantiation
var explosion = explosion_scene.instantiate()
explosion.global_position = pos
```

### 2. Forgetting Attribution
```gdscript
# BAD - No username set
var effect = effect_scene.instantiate()

# GOOD - Proper attribution
var effect = effect_scene.instantiate()
effect.source_name = username
effect.set_meta("source_name", username)
```

### 3. Not Handling Enemy Death
```gdscript
# BAD - Proxy continues after enemy dies
proxy.setup(enemy_id, enemy_manager, username)

# GOOD - Proxy auto-cleans on enemy death (handled in V2AbilityProxy)
# The proxy's _update_position() checks alive_flags
```

## Examples from Codebase

### Explosion (Simple Effect)
Located in: `enemy_bridge.gd::_trigger_explosion()`
- Direct instantiation
- Sets damage, radius, AOE scale
- Adds attribution
- Self-contained cleanup

### Poison Cloud (Simple Effect)  
Located in: `enemy_bridge.gd::_trigger_fart_cloud()`
- Direct instantiation
- Sets duration, damage
- Adds attribution
- Timer-based cleanup

### Suction (Complex Ability)
Located in: `enemy_bridge.gd::_start_suction_ability()`
- Uses V2AbilityProxy
- Channels over time
- Stops movement
- Tracks position
- Complex cleanup

## Testing V2 Abilities

1. **Check attribution**: Kill messages show correct username
2. **Verify cleanup**: No lingering effects after enemy death
3. **Test at scale**: Abilities work with 100+ enemies
4. **Check movement**: Channeled abilities stop movement
5. **Verify visuals**: Effects appear at correct positions

## Performance Considerations

- **Simple effects**: Minimal overhead, just instantiation
- **V2AbilityProxy**: Adds position tracking overhead
- **Use pooling**: For frequently spawned effects
- **Cleanup timers**: Always set max lifetimes
- **Batch operations**: Update multiple abilities per frame

## Future Improvements

- Object pooling for proxies
- Batch ability updates
- Shared proxy for multiple abilities
- Direct array manipulation for simple buffs (like boost)