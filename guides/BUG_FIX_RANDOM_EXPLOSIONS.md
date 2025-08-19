# Bug Fix: Random Monster Explosions

## Issue
Monsters (especially twitch rats) were randomly exploding without the !explode command being typed.

## Root Cause
There were two issues causing this:

1. **Automatic Ability Execution**: The enemy_bridge.gd had logic that automatically triggered abilities based on distance and random chance. For the "explosion" ability, it had a 5% chance every ability check (10 times per second) when enemies were within 80 units of the player.

2. **Incorrect Command Routing**: The `_execute_command_on_all_entities` function in game_controller.gd was trying to call methods on entity objects, but the V2 enemy system uses data arrays, not objects with methods.

## Fix Applied

### 1. Disabled Automatic Abilities
In `systems/core/enemy_bridge.gd`, changed the `_should_use_ability` function to return false for command-triggered abilities:

```gdscript
match ability.id:
    "explosion":
        # Explosions should only happen via !explode command, not automatically
        return false
    "fart":
        # Farts should only happen via !fart command, not automatically
        return false
    "boost":
        # Boosts should only happen via !boost command, not automatically
        return false
```

### 2. Fixed Command Execution
In `game_controller.gd`, updated `_execute_command_on_all_entities` to properly route commands through the V2 system:

```gdscript
func _execute_command_on_all_entities(username: String, method_name: String):
    if not TicketSpawnManager.instance:
        return
    
    # Convert method names to command names for the V2 system
    var command = ""
    match method_name:
        "trigger_explode":
            command = "explode"
        "trigger_fart":
            command = "fart"
        "trigger_boost":
            command = "boost"
        _:
            print("Unknown command method: ", method_name)
            return
    
    # Use the proper V2 command execution system
    TicketSpawnManager.instance.execute_command_on_entities(username, command)
```

### 3. Removed Automatic Abilities from Config
In `systems/core/enemy_config_manager.gd`, removed the abilities from the rat configuration since they should only be command-triggered:

```gdscript
"abilities": [
    # Explosion, fart, and boost are command-triggered only, not automatic abilities
],
```

## Prevention
To prevent similar issues in the future:

1. **Clear Separation**: Keep command-triggered abilities separate from automatic AI abilities
2. **Consistent Routing**: Always use the proper system APIs (TicketSpawnManager/EnemyBridge) for command execution
3. **Testing**: Test both automatic abilities and command-triggered abilities separately
4. **Documentation**: Clearly document which abilities are automatic vs command-triggered

## Testing
To verify the fix:
1. Start the game and spawn some enemies
2. Get close to enemies - they should NOT randomly explode
3. Type !explode in chat - only then should your monsters explode
4. Test !fart and !boost commands work properly