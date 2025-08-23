## 14 – Testing Strategy

Approach:

- Validate each system in isolation, then in sequence, with explicit gates.

Gates:

1) Core Loop Gate: Player moves, pause menu works.
2) Enemy System Gate: 500+ minions at 60 FPS; follow player.
3) Twitch Gate: Chat lines appear; Mock Chat works.
4) Command Gate: Commands parse and route; cooldown messages.
5) Spawning Gate: Users join and spawn over time with weights.
6) MXP Gate: Upgrades spend and apply; visible in HUD.
7) Evolution Gate: Entities transform; effects play; MXP deducted.
8) Boss Gate: Voting works; boss spawns; health bar binds.
9) Ability Gate: Abilities execute with cooldowns; scale by stats.
10) UI Gate: Action feed updates; boss bars; HUD live.

Repeatable tests:

- Stress tests: 1000+ minions, multi-boss fights.
- Rapid command spam via Mock Chat.
- Restart session and verify state resets as expected.

Example prompts:

- “List a 5-minute smoke test script for a QA pass across all systems.”
- “Generate a table of test commands to run for each system and the expected outcome messages.”


