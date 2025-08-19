# Bug Fix: Channeled Abilities Not Stopping Movement

## Issue Description
Channeled abilities (like Succubus' suction and Forsen's summon swarm) were not stopping entity movement during their channel duration. This made it appear as if the abilities weren't channeling properly and entities could move while supposedly focusing on their abilities.

## Root Cause
The channeled abilities tracked their channeling state with `is_channeling` flags, but the entity movement logic wasn't checking these flags to stop movement.

## Fix Applied

### 1. Succubus (SuctionAbility)
In `entities/enemies/succubus.gd`:
```gdscript
func _entity_physics_process(delta):
    # Stop movement during channeling
    if suction_ability and suction_ability.is_channeling:
        movement_velocity = Vector2.ZERO
        # Still need to call super for other physics updates
        super._entity_physics_process(delta)
        return
    
    # Normal movement logic...
```

### 2. Forsen Boss (SummonSwarmAbility)
In `entities/enemies/bosses/forsen_boss.gd`:
```gdscript
func _entity_physics_process(delta: float):
    # Stop movement during channeling
    if is_channeling_swarm:
        movement_velocity = Vector2.ZERO
    
    super._entity_physics_process(delta)
    # Rest of logic...
```

## How to Avoid in Future

1. **Always Consider Movement**: When creating channeled abilities, explicitly decide if movement should be allowed or stopped.

2. **Standard Pattern**: Use this pattern for channeled abilities that stop movement:
   ```gdscript
   if [ability] and [ability].is_channeling:
       movement_velocity = Vector2.ZERO
   ```

3. **Documentation**: Created `CHANNELED_ABILITIES_GUIDE.md` to standardize channeled ability implementation.

4. **OOP Consideration**: For a more scalable solution, consider creating a `ChanneledAbility` base class that:
   - Tracks channeling state
   - Provides hooks for movement control
   - Handles common channeling mechanics (interruption, completion, etc.)
   - Automatically notifies the entity to stop/allow movement

5. **Entity State Machine**: Consider implementing a state machine for entities where channeling is a distinct state that automatically handles movement restrictions.

## Key Takeaway
Channeled abilities need explicit movement handling. The ability system and movement system are separate, so they need to be explicitly connected when certain abilities should affect movement.
