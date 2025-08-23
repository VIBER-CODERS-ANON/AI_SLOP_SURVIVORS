## 01 – Core Loop

Plain-language goal:

- The player moves around an arena, enemies spawn over time, the player survives while chat interacts via commands.

Considered complete when:

- Start game: player spawns, camera follows, basic HUD visible.
- Pause menu toggles on Escape.
- No Twitch yet; no enemies yet.

Suggested LLM prompt (copy/paste):

```text
Implement the Core Loop.

Build outcomes:
- A Game Orchestrator that initializes systems in order and can broadcast/receive events.
- A running scene with a controllable player and empty world.

Interfaces & data:
- Events: chat_message_received, boss_spawned, evolution_completed.
- Initialization order: core singletons → game systems → twitch → world setup.

Considered complete when:

- Start game: player spawns, camera follows, basic HUD visible.
- Pause menu toggles on Escape.
- No Twitch yet; no enemies yet.
```

Validation steps:

1) Launch the game; verify player can move and HUD shows health/xp placeholders.
2) Press Escape; pause menu appears and resumes.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- This gives you a tiny “core game only” playground. If a future AI change breaks the game, you can open this one scene and instantly learn whether the core loop still works. You’ll know if you broke the basics (move, HUD, pause) without noise from other systems.

Send this to your LLM:

```text
Make a Godot 4 scene called CoreLoop_Isolated.tscn with a Node2D root. Include:
- A player that moves with WASD, plus a Camera2D set to current=true.
- A simple HUD (Control) showing HP and XP placeholders.
- A pause overlay that appears on Escape with Resume and Quit buttons.

This scene should run by itself, with no Twitch or enemies.
```

How to run this in Godot 4.4 (and switch back):

- In FileSystem, double‑click `CoreLoop_Isolated.tscn` to open it.
- Click the clapper “Run Current Scene” button (or press F6). The scene runs by itself.
- To stop, click the square Stop button.
- To return to your normal game, open your main game scene and press F5 (Run Project). If your main scene isn’t set, go to Project → Project Settings → Application → Run → Main Scene and pick your game’s main scene, then press F5.



Links:

- Next: [[02_Enemy System]]


