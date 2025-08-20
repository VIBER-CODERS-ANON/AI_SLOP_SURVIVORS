# XP and MXP Scaling System

## Overview
Enemies have a chance to drop XP orbs with values scaled by their MXP spending. This creates a risk/reward dynamic where players benefit from letting enemies buff themselves, while reducing visual clutter through single high-value orbs.

## How It Works

### Base System (Updated)
- Enemies have 50% chance to drop XP
- Base XP value increased to 2 (from 1)
- Each MXP spent adds +2 to maximum potential XP
- Drops single orb with value rolled between 1 and max
- Example: Enemy with 5 MXP spent = max 12 XP (2 base + 10 MXP bonus), rolls 1-12

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

## XP Orb Visual System

### Color Tiers (1-100+ XP)
XP orbs change color based on their value (all orbs are the same size):

- **1-5 XP**: Gray → Brown
- **6-10 XP**: Red → Orange
- **11-20 XP**: Orange → Yellow (+ slight glow)
- **21-30 XP**: Yellow → Green
- **31-40 XP**: Green → Cyan
- **41-50 XP**: Cyan → Blue (+ more glow)
- **51-60 XP**: Blue → Purple
- **61-70 XP**: Purple → Pink
- **71-80 XP**: Pink → Gold (+ strong glow)
- **81-90 XP**: Gold → White
- **91-100+ XP**: Rainbow prismatic effect (animated)

## Strategy Implications
- Players can choose to let enemies buff for more XP rewards
- Risk: Buffed enemies are harder to kill
- Reward: More XP for leveling up faster, chance for high-value orbs
- Visual feedback: Different colors/glow effects = more value
- Twitch chat engagement: Viewers spending MXP helps the player indirectly

## Technical Notes
- Only works for enemies with usernames (Twitch chatter entities)
- Regular spawned enemies without usernames: 50% chance to drop 1-2 XP
- Single orb spawns instead of multiple to reduce clutter
- System is in `enemy_manager.gd` NOT `base_enemy.gd` (which is deprecated)
- All orbs are the same size - only color changes based on value

## Debugging
Enable debug logs to see MXP spending and XP drops:
```
DEBUG: Chatter 'username' spent 5 MXP, max XP: 12
```

## Future Considerations
- Could add multipliers for rare enemies
- Could add bonus XP for specific upgrade combinations
- Keep implementation in enemy_manager.gd for performance