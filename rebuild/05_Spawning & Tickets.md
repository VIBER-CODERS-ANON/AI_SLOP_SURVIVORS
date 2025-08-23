## 05 – Spawning & Tickets

Purpose:

- Maintain target difficulty by spawning enemies based on a weighted ticket system.

Considered complete when:

- New chatters start spawning automatically over time.
- Adjusting weights changes mix of spawns.
- Disabling the system stops spawns.

Suggested LLM prompt (copy/paste):

```text
Implement the Spawning & Tickets system.

Build outcomes:
- TicketSpawnManager that manages a chatter pool and per-type ticket weights.
- Background loop that keeps monster power near a target by spawning minions.

Interfaces & data:
- Commands: !join adds user to the pool.
- Weights example: Rat 100, Succubus 33, Woodland Joe 20.
- APIs: add_chatter(username), set_ticket(username, type, weight), pick_next_spawn(), spawn_tick(delta).

Considered complete when:

- New chatters start spawning automatically over time.
- Adjusting weights changes mix of spawns.
- Disabling the system stops spawns.
```

Validation steps:

1) Join with multiple mock users; observe spawn variety over 2 minutes.
2) Increase a user’s ticket multiplier; see them spawn more often.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- You can see the weighted selection working visually. If spawns feel off in the game, this scene tells you if the picker or something else is to blame.

Send this to your LLM:

```text
Build Spawning_Isolated.tscn. Add:
- A TicketSpawnManager that chooses spawn types using weights and a fixed seed.
- UI: Add Chatter (username), Start/Stop loop, sliders for Rat/Succubus/WoodlandJoe weights.
- A log and a simple frequency table of chosen types.
No real enemies; just record selections.
```

How to run/switch in Godot 4.4:

- Open `Spawning_Isolated.tscn`, press F6.
- Open your main scene, press F5 to go back.



Links: [[02_Enemy System]], [[06_MXP & Upgrades]]


