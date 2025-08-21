# Testing & Debug Cheats

This document outlines all available cheats and testing functionality for development.

## Keyboard Cheats (Development)

### Core Testing
- **Ctrl+1**: Toggle God Mode (invulnerability)
- **Ctrl+2**: Grant 100 XP orbs around player
- **Ctrl+3**: Force level up
- **Ctrl+4**: Trigger boss vote
- **F1**: Grant 100 XP orbs around player
- **F2**: Grant 10 MXP to all chatters
- **F3**: Grant player health boost

### Enemy Spawning
- **Alt+1**: Spawn 5 test rats
- **Alt+2**: Spawn 3 succubus
- **Alt+3**: Spawn 1 woodland joe
- **Alt+4**: Spawn ugandan warriors
- **Alt+5**: Clear all enemies

### Boss Spawning  
- **Alt+6**: Trigger boss vote
- **Alt+7**: Spawn Thor boss
- **Alt+8**: Spawn Mika boss
- **Alt+9**: Spawn Forsen boss  
- **Alt+0**: Spawn ZZran boss

### System Controls
- **Escape**: Toggle pause menu
- **F12**: Toggle debug overlay (if available)

## Twitch Integration Testing

### Real Twitch Connection (Default)
The game connects to Twitch chat automatically:
- **No API keys required** - uses anonymous IRC
- **Default channel**: Set in game settings
- **Channel switching**: Available in pause menu settings
- **Commands work immediately** once connected

### Mock Chat Mode (Offline Testing)
For testing without Twitch connection:

1. **Enable in Code** - Add to `TwitchBot` node:
   ```gdscript
   # In TwitchBot _ready() method
   enable_mock_chat(true)
   ```

2. **Mock Behavior**:
   - Sends random chat messages every 3-5 seconds
   - Includes commands: !join, !explode, !fart, !boost
   - Uses random usernames and colors
   - Simulates real chat patterns

## Chat Commands (Available to Test)

### Entity Management
- `!join` - Join the monster pool (once per session)
- `!explode` - All your monsters explode (damage nearby)  
- `!fart` - All your monsters create poison clouds
- `!boost` - All your monsters get speed boost

### Evolutions (Costs MXP)
- `!evolve succubus` - Evolve to flying heart-shooter (10 MXP)
- `!evolve woodlandjoe` - Evolve to tank miniboss (5 MXP)

### MXP Upgrades (Permanent)
- `!hp <amount>` - +5 health per MXP spent
- `!speed <amount>` - +5 movement speed per MXP spent  
- `!attackspeed <amount>` - +1% attack speed per MXP spent
- `!aoe <amount>` - +5% ability area per MXP spent
- `!regen <amount>` - +1 HP/sec regeneration per MXP spent
- `!ticket <amount>` - +10% spawn chance per MXP spent

### Boss Voting
- `!vote1` - Vote for first boss option
- `!vote2` - Vote for second boss option  
- `!vote3` - Vote for third boss option

## System Architecture Notes

### Enemy Types
- **Minions**: rats, succubus, woodland_joe (multimesh system)
- **Bosses**: thor, mika, forsen, zzran (node-based scripts)

### Key Systems to Test
- **TicketSpawnManager**: Handles `!join` and spawning
- **EnemyManager**: Multimesh rendering and physics
- **BossFactory**: Individual boss creation
- **MXPManager**: Chat currency system
- **CommandProcessor**: All chat command handling

## Performance Testing

### Scaling Tests
- Spawn 1000+ rats with Alt+1 (hold down)
- Test framerate with many entities
- Check memory usage in task manager
- Verify multimesh rendering performance

### System Stress Tests  
- Multiple chatters using commands simultaneously
- Boss fights with many minions active
- Rapid evolution commands
- MXP upgrade spam testing

## Common Issues & Solutions

### Twitch Connection Problems
- Check internet connection
- Verify channel name spelling
- Try switching to mock chat mode
- Check console for connection errors

### Performance Issues
- Too many enemies: Use Alt+5 to clear
- Low framerate: Check multimesh instance counts
- Memory leaks: Restart game session

### Command Not Working
- Ensure user has joined with `!join` first
- Check MXP balance for paid commands  
- Verify correct command syntax
- Look for error messages in action feed

## Implementation Details

### Cheat System
- **Input handled by**: `InputManager` (`systems/core/input_manager.gd`)
- **Cheat execution**: `CheatManager` (`systems/core/cheat_manager.gd`)
- **Always enabled** in development builds
- **Key combinations** prevent accidental triggers

### Mock Chat System
- **Location**: `TwitchBot` (`systems/twitch_system/twitch_bot.gd`)
- **Random messages**: Realistic chat patterns
- **Command variety**: Tests all major systems
- **Configurable timing**: Adjustable message frequency
