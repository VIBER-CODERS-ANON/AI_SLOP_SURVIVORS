## Architecture Overview (Non-Technical)

What you are rebuilding:

- A top-down action game where Twitch chat drives enemy spawns, upgrades, and bosses.
- Two kinds of enemies:
  - Minions: Many at once, optimized for performance.
  - Bosses: Few, complex, with custom behaviors.
- A modular ability system so any entity can gain abilities.

Core building blocks:

- Game Orchestrator: Starts and connects all systems.
- Twitch Integration: Reads chat and forwards commands.
- Command System: Understands messages (e.g., !join, !hp 2, !vote1).
- Spawning & Tickets: Picks which enemies spawn and when.
- Enemy System: Efficiently updates hundreds of minions at once.
- MXP & Upgrades: Chat currency for upgrades and evolutions.
- Evolution System: Transforms minions into stronger forms.
- Boss System: Voting, spawning, and health bars.
- Ability System: Pluggable skills (explode, fart, boost, projectiles).
- UI System: Action feed, HUD elements, pause menu.
- Debug & Cheats: Hotkeys for testing.

Design principles:

- Separation of concerns (each system has one job).
- Event signals between systems (loosely coupled).
- Performance-first for minions (arrays, batch processing, GPU instancing).
- Human validation after each step to ensure working builds.

Next: [[GUIDE]] to rebuild step-by-step.


