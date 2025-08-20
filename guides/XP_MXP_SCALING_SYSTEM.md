# XP and MXP Scaling System

## Overview
Enemies drop additional XP orbs based on how much MXP (Monster XP) they've spent on upgrades. This creates a risk/reward dynamic where players benefit from letting enemies buff themselves.

## How It Works

### Base System
- All enemies drop 1 base XP orb when killed
- Each MXP spent by the enemy adds +1 additional XP orb
- Example: Enemy that spent 5 MXP drops 6 total XP orbs (1 base + 5 bonus)

### Implementation Location
The XP scaling is implemented in `systems/core/enemy_manager.gd` in the `_drop_xp_orb()` function:

```gdscript
func _drop_xp_orb(enemy_id: int):
    # Base XP value
    var xp_to_drop = 1
    
    # Scale XP based on MXP buffs if this is a chatter entity
    var username = chatter_usernames[enemy_id]
    if username != "" and ChatterEntityManager.instance:
        var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
        var total_mxp_spent = chatter_data.get("total_upgrades", 0)
        
        # Each MXP spent increases XP drop by 1
        xp_to_drop += total_mxp_spent
```

## MXP Commands and Their Costs
- `!hp` - 1 MXP per HP
- `!speed` - 1 MXP per speed boost  
- `!attackspeed` - 1 MXP per attack speed boost
- `!aoe` - 1 MXP per AoE increase
- `!regen` - 1 MXP per regen point
- `!ticket` - 3 MXP per ticket
- `!gamble` - 1 MXP per gamble

## Strategy Implications
- Players can choose to let enemies buff for more XP rewards
- Risk: Buffed enemies are harder to kill
- Reward: More XP for leveling up faster
- Twitch chat engagement: Viewers spending MXP helps the player indirectly

## Technical Notes
- Only works for enemies with usernames (Twitch chatter entities)
- Regular spawned enemies without usernames drop base 1 XP
- XP orbs spawn in a circle pattern when multiple drop
- System is in `enemy_manager.gd` NOT `base_enemy.gd` (which is deprecated)

## Debugging
Enable debug logs to see MXP spending and XP drops:
```
DEBUG: Chatter 'username' spent 5 MXP, dropping 6 XP orbs
```

## Future Considerations
- Could add multipliers for rare enemies
- Could add bonus XP for specific upgrade combinations
- Keep implementation in enemy_manager.gd for performance