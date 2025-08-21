# A.S.S WebSocket Test Server

A Node.js test server for receiving and displaying WebSocket events from the A.S.S (AI Slop Survivors) game.

## Features

- **Real-time Event Logging**: Displays all game events with timestamps and formatted output
- **Statistics Tracking**: Tracks event counts, types, and session data
- **Health Monitoring**: HTTP endpoints for health checks and statistics
- **Multi-client Support**: Can handle multiple WebSocket connections
- **Graceful Shutdown**: Properly closes connections on server shutdown

## Quick Start

1. **Install dependencies:**
   ```bash
   cd websocket-test-server
   npm install
   ```

2. **Start the server:**
   ```bash
   npm start
   ```
   
   Or for development with auto-restart:
   ```bash
   npm run dev
   ```

3. **Configure the game:**
   - Launch A.S.S game
   - Press ESC to open pause menu
   - Go to "TWITCH EXTENSION (WebSocket)" section
   - Enable the extension
   - Set URL to: `ws://localhost:8080/ws`
   - Click Apply

## Server Endpoints

- **WebSocket**: `ws://localhost:8080/ws` - Main game event endpoint
- **Health Check**: `http://localhost:8080/health` - Server status and statistics
- **Statistics**: `http://localhost:8080/stats` - Detailed event statistics

## Supported Events

The server handles all game events sent by the WebSocketManager:

### Core Events
- `session_start` - Game session begins
- `session_end` - Game session ends

### Game State Events
- `game_paused` - Game is paused (any reason)
- `game_resumed` - Game is resumed
- `game_restart` - Player requests game restart

### Monster Events
- `monster_join` - Player joins monster pool
- `entity_spawned` - Monster entity spawned in game
- `monster_death` - Monster killed
- `monster_power_changed` - Monster power level changed

### MXP (Monster Experience Points)
- `mxp_granted` - MXP awarded to all players
- `mxp_spent` - Player spends MXP on upgrades

### Boss Events
- `vote_started` - Boss vote begins
- `vote_updated` - Vote tallies updated
- `vote_result` - Boss vote winner announced
- `boss_spawned` - Boss appears in game
- `boss_killed` - Boss defeated

### Player Events
- `player_level_up` - Player gains a level
- `player_experience_gained` - Player gains XP
- `player_health_changed` - Player health changes (rate limited)
- `player_death` - Player dies

### Special Events
- `evolution` - Monster evolves to new form
- `rarity_assigned` - Monster assigned rarity type

## Event Format

All events follow this structure:
```json
{
  "type": "event_name",
  "timestamp": 1642781234,
  "channel": "twitch_channel_name",
  "data": {
    // Event-specific data
  }
}
```

## Example Output

```
🚀 A.S.S WebSocket Test Server running on port 8080
📡 WebSocket endpoint: ws://localhost:8080/ws
🔍 Health check: http://localhost:8080/health
📊 Statistics: http://localhost:8080/stats

🔗 Client connected: client_1642781234567_abc123def (1 total)
🎮 [10:30:15] SESSION START - Channel: quin69
👹 [10:30:22] MONSTER JOIN - testuser as twitch_rat
🐣 [10:30:22] ENTITY SPAWNED - ID:0 testuser (twitch_rat)
💀 [10:30:45] MONSTER DEATH - testuser's twitch_rat killed by Player (sword)
🎉 [10:31:02] PLAYER LEVEL UP - Level 2
⏸️ [10:31:15] GAME PAUSED
▶️ [10:31:30] GAME RESUMED
🔄 [10:32:00] GAME RESTART REQUESTED
🛑 [10:32:01] SESSION END - Channel: quin69
```

## Development

The server uses:
- **ws**: WebSocket library
- **express**: HTTP server for health endpoints
- **nodemon**: Auto-restart during development

## Configuration

Default configuration:
- Port: 8080 (set `PORT` environment variable to change)
- WebSocket path: `/ws`
- Health check: `/health`
- Statistics: `/stats`

## Troubleshooting

1. **Connection Issues**: Ensure the game's WebSocket URL matches the server endpoint
2. **Port Conflicts**: Change the PORT environment variable if 8080 is in use
3. **No Events**: Check that the WebSocket extension is enabled in the game's pause menu
4. **Parsing Errors**: Check server logs for malformed JSON from the game client

## Integration with Twitch Extensions

This test server demonstrates the event format that a real Twitch extension backend would receive. The events can be used to:

- Update extension overlays in real-time
- Track player statistics
- Create interactive voting systems
- Display live game state to viewers
- Trigger channel point rewards or other Twitch integrations
