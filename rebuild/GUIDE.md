## Rebuild the Game One System at a Time

This rebuild works best when you focus on exactly one system at a time, in small, safe steps. Each system page gives you:
- Plain-language goal (what it does)
- Considered complete when (what success looks like)
- A single “Suggested LLM prompt” you can copy/paste
- Validation steps (how to confirm it works)
- An isolated scene prompt (optional, highly recommended) for quick checks

### How to proceed for each system

1) Open the system page (see “Recommended order” below).
2) Read “Plain-language goal” and “Considered complete when.”
3) Copy the “Suggested LLM prompt” and paste it into your AI tool. Use the generated changes.
4) Run the game and complete the system’s Validation steps.
5) Optional but recommended: run the isolated scene to quickly check the system in isolation.
6) Commit your changes. Move to the next system.

### Recommended order (links)

- [01_Core Loop](01_Core%20Loop.md)
- [02_Enemy System](02_Enemy%20System.md)
- [03_Twitch Integration](03_Twitch%20Integration.md)
- [04_Command System](04_Command%20System.md)
- [05_Spawning & Tickets](05_Spawning%20%26%20Tickets.md)
- [06_MXP & Upgrades](06_MXP%20%26%20Upgrades.md)
- [07_Evolution System](07_Evolution%20System.md)
- [08_Boss System](08_Boss%20System.md)
- [09_Ability System](09_Ability%20System.md)
- [10_UI System](10_UI%20System.md)
- [11_Performance & Rendering](11_Performance%20%26%20Rendering.md)
- [12_Debug & Cheats](12_Debug%20%26%20Cheats.md)
- [13_Data & Config](13_Data%20%26%20Config.md)
- Finally: [14_Testing Strategy](14_Testing%20Strategy.md)

Notes:
- Keep each change small. Validate before moving on.
- If something breaks later, use each system’s isolated scene to quickly find where it broke.
- Try not to add scope in the middle, tack it on at the end.


