## 11 – Performance & Rendering

Purpose:

- Keep the game smooth with hundreds of minions on screen.

Considered complete when:

- 1000+ minions maintain near 60 FPS on a mid‑range PC.
- Memory and instance counts remain stable during stress.
- Minions render via MultiMesh (no per‑minion nodes); object pools are active for effects/physics bodies.

Suggested LLM prompt (copy/paste):

```text
Harden performance & rendering.

Build outcomes:
- MultiMesh rendering for minions, frustum culling, and batched updates.
- Object pooling for effects and a small pool of live physics bodies.
- Spatial grid for neighbor queries and pathfinding.

Interfaces & data:
- Use existing minion arrays/transforms from the Enemy System.
- Avoid per‑minion nodes; bosses remain node‑based.

Considered complete when:

- 1000+ minions maintain near 60 FPS on a mid‑range PC.
- Memory and instance counts remain stable during stress.
- Minions render via MultiMesh (no per‑minion nodes); object pools are active for effects/physics bodies.
```

Validation steps:

1) Spawn 1000 rats; maintain near 60 FPS on a scamforge PC.
2) Profile memory and instance counts; verify stable behavior.

---

Isolated scene prompt (optional, highly recommended):

Why this is valuable:

- Lets you measure “how many minions can we handle” with one slider, no other noise.

Send this to your LLM:

```text
Build Perf_Isolated.tscn. Add:
- Arrays-only minion data + MultiMeshInstance2D renderer.
- Slider: minion count (100→2000). Toggle: flow-field on/off.
- On-screen readout: FPS, frame time, memory.
```

How to run/switch in Godot 4.4:

- Open `Perf_Isolated.tscn`, press F6.
- Open main scene, press F5 to return.



Links: [[02_Enemy System]]


