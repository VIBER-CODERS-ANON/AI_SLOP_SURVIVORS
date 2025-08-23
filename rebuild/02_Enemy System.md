## 02 – Enemy System (Minions)

Purpose:

- Efficiently handle hundreds/thousands of small enemies with simple logic.

Considered complete when:

- 500+ minions render at 60 FPS on a mid-range PC.
- They path toward the player and stop at walls.
- Clearing enemies frees memory and removes visuals.

Suggested LLM prompt (copy/paste):

```text
Implement the Enemy System (minions).

Build outcomes:
- EnemyManager storing minion data in arrays (positions, health, speed, etc.).
- MultiMesh renderer drawing minions from arrays.
- Spatial grid + flow-field to move minions toward the player.

Interfaces & data:
- Arrays: PackedVector2Array, PackedFloat32Array per attribute.
- Methods: spawn_enemy(type, pos, username), update(delta), clear_all().
- Renderer receives transforms each frame.

Considered complete when:

- 500+ minions render at 60 FPS on a mid-range PC.
- They path toward the player and stop at walls.
- Clearing enemies frees memory and removes visuals.
```

Validation steps:

1) Spawn 300+ test rats in a loop; confirm stable framerate.
2) Move the player; minions follow reasonably.
3) Clear all; verify visual list empties.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- You can quickly see if “tons of minions” still render and move smoothly. If performance tanks later, this single scene tells you whether the problem is here or elsewhere.

Send this to your LLM:

```text
Create EnemySystem_Isolated.tscn (Node2D root). Add:
- A simple EnemyManager that holds minions in arrays and updates movement.
- A MultiMeshInstance2D that draws all minions from those arrays.
- A small player controlled with WASD.
On start, spawn ~300 minions at predictable positions (grid/ring) with a fixed seed. Bind key C to clear all.
```

How to run/switch in Godot 4.4:

- Open `EnemySystem_Isolated.tscn` and press F6 to run just this scene.
- Watch FPS in the top bar; you can also open Debug → Profiler while it runs.
- To go back, open your main scene and press F5 (or set it in Project Settings → Application → Run → Main Scene).



Links: [[11_Performance & Rendering]]


