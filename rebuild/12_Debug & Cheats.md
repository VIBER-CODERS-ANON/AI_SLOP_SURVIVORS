## 12 – Debug & Cheats

Purpose:

- Speed up manual testing with hotkeys and mock systems.

Considered complete when:

- Listed hotkeys trigger visible actions or logs in development builds.
- A single feature flag disables all cheats for production builds.
- Debug overlay toggles on/off and displays basic metrics.

Suggested LLM prompt (update `Keyboard map` as needed):

```text
Implement Debug & Cheats.

Build outcomes:
- Cheat hotkeys for spawning, MXP grants, boss voting, and clearing enemies.
- Toggleable debug overlay.

Keyboard map:

- Ctrl+1: God mode
- Ctrl+2: Spawn XP orbs
- Ctrl+3: Force level up
- Ctrl+4: Trigger boss vote
- Alt+1..0: Spawn/clear enemies and bosses
- F12: Toggle debug overlay

Considered complete when:

- Listed hotkeys trigger visible actions or logs in development builds.
- A single feature flag disables all cheats for production builds.
- Debug overlay toggles on/off and displays basic metrics.
```

Validation steps:

1) Use hotkeys to spawn enemies and MXP; verify visual and numeric changes.
2) Trigger boss vote via hotkey; confirm the UI opens.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- Confirms testing keys work and can be turned off for release with one switch.

Send this to your LLM:

```text
Create Cheats_Isolated.tscn. Add:
- A CheatManager binding the listed hotkeys to print to a log and emit signals.
- Optional dummy listeners (spawn dummy, add MXP, start vote, clear) to react.
- A “Prod Mode” checkbox that disables all hotkeys.
```

How to run/switch in Godot 4.4:

- Open `Cheats_Isolated.tscn`, press F6.
- Open main scene, press F5 to return.



Links: [[14_Testing Strategy]]


