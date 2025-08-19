# Testing Cheats

For development and testing purposes, the following cheat codes are available:

## God Mode
**Key Combination:** `CTRL + 1`
- Toggles invulnerability on/off
- Player takes no damage from any source
- Player sprite gets a golden glow when active
- "IMMUNE" text appears when damage is blocked

## Spawn XP Orbs
**Key Combination:** `CTRL + 2`
- Spawns 10 XP orbs in a circle around the player
- Each orb grants 10 XP (100 XP total per press!)
- Spammable - can be used repeatedly
- Useful for testing level-up mechanics quickly

## Visual Indicators
- **God Mode ON:** Player has golden glow, "GOD MODE: ON" appears in action feed
- **God Mode OFF:** Player returns to normal appearance, "GOD MODE: OFF" appears in action feed
- **XP Spawn:** "✨ Spawned 100 XP! (10 orbs × 10 XP)" appears in action feed

## Twitch Testing

### Real Connection (Default)
The game automatically connects to Twitch chat using anonymous IRC:
- No API keys needed!
- Connects to the channel set in Settings → Twitch Integration
- Default channel: "quin69"
- Change channel anytime from the pause menu

### Mock Chat Mode (For Testing)
To test without a real Twitch connection:

1. **Enable Mock Chat in Code:**
   Add this to `game_controller.gd` in `_ready()`:
   ```gdscript
   var bot = get_node_or_null("TwitchBot")
   if bot:
       bot.enable_mock_chat(true)
   ```

2. **Mock Chat Behavior:**
   - Sends random messages every 3 seconds
   - Includes various commands and chat messages
   - Uses random usernames and colors

### Mock Chat Mode
When enabled, simulates random Twitch messages including:
- Regular chat messages
- Evolution commands (!evolve)
- Boss voting (!vote)
- Rat abilities (!explode, !fart, !boost)
- MXP commands (!mxp health 2)

## Implementation Details
- Cheats are enabled by default (can be restricted to debug builds later)
- Input is handled in `game_controller.gd`
- God mode is implemented by overriding `take_damage()` in `player.gd`
- Both cheats use key-press flags to prevent multiple triggers per frame
- Twitch mock chat can be enabled for testing without real Twitch connection
