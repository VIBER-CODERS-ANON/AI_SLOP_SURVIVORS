# Twitch Entity Spawning System Guide

## Overview

The Twitch entity spawning system uses a **ticket-based pool mechanism** to control monster spawning. Instead of spawning on every chat message, chatters join a session and contribute tickets to a weighted spawning pool.

## Core Concepts

### 1. Session Management
- Chatters type `!join` once per game session to participate
- Sessions reset when the game restarts
- All joined chatters contribute to the ticket pool

### 2. Ticket System
Each monster type has a base ticket value (higher = more likely to spawn):

```gdscript
const MONSTER_TICKETS = {
    "twitch_rat": 100,      # Most common
    "succubus": 20,          # Equal to Joe (was 33)
    "woodland_joe": 20       # Rarer
}
```

### 3. Monster Power
Monster Power = `1 / ticket_value`
- Rat: 0.01 power (1/100)
- Succubus: 0.05 power (1/20)
- Woodland Joe: 0.05 power (1/20)

The system maintains a dynamically ramping monster power threshold:
- **Base**: Starts at 0.0
- **Time Ramp**: +0.002 every 1 second (0.12 per minute)
- **Boss Bonus**: +1.0 for each boss defeated
- **Total**: Base + Time + Boss bonuses

### 4. Concurrent Spawning
- Same chatter can have **multiple monsters alive** simultaneously
- No limit on concurrent entities per chatter
- More tickets = more likely to have multiple spawns

### 5. Off-Screen Spawning
Monsters always spawn outside the player's view for better gameplay:
- **Donut Zone**: Spawns in a ring 50-300 pixels outside camera view
- **Sector-based**: Divides spawn area into 8 sectors for even distribution
- **Dynamic**: Adjusts to camera zoom level
- **Safe spawning**: Avoids obstacles and stays within arena bounds
- **Smart fallbacks**: Multiple fallback systems if ideal position unavailable

## Implementation Details

### TicketSpawnManager (`systems/ticket_spawn_manager.gd`)

The core manager that handles:
- Session tracking
- Ticket pool management
- Monster spawning logic
- Power threshold maintenance

#### Key Methods

```gdscript
# Handle chatter joining
func handle_join_command(username: String) -> bool

# Rebuild ticket pool when upgrades change
func _rebuild_ticket_pool()

# Check and spawn monsters to maintain threshold
func _check_and_spawn()

# Get all alive entities for a chatter
func get_alive_entities_for_chatter(username: String) -> Array
```

### GameController Integration

```gdscript
# Commands now execute on ALL entities
func _execute_command_on_all_entities(username: String, method_name: String):
    var entities = TicketSpawnManager.instance.get_alive_entities_for_chatter(username)
    for entity in entities:
        if is_instance_valid(entity) and entity.has_method(method_name):
            entity.call(method_name)
```

## MXP Integration

### Ticket Modifier (`!ticket` command)
- Cost: 3 MXP per use
- Effect: +10% tickets per stack
- Max stacks: 10 (+100% spawn chance)

```gdscript
# In ticket_modifier.gd
func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
    var current_multiplier = chatter_data.upgrades.get("ticket_multiplier", 1.0)
    var bonus_per_stack = 0.1  # +10% per stack
    var new_multiplier = current_multiplier + (bonus_per_stack * amount)
    
    chatter_data.upgrades["ticket_multiplier"] = new_multiplier
    TicketSpawnManager.instance._rebuild_ticket_pool()
```

## Command System Updates

### Concurrent Execution
Commands now affect ALL of a chatter's alive monsters:

- `!explode` - All monsters explode
- `!fart` - All monsters fart (if not on cooldown)
- `!boost` - All monsters boost

Each entity maintains individual cooldowns.

## Configuration

### Tuning Parameters

```gdscript
# In TicketSpawnManager
var base_monster_power_threshold: float = 0.0  # Starting threshold
var spawn_check_interval: float = 0.5          # Check frequency
var max_spawn_per_tick: int = 5               # Spawn rate limit

# Off-screen spawn settings
var spawn_inner_margin: float = 50.0          # Min pixels from screen edge
var spawn_outer_margin: float = 300.0         # Max pixels from screen edge

# Ramping constants
const RAMP_INTERVAL: float = 1.0               # Time between ramps (1 second)
const RAMP_AMOUNT: float = 0.002               # Power per time ramp
const BOSS_DEATH_BONUS_AMOUNT: float = 1.0     # Power per boss kill
```

