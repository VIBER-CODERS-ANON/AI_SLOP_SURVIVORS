## 03 – Twitch Integration

Purpose:

- Read Twitch chat in real time and forward messages into the game.

Considered complete when:

- Connects automatically to a configurable channel.
- Emits events for each chat line.
- Mock Chat works without internet.

Suggested LLM prompt (copy/paste):

```text
Implement the Twitch Integration system.

Build outcomes:
- TwitchManager that connects anonymously to Twitch IRC and emits (username, message, color).
- Mock Chat mode to simulate messages offline.

Interfaces & data:
- Settings: auto_connect, default_channel, command_prefix, cooldown_per_user.
- Events: chat_message_received(username, message, color).

Considered complete when:

- Connects automatically to a configurable channel.
- Emits events for each chat line.
- Mock Chat works without internet.
```

Validation steps:

1) Set channel in settings; see messages in a debug log.
2) Enable Mock Chat; fake messages appear every few seconds.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- You can check chat I/O separately from gameplay. If commands stop working, this scene helps you confirm whether chat is arriving at all.

Send this to your LLM:

```text
Make Twitch_Isolated.tscn. Add:
- A TwitchManager that connects to a channel or emits fake messages.
- A LineEdit + “Connect” button for real chat.
- A “Mock Chat” button that emits a message every 3–5s with a fixed seed.
- A RichTextLabel that displays (username, message, color).
Run standalone. No gameplay.
```

How to run/switch in Godot 4.4:

- Open `Twitch_Isolated.tscn`, press F6.
- To return to the game, open your main scene and press F5.



Links: [[04_Command System]], [[12_Debug & Cheats]]


