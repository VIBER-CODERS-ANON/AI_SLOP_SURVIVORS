# Bug Fix: Succubus Random Bite Damage

## Issue Description
The succubus was randomly killing the player with "bite" attacks, seemingly out of nowhere. This was unexpected behavior for a ranged unit that should only damage through its abilities (heart projectiles and life drain).

## Root Cause
The issue was caused by multiple factors:

1. **Contact Damage**: Succubus had `damage = 5.0` which is contact/melee damage
2. **Large Attack Range**: When I doubled the heart projectile range, I also set `attack_range = 300.0`
3. **Base Enemy Behavior**: The base enemy class automatically performs attacks when a player is within `attack_range`
4. **Default Attack Name**: Base enemy's `get_attack_name()` returns "bite" by default
5. **Movement During Channel**: When succubus stops to channel suction, players could get within the 300 unit attack range

## The Attack Chain
1. Succubus channels suction ability and stops moving
2. Player is within 300 units (the large attack_range)
3. Base enemy's `_entity_physics_process()` detects player in range
4. Calls `_perform_attack()` which deals 5 damage
5. Death message shows "[Succubus Name] bite" as the cause

## Fix Applied

### 1. Removed Contact Damage
```gdscript
damage = 0.0  # No contact damage - succubus only damages through abilities
```

### 2. Override Attack Method
```gdscript
func _perform_attack():
    # Succubus doesn't do contact damage - only abilities
    pass
```

### 3. Fixed Attack Name
```gdscript
func get_attack_name() -> String:
    return "magic"  # Instead of default "bite"
```

### 4. Bonus Fix: Sprite Direction
Also fixed the sprite direction code to use proper MXP-compatible scaling instead of `flip_h`.

## Prevention
- When creating ranged units, always set `damage = 0` if they should only use abilities
- Be careful with `attack_range` - it controls both ability range AND contact damage range
- Override `_perform_attack()` for units that shouldn't have contact damage
- Always test edge cases like "what happens when the player gets close"

## Key Takeaway
Inherited behavior from base classes can cause unexpected interactions. Always consider what the base class does and override behaviors that don't apply to specialized units.