### Ramping System

The monster power threshold automatically increases over time:

```gdscript
# Simple addition formula:
threshold = base + time_bonus + boss_bonus

# Example after 60 seconds and 2 boss kills:
# 0.0 (base) + 0.12 (60 * 0.002) + 2.0 (2 bosses) = 2.12 total
```

### Getting Current Stats

```gdscript
# Get ramping information
var stats = GameController.instance.get_monster_power_stats()
print("Current threshold: ", stats.total)
print("Time bonus: ", stats.time_bonus)
print("Boss bonus: ", stats.boss_bonus)
print("Next ramp in: ", stats.time_to_next_ramp)
```

## Migration from Old System

### Removed Systems
- ❌ Spawn on every chat message
- ❌ One entity limit per chatter
- ❌ Respawn cooldown timers
- ❌ `active_twitch_rats` dictionary tracking
- ❌ `rat_respawn_cooldowns` dictionary

### New Systems
- ✅ `!join` command to participate
- ✅ Ticket-based weighted spawning
- ✅ Monster power threshold maintenance
- ✅ Multiple concurrent entities
- ✅ Session-based participation

## UI Display

### Monster Power Display
A clean, minimal UI component shows just the current monster power threshold as a number at the top center of the screen:

- **Just a number**: No labels, no bars, just "0.2" 
- **Grey default color**: Starts grey, transitions to red at higher values
- **1 decimal place**: Always shows one decimal for readability (even if actual value is 0.003)
- **Subtle Pulse**: Small scale animation when threshold changes significantly
- **Real-time Updates**: Directly references TicketSpawnManager
- **Small font**: 18px font size for minimal UI footprint
- **Positioned lower**: 60 pixels from top (was 20)

The display is a simple Label component (`ui/monster_power_display.gd`) that:
- Shows only the threshold value with one decimal place (cosmetic rounding)
- Updates smoothly with lerp for clean transitions
- Changes color based on difficulty level

## Testing Checklist

### Basic Functionality
- [ ] `!join` adds chatter to session
- [ ] Monsters spawn based on ticket weights
- [ ] Monster power stays near threshold
- [ ] Session resets on game restart
- [ ] Monster Power Display shows correct values
- [ ] Display updates on time ramps (every 10s)
- [ ] Display updates on boss kills (+1.0)

### Concurrent Spawning
- [ ] Same chatter has multiple monsters
- [ ] All monsters respond to commands
- [ ] Individual cooldowns work correctly
- [ ] Death reduces monster power properly

### MXP Integration
- [ ] `!ticket` command increases spawn rate
- [ ] Ticket pool rebuilds after upgrades
- [ ] Other MXP upgrades apply to all entities

## Example Flow

1. **Chatter joins**: Types `!join` in chat
2. **Added to pool**: 100 tickets added (if rat)
3. **System checks**: Total power < 5.0?
4. **Draw ticket**: Random selection from pool
5. **Spawn monster**: Create chatter's customized entity
6. **Track entity**: Add to alive_monsters array
7. **Monitor power**: Continuously maintain threshold
8. **Commands**: `!fart` makes ALL their monsters fart
9. **Death**: Power decreases, may trigger new spawns

## Best Practices

1. **Test with multiple chatters** to see ticket weighting
2. **Monitor performance** with many concurrent entities
3. **Adjust threshold** based on player difficulty preference
4. **Use debug prints** to track spawning patterns:

```gdscript
print("🎫 Monster power: %.2f / %.2f" % [current_monster_power, monster_power_threshold])
print("🎫 %s has %d monsters alive" % [username, entities.size()])
```

## Common Issues

### No Spawning
- Check if chatters have joined (`!join`)
- Verify ticket pool is not empty
- Check monster power threshold setting

### Too Many/Few Spawns
- Adjust `monster_power_threshold`
- Check ticket values for balance
- Verify power calculation is correct

### Commands Not Working
- Ensure entities are tracked in `alive_monsters`
- Check method names match exactly
- Verify entities have the methods

## Future Enhancements

Potential improvements to consider:
- Dynamic ticket values based on game state
- Special event multipliers
- Chatter-specific monster customization
- Team-based spawning pools
- Boss summon tickets