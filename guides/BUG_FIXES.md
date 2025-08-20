# Bug Fixes Documentation

## AOE Scaling Not Applied to Explosions (Fixed 2025-08-19)
**Issue**: The !aoemax command wasn't applying to monster explosion abilities.

**Root Cause**: 
1. ChatterEntityManager was looking for "aoe_multiplier" but MXP system stores it as "bonus_aoe"
2. V2 enemy explosions weren't getting AOE scale applied
3. Command explosions (!explode) also missed AOE scaling

**Fix**:
1. Updated ChatterEntityManager to use "bonus_aoe" field: `(1.0 + bonus_aoe) * rarity_multiplier`
2. Modified enemy_bridge._trigger_explosion() to apply chatter's AOE bonus to both visual and damage radius
3. Updated ticket_spawn_manager explosion commands to pass username for AOE scaling

**Prevention**: Always check that upgrade field names match between systems when modifying stat systems.