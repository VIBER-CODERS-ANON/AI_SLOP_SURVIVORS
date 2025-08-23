## 06 – MXP & Upgrades

Purpose:

- A simple shared currency chatters spend on upgrades and evolution.

Considered complete when:

- Spending reduces balance and applies stat changes.
- Modifiers persist through death/evolution within a session.

Suggested LLM prompt (copy/paste):

```text
Implement the MXP & Upgrades system.

Build outcomes:
- MXPManager that tracks balance and applies modifiers on spawn and live.
- Modifier types: HP, Speed, Attack Speed, AoE, Regeneration, Tickets.

Interfaces & data:
- Commands: !hp <n>, !speed <n>, !attackspeed <n>, !aoe <n>, !regen <n>, !ticket <n>.
- APIs: spend(username, amount), apply_modifiers(username, entity_id).

Considered complete when:

- Spending reduces balance and applies stat changes.
- Modifiers persist through death/evolution within a session.
```

Validation steps:

1) Spend MXP on `!hp 3`; verify minions have higher health on next spawn.
2) Use `!speed 2`; observe faster movement.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- You can verify “numbers go up” before touching any AI or combat. If stats feel wrong later, check this scene first.

Send this to your LLM:

```text
Create MXP_Isolated.tscn. Include:
- MXPManager and a SpawnStub showing a dummy entity’s stats.
- Buttons: +HP, +Speed, +AttackSpeed, +AoE, +Regen, +Ticket.
- A “Spawn Test Minion” that creates a dummy and applies modifiers.
- A small table printing stats before/after spends.
Standalone; no Twitch or enemies.
```

How to run/switch in Godot 4.4:

- Open `MXP_Isolated.tscn`, press F6 to run.
- Open main scene, press F5 to return.



Links: [[07_Evolution System]], [[10_UI System]]


