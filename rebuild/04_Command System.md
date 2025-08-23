## 04 – Command System

Purpose:

- Translate chat text into in-game actions with validation and cooldowns.

Considered complete when:

- Invalid syntax yields friendly feedback in the action feed.
- Per-user cooldowns prevent spam.
- Safe handling if a user hasn’t joined yet.

Suggested LLM prompt (copy/paste):

```text
Implement the Command System.

Build outcomes:
- CommandProcessor that listens to chat_message_received and routes to systems.
- Categories: free, MXP-spend, system (join/vote), evolution.

Interfaces & data:
- Input: !join, !explode, !fart, !boost, !hp <n>, !speed <n>, !attackspeed <n>, !aoe <n>, !regen <n>, !ticket <n>, !evolve <type>, !vote1/2/3.
- Output: calls into Spawning, MXP, Evolution, Boss Voting, and Ability systems.

Considered complete when:

- Invalid syntax yields friendly feedback in the action feed.
- Per-user cooldowns prevent spam.
- Safe handling if a user hasn’t joined yet.
```

Validation steps:

1) Send test commands from Mock Chat and real chat; observe correct routing.
2) Verify cooldown messaging when spamming.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- This proves your command parser routes messages correctly before touching real systems. If a command misbehaves later, you can check routing here first.

Send this to your LLM:

```text
Create CommandSystem_Isolated.tscn. Add:
- A CommandProcessor.
- Stub nodes for Spawning, MXP, Evolution, BossVote, Ability that log calls.
- A LineEdit + “Send” to inject chat text.
- A “Spam” button sending a mix of valid/invalid commands to observe cooldowns and errors.
Run standalone and show which stub gets called.
```

How to run/switch in Godot 4.4:

- Open `CommandSystem_Isolated.tscn`, press F6.
- Open main scene and press F5 to return to full game.



Links: [[05_Spawning & Tickets]], [[06_MXP & Upgrades]], [[07_Evolution System]], [[08_Boss System]], [[10_UI System]]


