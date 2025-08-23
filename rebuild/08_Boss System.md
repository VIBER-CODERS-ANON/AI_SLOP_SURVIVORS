## 08 – Boss System

Purpose:

- Spawn complex, unique bosses through periodic voting and scripts.

Considered complete when:

- A winner spawns; game pauses during voting; UI shows options and countdown.
- Boss health bars show and update; clean up on death.

Suggested LLM prompt (copy/paste):

```text
Implement the Boss system.

Build outcomes:
- BossVoteManager that opens 20s vote windows and chooses a winner.
- BossSpawner that spawns a boss by id with stats, visuals, and abilities; hooks up a health bar and cleanup.

Interfaces & data:
- Commands: !vote1, !vote2, !vote3.
- Boss IDs: thor, mika, forsen, zzran.
- APIs: start_vote(), tally(), spawn_winning_boss().

Considered complete when:

- A winner spawns; game pauses during voting; UI shows options and countdown.
- Boss health bars show and update; clean up on death.
```

Validation steps:

1) Trigger a vote; use mock chat to vote; verify the winner spawns at vote end.
2) Observe boss health bar updates when dealing damage.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- You can check the entire vote → spawn → health bar loop without any minions or abilities involved.

Send this to your LLM:

```text
Create Boss_Isolated.tscn. Add:
- BossVoteManager (20s vote, 3 options).
- BossSpawner that spawns a placeholder boss when voting ends.
- UI: Start Vote, Vote1/2/3, countdown label, and a BossHealthBar.
- Buttons: Damage 10 / Heal 10 to test the bar and death cleanup.
```

How to run/switch in Godot 4.4:

- Open `Boss_Isolated.tscn`, press F6.
- Open main scene, press F5 to return.



Links: [[10_UI System]], [[11_Performance & Rendering]]


