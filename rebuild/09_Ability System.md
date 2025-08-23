## 09 – Ability System

Purpose:

- Let any entity use any ability via a modular plug-and-play framework.

Considered complete when:

- Add/remove abilities at runtime; cooldowns respected; abilities scale from holder stats.

Suggested LLM prompt (copy/paste):

```text
Implement the Ability system.

Build outcomes:
- AbilityManager + AbilityHolder that store abilities and execute them by id.
- BaseAbility resource extended by concrete abilities (explode, fart, boost, heart projectile).

Interfaces & data:
- Execute: execute_ability(id, target_data).

Considered complete when:

- Add/remove abilities at runtime; cooldowns respected; abilities scale from holder stats.
```

Validation steps:

1) Give player and a minion the same ability; confirm both execute it.
2) Verify cooldown and resource cost behavior.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- You can prove abilities attach/execute/scale correctly with no other moving parts.

Send this to your LLM:

```text
Build Ability_Isolated.tscn. Add:
- AbilityHolder + AbilityManager.
- Buttons: Explode, Fart, Boost, Heart Projectile (call execute_ability by id).
- Cooldown visuals on the buttons.
- Sliders for stats (Spell Power, Area Size) that change outcomes.
- A log showing when abilities run and their computed values.
```

How to run/switch in Godot 4.4:

- Open `Ability_Isolated.tscn`, press F6.
- Open main scene, press F5 to return.



Links: [[02_Enemy System]], [[07_Evolution System]]


