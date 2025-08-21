# Buff System Implementation Guide

## Overview
This guide documents the buff system implementation in AI SLOP SURVIVORS, focusing on temporary effects that modify entity stats for a limited duration.

## First Buff: !boost Command

### Specifications
- **Effect**: +500 flat movement speed
- **Duration**: 1 second
- **Cooldown**: 60 seconds per entity
- **Cost**: Free (no MXP required)
- **Visual**: Yellow flash effect
- **Tags**: ["Buff", "Duration", "Movement", "Speed", "Temporary", "Command"]

## Technical Architecture

### Data-Oriented Implementation (V2 Enemies)

The buff system uses parallel arrays in `EnemyManager` for high-performance tracking:

```gdscript
# Buff tracking arrays
var last_boost_times: PackedFloat32Array      # When buff was last used
var temporary_speed_boosts: PackedFloat32Array # Current active bonus
var boost_end_times: PackedFloat32Array       # When buff expires

# Constants
const BOOST_COOLDOWN: float = 60.0
const BOOST_FLAT_BONUS: float = 500.0  
const BOOST_DURATION: float = 1.0
```

### Command Flow

1. **TwitchManager** receives "!boost" command
2. **GameController** translates to internal command:
   - Receives "!boost" → calls `_execute_command_on_all_entities(username, "trigger_boost")`
3. **Translation Layer** converts prefix:
   - "trigger_boost" → "boost"
4. **TicketSpawnManager** routes to entities:
   - Gets all alive entities for chatter
   - Calls `EnemyBridge.execute_command_for_enemy(entity_id, "boost")`
5. **EnemyBridge** applies buff:
   - Checks cooldown
   - Sets buff values in arrays
   - Creates visual effects
   - Reports to activity feed
6. **EnemyManager** applies movement:
   - Calculates: `effective_speed = move_speeds[id] + temporary_speed_boosts[id]`
   - Checks expiry each physics frame

## Implementation Details

### Initialization (Spawn)
```gdscript
# In spawn_enemy - make boost available immediately
last_boost_times[id] = -BOOST_COOLDOWN
temporary_speed_boosts[id] = 0.0
boost_end_times[id] = 0.0
```

### Application (EnemyBridge)
```gdscript
func execute_command_for_enemy(enemy_id: int, command: String):
    if command == "boost":
        var current_time = Time.get_ticks_msec() / 1000.0
        
        # Check cooldown
        if current_time - enemy_manager.last_boost_times[enemy_id] < enemy_manager.BOOST_COOLDOWN:
            return
        
        # Apply buff
        enemy_manager.temporary_speed_boosts[enemy_id] = enemy_manager.BOOST_FLAT_BONUS
        enemy_manager.boost_end_times[enemy_id] = current_time + enemy_manager.BOOST_DURATION
        enemy_manager.last_boost_times[enemy_id] = current_time
        
        # Visual effect
        _add_boost_visual_effect(enemy_id)
        
        # Activity feed
        var feed = GameController.instance.get_action_feed()
        if feed:
            feed.add_message("⚡ %s used BOOST!" % username, Color(1.0, 1.0, 0.3))
```

### Movement Calculation
```gdscript
# In _update_enemy_movement
var effective_speed: float = move_speeds[id] + temporary_speed_boosts[id]
velocities[id] = combined_direction * effective_speed * delta
```

### Expiry Check
```gdscript
# In _physics_process
if boost_end_times[id] > 0 and current_time >= boost_end_times[id]:
    temporary_speed_boosts[id] = 0.0
    boost_end_times[id] = 0.0
    # Remove visual effect via flash timer system
```

## Common Issues & Solutions

### Issue 1: Command Not Working
**Problem**: !boost command does nothing
**Solution**: Check command routing:
1. Ensure command is not commented out in `game_controller.gd`
2. Verify translation layer converts "trigger_boost" → "boost"
3. Check entities are properly tracked in `alive_monsters` dictionary

### Issue 2: Boost Not Available on Spawn
**Problem**: Entities can't boost immediately after spawning
**Solution**: Initialize `last_boost_times[id] = -BOOST_COOLDOWN` instead of `0.0`

### Issue 3: Action Feed Crash
**Problem**: "Invalid access to property 'action_feed'"
**Solution**: Use `get_action_feed()` method instead of direct property access:
```gdscript
var feed = GameController.instance.get_action_feed()
if feed:
    feed.add_message(...)
```

### Issue 4: Visual Effect Not Showing
**Problem**: No yellow flash when boost activates
**Solution**: Check flash timer system in EnemyManager:
- Ensure `flash_timers[id]` is set to duration
- Verify color modulation in render code

## Adding New Buffs

### Step 1: Define Arrays
Add to EnemyManager:
```gdscript
var last_[buff]_times: PackedFloat32Array
var temporary_[buff]_values: PackedFloat32Array
var [buff]_end_times: PackedFloat32Array

const [BUFF]_COOLDOWN: float = 30.0
const [BUFF]_VALUE: float = 100.0
const [BUFF]_DURATION: float = 2.0
```

### Step 2: Initialize on Spawn
```gdscript
last_[buff]_times[id] = -[BUFF]_COOLDOWN
temporary_[buff]_values[id] = 0.0
[buff]_end_times[id] = 0.0
```

### Step 3: Add Command Handler
In EnemyBridge.execute_command_for_enemy():
```gdscript
"[buff]":
    # Check cooldown
    # Apply buff
    # Create visual effect
    # Report to feed
```

### Step 4: Apply in Update Loop
Modify relevant calculation (movement, damage, defense, etc.)

### Step 5: Check Expiry
Add to _physics_process expiry checks

## Best Practices

1. **Always use flat bonuses for temporary buffs** - Easier to add/remove cleanly
2. **Track per-entity cooldowns** - Prevents spam while allowing tactical use
3. **Initialize to negative cooldown** - Makes buffs immediately available
4. **Use flash timer system for visuals** - Integrates with damage flash
5. **Report to activity feed** - Player awareness is crucial
6. **Use trigger_ prefix pattern** - Maintains consistency with command system

## Future Enhancements

- Stack multiple buffs of different types
- Buff immunity periods
- Debuff system (negative temporary effects)
- Buff stealing/transferring mechanics
- Visual buff indicators (icons/particles)
- Buff refresh mechanics
- Conditional buffs (only while moving, only while stationary, etc.)