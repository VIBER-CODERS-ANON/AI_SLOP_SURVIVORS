## 07 – Evolution System

Purpose:

- Transform a chatter’s existing minions into stronger forms, preserving relative health.

Considered complete when:

- Entities transform while keeping health percentage.
- New abilities and visuals appear immediately.

Suggested LLM prompt (copy/paste):

```text
Implement the Evolution system.

Build outcomes:
- EvolutionSystem that finds a user’s entities and transforms them to a new type, preserving health ratio, swapping visuals/abilities, and playing effects.

Interfaces & data:
- Commands: !evolve succubus (10 MXP), !evolve woodlandjoe (5 MXP).
- APIs: evolve(username, new_type), can_evolve(username, cost).

Considered complete when:

- Entities transform while keeping health percentage.
- New abilities and visuals appear immediately.
```

Validation steps:

1) Spawn 10 rats; run `!evolve succubus`; verify flying and heart projectiles.
2) Validate MXP deduction and UI feedback.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- Guarantees evolution does what it says (change type, keep health %) without fighting with other systems.

Send this to your LLM:

```text
Make Evolution_Isolated.tscn. Include:
- EvolutionSystem + a simple EnemyStub (type, max_hp, current_hp).
- Buttons: Spawn 10 Rats, Evolve → Succubus, Evolve → WoodlandJoe.
- A log that prints type and health % before/after evolution.
Keep health ratio on evolve and show a quick visual cue.
```

How to run/switch in Godot 4.4:

- Open `Evolution_Isolated.tscn`, press F6.
- Open main scene, press F5 to return.



Links: [[06_MXP & Upgrades]], [[09_Ability System]]


