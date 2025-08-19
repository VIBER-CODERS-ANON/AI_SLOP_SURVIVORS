# Twitch Integration System

## Overview

The Twitch Integration System provides a clean, modular way to connect your game to Twitch chat. It follows OOP principles and integrates seamlessly with the game's architecture.

## Architecture

### Components

1. **TwitchManager** (`twitch_manager.gd`)
   - Core system that handles all Twitch functionality
   - Manages connections, chat parsing, and command processing
   - Implements rate limiting and cooldowns
   - Provides mock chat for testing

2. **TwitchBot** (`twitch_bot.gd`)
   - Simple adapter for backwards compatibility
   - Delegates all functionality to TwitchManager
   - Provides the interface expected by GameController

## Features

- **Modular Design**: Drop-in replacement for old Twitch integration
- **Rate Limiting**: Prevents spam with per-user cooldowns
- **Command System**: Extensible command processing with prefix support
- **Mock Chat**: Built-in testing mode for development
- **Channel Switching**: Dynamic channel changes without restart

## Usage

### Basic Setup

The system is automatically initialized when the game starts. The TwitchBot node in `game.tscn` creates and manages the TwitchManager.

### Configuration

Edit the TwitchManager export variables:
- `auto_connect`: Connect on startup
- `default_channel`: Initial channel to join
- `command_prefix`: Chat command prefix (default: "!")
- `cooldown_per_user`: Seconds between commands per user
- `max_spawn_rate`: Maximum spawns per second

### Adding New Commands

Add new commands in `_handle_command()`:

```gdscript
match cmd:
    "spawn", "rat":
        _handle_spawn_command(username, color)
    "evolve":
        _handle_evolve_command(username, color, args)
    "your_command":
        _handle_your_command(username, color, args)
```

### Testing with Mock Chat

Enable mock chat in development by adding this to `game_controller.gd` in `_ready()`:

```gdscript
var bot = get_node_or_null("TwitchBot")
if bot:
    bot.enable_mock_chat(true)
```

This will simulate random Twitch messages for testing purposes.

## Integration Points

### GameController
- Receives chat messages via `_handle_chat_message()`
- Can spawn creatures via `spawn_twitch_creature()`
- Updates action feed with connection status

### Implementation Details
- Uses anonymous IRC connection via WebSocket
- No API keys or OAuth required for reading chat
- Connects as "justinfan12345" (Twitch's anonymous user)
- Parses IRC messages for username, text, and color tags
- Maintains connection with PING/PONG responses

### Future Extensions
- OAuth authentication for sending messages
- Subscriber/mod detection
- Channel point redemptions
- Emote parsing

## Best Practices

1. **Always check connection status** before processing commands (use `is_twitch_connected()`)
2. **Respect rate limits** to prevent spam
3. **Validate user input** in command handlers
4. **Use the action feed** for user feedback
5. **Test with mock chat** before going live
