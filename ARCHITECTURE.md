## Game Architecture Overview (Clean Structure)

This guide explains the current hybrid architecture after the cleanup and naming harmonization. It covers the data‑oriented enemy system we added (formerly referred to as “v2”), how it integrates with existing node‑based systems, and how minions vs bosses are handled.

### High‑Level

- **Minions (rats, evolved forms, etc.)**: Use a data‑oriented design. Enemies are rows in packed arrays (positions, velocities, health, etc.) managed by a single manager. Rendering uses MultiMesh for thousands of instances with a few draw calls.
- **Bosses**: Remain fully node‑based to preserve their bespoke behaviors, scenes, and effects.
- **Naming**: We removed “v2” from class and file names. The data‑oriented path is now the default. Any references to “v1/v2” should be read as “node‑based” vs “data‑oriented”.

### Core Systems

- **Enemy Manager (data‑oriented)**

  - Stores enemy state in arrays: positions, velocities, healths, move speeds, rotations, scales, types, colors, rarity, etc.
  - Integrates movement in small slices each frame, while positions and timers integrate every frame for smooth motion at high counts.
  - Supports obstacle avoidance (arena bounds, pits, pillars) and optional flocking forces.
  - Renders minions via MultiMesh, optionally split by minion type to support distinct visuals (e.g., Rat, Succubus, Woodland Joe).
  - Maintains a spatial grid for cheap neighborhood queries and a flow‑field (single BFS from the player) for global movement.

- **Ticket Spawner (data‑oriented)**

  - Ticket pool + ramping model; draws usernames to spawn minions using the data manager.
  - Spawns off‑screen using a donut around the camera, checking map safety before placement.
  - Tracks which entities belong to each chatter for upgrades, evolutions, and commands.

- **Bridge/Interop**

  - Connects the data arrays to existing gameplay systems (abilities, effects, lighting, UI, action feed) without needing a per‑enemy node.
  - Rebuilds abilities/effects/lighting when an enemy’s type changes (e.g., on evolution).

- **Live Physics Subset (pooled bodies)**

  - A small pool of `CharacterBody2D` nodes is recycled for the nearest N enemies to the player.
  - These bodies expose `take_damage(amount, attacker, tags)` and `apply_knockback(direction, force)` so existing weapons and physics interactions work as expected.
  - Bodies are fully disabled on release (hidden, physics off, collision layers/masks zeroed) to avoid lingering collisions.

- **Projectiles from Data Enemies**

  - Projectiles can be attributed to a logical owner via a small proxy node (stores enemy_id/username), enabling killfeed and death messaging without a full enemy node.

- **Nameplates**
  - Shows only the nearest N (default 20) minion nameplates.
  - Uses object pooling, absolute z‑order, pixel snapping, and stable sort for smooth visuals.

### Movement & Behavior

- **Flow‑Field Navigation**: A lightweight BFS from the player provides a direction field; enemies move toward the player without per‑entity pathfinding.
- **Obstacle Avoidance**: Configurable margins for arena edges, pits, and pillars; enemies steer away from blocked cells and edges.
- **Flocking (optional)**: Low‑weight separation/alignment/cohesion computed over array data using the spatial grid.
- **Variability**: Per‑enemy wander phase, strafe bias, speed jitter, and periodic bursts reduce “jagged/stiff” herd motion at scale.

### Evolutions & Rarity

- **Evolutions (data‑oriented)**

  - Changing a minion’s type updates its arrays, reapplies stats and abilities through the bridge, and switches visuals via the appropriate MultiMesh.
  - Works for chatter‑triggered upgrades (e.g., evolving a rat to succubus).

- **NPC Rarity**
  - Rarity modifies stats (health/damage), visual scale, and tints for minions. Applied on spawn.

### Damage Numbers & UI

- **Damage Numbers**: Spawned when data‑oriented enemies take damage via the live physics body API or projectile hit, matching the node presentation (crit styling supported).
- **Nameplates**: See “Nameplates” above; nearest N only.
- **Counters/Debug**: Simple hooks expose active enemy count, grid and flow‑field sizes for UI/telemetry.

### Bosses (Node‑Based)

- Bosses keep their scenes, signals, and bespoke logic. They are spawned the traditional way and remain independent from the data arrays.
- This separation keeps boss fights expressive while minions scale to thousands smoothly.

### Performance Practices

- MultiMesh rendering with viewport culling.
- Slice updates for heavy logic; always integrate position and behavior timers every frame to stay smooth.
- Spatial grid for neighbor queries; avoid O(N²) checks.
- Live physics subset only for the nearest N enemies.
- Object pooling for UI (nameplates) and physics bodies.

### Adding Content

- **Add a new data‑oriented minion**

  1. Define its base stats/abilities in the enemy configuration database.
  2. Add a type id/name and (optionally) a dedicated MultiMesh texture.
  3. Ensure the bridge knows how to set up its abilities/effects/lighting.
  4. Optionally expose a chat command or evolution path to this type.

- **Add/modify a boss (node)**
  1. Create/update the scene and its script as usual.
  2. Wire abilities/effects/voicelines in node space.
  3. Spawn bosses via the established node‑based boss flow.

### Migration Notes (Terminology Cleanup)

- We removed “v2” from class/file names. The “data‑oriented” approach is now the default for minions.
- The old advanced boss spawner and boss `.tres` configs were removed; bosses use the classic node path.
- The legacy ticket spawner was removed; the data‑oriented ticket spawner is canonical.

### Tuning Cheats & Debugging

- Cheats can spawn minions near the player to test scale/perf.
- Use ramping to push monster power over time.
- Flocking weights and avoidance margins can be increased slightly if minions clip pits/pillars.

### Glossary

- **Data‑Oriented Minion**: An enemy represented as a row in arrays (no per‑enemy node), rendered via MultiMesh, updated in slices.
- **Bridge/Interop**: Code that binds the data arrays to existing node‑based systems (abilities, effects, lights, UI).
- **Live Physics Subset**: Recycled `CharacterBody2D` nodes assigned to the nearest N minions for collisions and weapon hits.
- **Flow‑Field**: A grid of directions (from a single BFS) that guides minions toward the player efficiently.
