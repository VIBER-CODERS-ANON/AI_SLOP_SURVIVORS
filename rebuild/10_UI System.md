## 10 – UI System

Purpose:

- Provide clear, live feedback: action feed, HUD, boss bars, menus.

Considered complete when:

- Messages are color-coded; HUD updates in real-time; boss bars attach to bosses.

Suggested LLM prompt (copy/paste):

```text
Implement the UI system.

Build outcomes:
- ActionFeed for messages, HUD widgets (XP/MXP/stats), BossHealthBar, Twitch config dialog.

Interfaces & data:
- Inputs from systems: command success/failure, boss spawn, evolution complete, MXP changes.

Considered complete when:

- Messages are color-coded; HUD updates in real-time; boss bars attach to bosses.
```

Validation steps:

1) Trigger commands and observe action feed entries.
2) Spawn a boss; verify health bar binds and updates.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- You can lock in UI look/feel without chasing bugs in gameplay.

Send this to your LLM:

```text
Create UI_Isolated.tscn (Control root). Add:
- ActionFeed, XP bar, MXP display, Player stats, BossHealthBar (start hidden), and a Twitch config dialog button.
- Buttons that emit fake UI events: Success, Error, System, Show/Hide BossBar, Set Twitch Channel.
Run standalone; no backend required.
```

How to run/switch in Godot 4.4:

- Open `UI_Isolated.tscn`, press F6.
- Open main scene, press F5 to return to game.



Links: [[04_Command System]], [[08_Boss System]]


