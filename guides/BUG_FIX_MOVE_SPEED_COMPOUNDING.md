# Bug Fix: Move Speed Compounding in Chatter Entity Upgrades

## Issue Description
After evolving a Twitch chatter to WoodlandJoe and applying any MXP buff, the entity's move speed would increase exponentially, making it move way too fast. This was due to the move speed multiplier being applied to the current speed each time upgrades were reapplied, causing compounding.

This issue was specific to WoodlandJoe in testing, but the root cause was in the shared upgrade system.

## Root Cause
The caching for the base_move_speed was missing in the apply_upgrades_to_entity function. Without caching the initial base value, each reapplication of upgrades used the current (already multiplied) move_speed as the base, leading to multiplicative compounding every time a buff was used (since buffs trigger a reapply).

For example:
- Initial move_speed = 50
- mult = 1.5
- First apply: set to 50 * 1.5 = 75
- Second buff reapply: set to 75 * 1.5 = 112.5
- Third: 112.5 * 1.5 = 168.75, and so on.

## Fix Applied
Added the missing caching line for base_move_speed, similar to other stats:

if not entity.has_meta("base_move_speed"):
    entity.set_meta("base_move_speed", entity.move_speed)

This caches the initial base value once, and subsequent reapplies use the cached base instead of the current value, preventing compounding.

## How to Avoid in Future
- Always use caching for base stats in upgrade systems to prevent unintentional compounding.
- Encapsulate stat modifications in a dedicated StatComponent using OOP principles:
  - Store base values immutably upon initialization.
  - Calculate effective stats on demand using multipliers.
  - Avoid directly modifying stats in reapply functions; always compute from base.
- Test upgrade applications multiple times, especially after evolutions or respawns, to catch compounding issues.
- For scalable systems, consider a StatManager class that handles all stat calculations uniformly.
