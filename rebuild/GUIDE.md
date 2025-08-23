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

- [[01_Core Loop]]
- [[02_Enemy System]]
- [[03_Twitch Integration]]
- [[04_Command System]]
- [[05_Spawning & Tickets]]
- [[06_MXP & Upgrades]]
- [[07_Evolution System]]
- [[08_Boss System]]
- [[09_Ability System]]
- [[10_UI System]]
- [[11_Performance & Rendering]]
- [[12_Debug & Cheats]]
- [[13_Data & Config]]
- Finally: [[14_Testing Strategy]]

Notes:
- Keep each change small. Validate before moving on.
- If something breaks later, use each system’s isolated scene to quickly find where it broke.
- Try not to add scope in the middle, tack it on at the end.


