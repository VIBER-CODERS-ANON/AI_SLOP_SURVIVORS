## AI Slop Survivors Rebuild

Preface: I deleted all source code so you wouldn't have to spend time figuring that out. I did my best to not touch any of your project settings nor assets. I never saw how you had godot configured so couldn't verify parity on my end. Worse case you reset your godot settings again which I know is a pain.

If you're reading this from Github and don't know how to access this locally do this:
  - commit/discard any changes in your current branch
  - `git fetch`
  - `git checkout talitore/guided-refactor`
  - literally nothing else if they succeeded

This vault is a non-technical, system-by-system blueprint to recreate the game from scratch. Open the `rebuild/` folder in Obsidian and then:

- **Start here**: [[Systems Index]] and [[GUIDE]]
- **Goal**: You can rebuild the game one system at a time using these notes.

## Conventions

- **System page layout**: Purpose → Done-when checklist → Validation steps → Isolated testing options.
- **Validation Gate**: A manual check to confirm a step is working before moving on.
- **Links**: Obsidian-style links like [[03_Twitch Integration]].
- **Scope**: These docs capture behavior, not implementation details. You will "code" each step with the prompts provided and verify functionality.

## High-level Summary

- Hybrid enemy architecture: data-oriented minions (arrays + MultiMesh) and node-based bosses.
- Twitch-native game loop: chat commands drive entity spawns, upgrades, evolutions, and boss votes.
- Modular ability framework: abilities are pluggable resources; any entity can use any ability.
- Performance-first: batched updates, object pooling, spatial grid, and GPU instancing.

See [[Architecture Overview]] for an accessible overview.


