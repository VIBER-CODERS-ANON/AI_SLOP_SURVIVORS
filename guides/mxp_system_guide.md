# MXP System Guide

## Overview
The MXP (Monster Experience Points) system allows Twitch chat viewers to upgrade their spawned entities using chat commands. This guide covers how the system works and how to ensure proper integration with V2 enemies.

## System Architecture

### Key Components
- `MXPManager`: Tracks MXP balance and spending for each chatter
- `MXPModifierManager`: Processes chat commands and applies modifiers
- `ChatterEntityManager`: Stores upgrade data and applies to entities
- `EnemyManager`: V2 enemy system that uses upgrade values

### Available Commands
- `!hp` / `!hp5` / `!hpmax`: Increase entity health (+5 HP per MXP)
- `!speed` / `!speed5` / `!speedmax`: Increase movement speed (+5 speed per MXP)
- `!attackspeed`: Increase attack rate (+0.1 attacks/sec per MXP)
- `!aoe`: Increase area of effect (+5% per MXP)
- `!regen`: Add health regeneration (+1 HP/sec per MXP)
- `!ticket`: Increase spawn chance (+10% tickets per 3 MXP)
- `!gamble`: 7.77% chance to win 10 MXP per MXP gambled

## V2 Enemy Integration

### Critical Integration Points

1. **On Spawn (enemy_manager.gd:540-571)**
   - Applied in `spawn_enemy()` function
   - Reads upgrades from ChatterEntityManager
   - Modifies base stats before entity becomes active

2. **Live Updates (chatter_entity_manager.gd:209-267)**
   - `_update_active_entity()` updates existing enemies
   - Triggered when modifiers are applied via chat
   - Searches for all enemies with matching username

### Adding New MXP Modifiers

1. Create modifier class in `systems/mxp_modifiers/modifiers/`
2. Extend `BaseMXPModifier`
3. Store upgrade value in chatter_data.upgrades dictionary
4. Add application logic to:
   - `enemy_manager.spawn_enemy()` for new spawns
   - `chatter_entity_manager._update_active_entity()` for live updates

### Common Issues & Solutions

**Issue**: MXP upgrades not applying to V2 enemies
**Solution**: Ensure upgrade is applied in both spawn and update functions

**Issue**: Regeneration not working
**Solution**: Check that `regen_rates` array is initialized and `_update_enemy_regeneration()` is called

**Issue**: AOE upgrades not affecting abilities  
**Solution**: Abilities must read `aoe_scales[enemy_id]` from EnemyManager

## Data Flow

1. Chat command → TwitchConnection
2. TwitchConnection → MXPModifierManager.process_command()
3. MXPModifierManager → Modifier.execute()
4. Modifier → ChatterEntityManager (stores upgrade)
5. ChatterEntityManager → Signal to update active entities
6. EnemyManager reads upgrades on spawn/update

## Upgrade Storage Format

Upgrades stored in `ChatterEntityManager.chatter_data[username].upgrades`:
```gdscript
{
  "bonus_health": 15,          # Flat HP bonus
  "bonus_move_speed": 10,      # Flat speed bonus
  "bonus_attack_speed": 0.3,   # Attacks/sec bonus
  "bonus_aoe": 0.25,           # AOE multiplier (25% increase)
  "regen_flat_bonus": 2.0,     # HP/sec regeneration
  "ticket_multiplier": 1.3     # Spawn chance multiplier
}
```

## Testing Checklist

- [ ] Spawn entity with !summon command
- [ ] Apply !hp upgrade and verify health increases
- [ ] Apply !speed upgrade and verify movement speed increases
- [ ] Apply !attackspeed and verify attack rate increases
- [ ] Apply !regen and verify health regenerates over time
- [ ] Apply !aoe and verify ability ranges increase
- [ ] Use !ticket and verify increased spawn frequency
- [ ] Test live updates affect already-spawned enemies

## Performance Considerations

- Upgrades are cached in arrays for V2 enemies
- No per-frame lookups to ChatterEntityManager
- Regeneration processed in enemy update slice
- Live updates iterate only affected enemies

## Debug Commands

- Check enemy stats: Look for debug overlay showing array values
- Monitor upgrade application: Check console logs for upgrade messages
- Verify array sizes: Ensure aoe_scales and regen_rates match other arrays