# Active Chat Commands (as of 2025-08-19)

## MXP Modifier Commands (All Working!)
All these commands support variants: `!command`, `!command[number]`, `!commandmax`
- **!aoe** - +5% area of effect per MXP (1 MXP cost)
- **!hp** - +1 HP per MXP (1 MXP cost)  
- **!speed** - +5 movement speed per MXP (1 MXP cost)
- **!attackspeed** - +0.1 attacks/sec per MXP (1 MXP cost)
- **!regen** - HP regeneration (check file for details)
- **!ticket** - More spawn tickets 
- **!gamble** - Gamble MXP for rewards

Examples:
- `!aoe` - Spend 1 MXP for +5% AOE
- `!aoe10` - Spend 10 MXP for +50% AOE
- `!aoemax` - Spend all available MXP on AOE

## Monster Commands
- **!join** - Join the monster spawning pool
- **!evolve [type]** - Evolve to a different monster type
  - `!evolve succubus` - Become a succubus
  - `!evolve woodlandjoe` or `!evolve woodland_joe` - Become Woodland Joe
- **!explode** - Make your monsters explode (with AOE scaling!)
- **!fart** - Create poison clouds
- **!boost** - Double monster speed for 5 seconds

## Boss Voting
- **!vote [boss]** - Vote for next boss spawn
  - Available bosses are shown in chat when voting opens

## Notes
- All MXP commands now show activity feed updates when successful
- No spam when you have 0 MXP (no message shown)
- AOE scaling now properly applies to explosion abilities
- All modifiers use flat bonuses (no percentages)
- Rarity multiplier still applies to all stats