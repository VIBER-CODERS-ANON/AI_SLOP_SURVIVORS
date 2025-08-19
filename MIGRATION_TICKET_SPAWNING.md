# Migration Guide: Old Spawning → Ticket System

## Quick Summary of Changes

### OLD SYSTEM (REMOVED)
- ❌ Spawned on every chat message
- ❌ One entity limit per chatter
- ❌ 60-second respawn cooldown
- ❌ `active_twitch_rats` tracked single entity
- ❌ Commands worked on one entity

### NEW SYSTEM (CURRENT)
- ✅ Chatters type `!join` to participate
- ✅ Multiple concurrent entities per chatter
- ✅ Ticket-based weighted spawning
- ✅ Monster power threshold (default: 5.0)
- ✅ Commands affect ALL chatter's entities

## Code Changes Required

### If you were checking `active_twitch_rats`:

**OLD:**
```gdscript
var entity = GameController.instance.active_twitch_rats.get(username)
if entity and is_instance_valid(entity):
    entity.do_something()
```

**NEW:**
```gdscript
var entities = TicketSpawnManager.instance.get_alive_entities_for_chatter(username)
for entity in entities:
    if is_instance_valid(entity):
        entity.do_something()
```

### If you were spawning entities:

**OLD:**
```gdscript
GameController.instance._spawn_twitch_rat(username, color)
```

**NEW:**
```gdscript
# Entities spawn automatically via ticket system
# Chatters must !join first
TicketSpawnManager.instance.handle_join_command(username)
```

### If you were tracking respawn cooldowns:

**OLD:**
```gdscript
rat_respawn_cooldowns[username] = Time.get_unix_time_from_system() + 60
```

**NEW:**
```gdscript
# No respawn cooldowns - ticket system handles everything
```

## Key Files Changed

### Removed/Deprecated
- `game_controller.gd`:
  - `_spawn_twitch_rat()` - Now empty
  - `active_twitch_rats` - No longer used
  - `rat_respawn_cooldowns` - Removed
  - `_on_twitch_rat_died()` - Removed
  - `max_rats_per_user` - Removed
  - `max_total_twitch_entities` - Removed

### Added
- `systems/ticket_spawn_manager.gd` - New spawning system
- `systems/mxp_modifiers/modifiers/ticket_modifier.gd` - Ticket upgrade

### Modified
- `game_controller.gd`:
  - `_handle_chat_message()` - Now handles !join
  - `_execute_command_on_all_entities()` - New helper
  - Commands (!fart, !explode, !boost) - Use new helper

## Testing the New System

1. **Start the game**
2. **Type in chat**: `!join`
3. **Watch monsters spawn** automatically
4. **Type**: `!fart` - ALL your monsters fart
5. **Use MXP**: `!ticket3` - Increase spawn chance

## Important Notes

- **Session-based**: Resets on game restart
- **No spawn limits**: Can have many entities
- **Power threshold**: Adjustable via `set_monster_power_threshold()`
- **Ticket values**: Rat=100, Succubus=33, Joe=20

## Troubleshooting

### "Nothing spawns!"
- Did chatters type `!join`?
- Check if session was reset

### "Too many/few monsters!"
- Adjust power threshold (default: 5.0)
- Check ticket values

### "Commands don't work!"
- Entities must be alive
- Check method names match

## For Developers

The new system is more flexible and scalable:
- Better performance (controlled spawning)
- More engaging (multiple entities)
- Fairer (weighted by monster type)
- Upgradeable (ticket modifier)

See `guides/TWITCH_SPAWNING_SYSTEM.md` for full documentation.