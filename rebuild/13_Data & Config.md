## 13 – Data & Config

Purpose:

- Centralize tunable values and content in resources.

Considered complete when:

- Editing a minion’s config changes behavior on the next spawn.
- Boss configs load/save as .tres with fields persisted (e.g., health, speed, rarity, weight).
- Settings (channel, command prefix, cooldowns, difficulty targets) take effect at runtime or after restart.

Suggested LLM prompt (copy/paste):

```text
Implement the Data & Config system.

Build outcomes:
- EnemyConfigManager for minion types and base stats.
- BossConfig resources for boss definitions and spawn weighting.
- SettingsManager for Twitch channel, cooldowns, and difficulty targets.

Interfaces & data:
- Resource files (.tres) for BossConfig and EnemyConfig (fields e.g., base_health, base_damage, move_speed, rarity, spawn_weight).
- Settings fields: default_channel, command_prefix, cooldown_per_user, difficulty_target.

Considered complete when:

- Editing a minion’s config changes behavior on the next spawn.
- Boss configs load/save as .tres with fields persisted (e.g., health, speed, rarity, weight).
- Settings (channel, command prefix, cooldowns, difficulty targets) take effect at runtime or after restart.
```

Validation steps:

1) Change a minion’s base speed; see behavior change after respawn.
2) Adjust boss rarity/weight; observe different vote options over time.
3) Change Twitch settings (channel/prefix/cooldowns) and confirm expected behavior.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- Confirms you can safely edit/save data without corrupting the game. If a boss or minion feels wrong later, you can check their config here.

Send this to your LLM:

```text
Build Config_Isolated.tscn (Control root). Include:
- Dropdown to pick Boss or Minion.
- Fields for key props (health, speed, rarity, weight).
- Buttons: Load, Save As…, Reset Defaults.
Use Godot Resource (.tres) load/save.
```

How to run/switch in Godot 4.4:

- Open `Config_Isolated.tscn`, press F6.
- Open main scene, press F5 to return.

Links: [[08_Boss System]]


