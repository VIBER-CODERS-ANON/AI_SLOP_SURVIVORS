# A.S.S Game Development Guides

Welcome to the comprehensive guide collection for AI SLOP SURVIVORS. These guides are designed to help developers and LLMs create high-quality, modular, and future-proof game systems.

## Available Guides

### 📚 Core Guides

#### Performance & Optimization
1. **[Flocking Optimization Guide](./FLOCKING_OPTIMIZATION_GUIDE.md)** 🆕
   - Authoritative flocking architecture
   - Single velocity owner principle
   - Grid-based neighbor queries
   - Common mistakes to avoid

2. **[Performance Optimization Guide](./PERFORMANCE_OPTIMIZATION_GUIDE.md)** 🆕
   - Cadence patterns for expensive operations
   - Spatial partitioning strategies
   - Frame budget management
   - Profiling and metrics

3. **[Movement Controller Guide](./MOVEMENT_CONTROLLER_GUIDE.md)** 🆕
   - Controller architecture rules
   - NO separation logic in controllers
   - Raycast and pathfinding cadence
   - Integration with flocking system

#### Ability System
1. **[Ability Implementation Guide](./ABILITY_IMPLEMENTATION_GUIDE.md)**
   - Complete guide for creating abilities
   - Architecture overview
   - Integration patterns
   - Best practices
   - Troubleshooting

2. **[Ability Implementation Checklist](./ABILITY_IMPLEMENTATION_CHECKLIST.md)**
   - Step-by-step checklist for new abilities
   - Pre-development planning
   - Testing requirements
   - Quality assurance

3. **[Ability Quick Reference](./ABILITY_QUICK_REFERENCE.md)**
   - Common code patterns
   - Quick lookup tables
   - Performance tips
   - Debugging helpers

4. **[Channeled Abilities Guide](./CHANNELED_ABILITIES_GUIDE.md)**
   - Implementation patterns for channeled abilities
   - Movement stop mechanics
   - Current channeled abilities
   - Common issues and solutions

#### Boon System
1. **[Boon Implementation Guide](./BOON_IMPLEMENTATION_GUIDE.md)**
   - Complete guide for creating boons
   - Rarity system explanation
   - Scaling mechanics (MORE vs Increased)
   - Balance philosophy
   - Integration patterns

2. **[Boon Implementation Checklist](./BOON_IMPLEMENTATION_CHECKLIST.md)**
   - Step-by-step checklist for new boons
   - Rarity testing requirements
   - Balance verification
   - Integration checklist

3. **[Boon Quick Reference](./BOON_QUICK_REFERENCE.md)**
   - Essential code patterns
   - Rarity multipliers table
   - Common base values
   - Quick decision tree

#### NPC System
1. **[NPC Implementation Guide](./NPC_IMPLEMENTATION_GUIDE.md)**
   - Complete guide for creating NPCs
   - Class hierarchy explanation
   - Movement and AI patterns
   - Ability integration
   - Best practices

2. **[NPC Implementation Checklist](./NPC_IMPLEMENTATION_CHECKLIST.md)**
   - Step-by-step checklist for new NPCs
   - Scene structure requirements
   - Combat behavior verification
   - Common issues and fixes

3. **[NPC Quick Reference](./NPC_QUICK_REFERENCE.md)**
   - Copy-paste templates
   - Common patterns
   - Stats reference tables
   - Debug helpers

#### Twitch Integration
1. **[Twitch Spawning System](./TWITCH_SPAWNING_SYSTEM.md)**
   - Ticket-based spawning mechanism
   - Session management (!join command)
   - Monster power threshold system
   - Concurrent entity spawning
   - MXP ticket upgrades

### 🎨 Templates

#### Ability Templates

Located in `ability_templates/`:

1. **[Projectile Ability Template](./ability_templates/projectile_ability_template.gd)**
   - For fireball, arrow, missile-type abilities
   - Configurable projectile properties
   - Multi-shot support

2. **[AoE Ability Template](./ability_templates/aoe_ability_template.gd)**
   - For explosion, nova, earthquake-type abilities
   - Telegraph system
   - Damage falloff options

3. **[Buff/Debuff Ability Template](./ability_templates/buff_ability_template.gd)**
   - For stat modifications
   - Status effects
   - Duration-based effects

4. **[Movement Ability Template](./ability_templates/movement_ability_template.gd)**
   - For dash, teleport, leap abilities
   - Movement validation
   - Combat integration

#### Boon Templates

Located in `boon_templates/`:

1. **[Stat Boon Template](./boon_templates/stat_boon_template.gd)**
   - For health, damage, speed increases
   - Simple numerical boosts
   - Automatic rarity scaling

2. **[Percentage Boon Template](./boon_templates/percentage_boon_template.gd)**
   - For percentage modifiers
   - MORE vs Increased scaling
   - Compound effects

3. **[Weapon Modifier Boon Template](./boon_templates/weapon_modifier_boon_template.gd)**
   - For weapon-specific enhancements
   - Tag-based targeting
   - Arc angle, strikes, etc.

4. **[Unique Boon Template](./boon_templates/unique_boon_template.gd)**
   - For game-changing mechanics
   - Risk/reward systems
   - Custom effects

5. **[Stackable Unique Boon Template](./boon_templates/stackable_unique_boon_template.gd)**
   - For repeatable unique boons
   - Visual progression patterns
   - Stack-based mechanics

## 🚀 Quick Start

### Creating Your First Ability

1. **Choose a template** from `ability_templates/` that matches your ability type
2. **Copy the template** to `systems/ability_system/abilities/your_ability.gd`
3. **Follow the TODOs** in the template to customize
4. **Use the checklist** to ensure nothing is missed
5. **Refer to the main guide** for detailed explanations

### Example: Creating a Fireball

```gdscript
# 1. Copy projectile_ability_template.gd to fireball_ability.gd
# 2. Update the _init() method:

func _init() -> void:
    ability_id = "fireball"
    ability_name = "Fireball"
    ability_description = "Launches a fiery projectile that explodes on impact"
    ability_tags = ["Fire", "Projectile", "AoE"]
    base_cooldown = 2.0
    resource_costs = {"mana": 15.0}
```

### Creating Your First Boon

1. **Choose a template** from `boon_templates/` that matches your boon type
2. **Copy the template** to `systems/boon_system/boons/your_boon.gd`
3. **Set base values** (these are Common rarity values)
4. **Add to boon pool** in `boon_manager.gd`
5. **Test at all rarities** using the checklist

### Example: Creating a Strength Boon

```gdscript
# 1. Copy stat_boon_template.gd to strength_boon.gd
# 2. Update the configuration:

const BASE_VALUE = 2.0  # +2 damage at Common

func _init():
    id = "strength"
    display_name = "Strength"
    base_type = "damage"
    icon_color = Color(1, 0.5, 0)  # Orange

func get_formatted_description() -> String:
    var value = get_effective_power(BASE_VALUE)
    return "+%.0f Base Damage" % value
```

### Creating Your First NPC

1. **Choose base class**: `BaseCreature` for standard NPCs, `BaseEvolvedCreature` for evolved forms
2. **Copy a template** from the Quick Reference guide
3. **Create the script** in `entities/enemies/your_npc.gd`
4. **Create the scene** in `entities/enemies/your_npc.tscn`
5. **Use the checklist** to ensure proper setup

### Example: Creating a Goblin Archer

```gdscript
# 1. Create goblin_archer.gd extending BaseCreature
# 2. Set up the NPC:

func _setup_npc():
    creature_type = "GoblinArcher"
    base_scale = 0.9
    abilities = ["shoot_arrow"]
    
    max_health = 25
    current_health = max_health
    move_speed = 140
    damage = 8
    attack_range = 180
    attack_cooldown = 1.2
    attack_type = AttackType.RANGED
    preferred_attack_distance = 160
    
    if taggable:
        taggable.add_tag("Enemy")
        taggable.add_tag("Goblin")
        taggable.add_tag("Ranged")
```

## 📋 Guide Philosophy

All guides in this project follow these principles:

1. **OOP First**: Every system uses object-oriented programming
2. **Modularity**: Components are plug-and-play
3. **Future-Proof**: Designed for easy extension
4. **Tag-Based**: Leverages the universal tag system
5. **Well-Documented**: Clear comments and examples

## 🔥 Recent Updates

### Performance Refactor - Flocking & Controllers (NEW!)
- **Complete flocking optimization**: O(n²) → O(n·k) scaling
- **Authoritative separation**: FlockingSystem is the ONLY source of separation/alignment/cohesion
- **Controller refactor**: Removed all local separation logic from movement controllers
- **Cadence patterns**: Raycasts every N frames, pathfinding on timer
- **Grid-based neighbors**: Replaced global entity scans with spatial grid lookups
- **Single velocity owner**: BaseEntity is the only script that sets velocity
- **New guides created**:
  - Flocking Optimization Guide - Architecture rules and patterns
  - Performance Optimization Guide - Cadence, caching, profiling
  - Movement Controller Guide - Controller patterns and integration
- **Critical changes**:
  - ZombieMovementController no longer has `separation_force` property
  - AIMovementController uses FlockingSystem.get_neighbors()
  - All controllers must use cadence for expensive operations

### Ticket-Based Spawning System with Ramping (UPDATED!)
- **Complete overhaul** of Twitch entity spawning mechanics
- Chatters now type `!join` once per session to participate
- **Ticket pool system**: Each monster type has different ticket values (spawn weights)
  - Twitch Rat: 100 tickets (most common)
  - Succubus: 20 tickets (equal to Joe, was 33)
  - Woodland Joe: 20 tickets
- **Dynamic Monster Power Ramping**:
  - Starts at 0.0 base threshold
  - +0.002 every 1 second (0.12 per minute)
  - +1.0 for each boss defeated (boss bonus)
  - Simple addition: base + time + boss
- **Off-Screen Spawning**: Monsters spawn in 50-300px ring outside camera view
- **Clean UI Display**: 
  - Just the threshold number at top center (grey, 18px font)
  - Always shows 1 decimal place for readability
  - Positioned 60px from top
- **Concurrent spawning**: Same chatter can have multiple monsters alive
- **Commands affect all entities**: !fart, !explode, !boost trigger on ALL chatter's monsters
- **New MXP upgrade**: !ticket command increases spawn chance (3 MXP per use)
- **Session-based**: Resets on game restart, chatters must rejoin

### Boss Updates & AI Improvements
- **Forsen Boss**: Now plays "crashing this plane" dialog when channeling Summon Swarm
- **Ziz Boss Buff Nerf**: Death explosion chance reduced from 50% to 25%
- **Ugandan Warrior Improvements**:
  - Explosion logic moved to SuicideBombAbility (reusable)
  - AI proximity activation pattern documented
  - Size reduced by 30%, base damage reduced to 1

### NPC Implementation Guides Added
- Created comprehensive NPC Entity Implementation Guide
- Added NPC Quick Reference with copy-paste templates
- Created detailed NPC Implementation Checklist
- Documented class hierarchy (BaseCreature vs BaseEvolvedCreature)
- Included movement patterns, aggro systems, and ability integration
- Added common issues and debugging tips

### Death Attribution System Complete
- Fixed critical crash when Resource-based abilities tried to deal damage
- Added Twitch chat colors to death screen for killer names
- Fixed missing ability names in death messages
- Fixed priority bug where entity's default attack overrode ability names
- Updated all damage-dealing entities with proper attribution methods:
  - `explosion_effect.gd` - Now shows correct attacker and "explosion"
  - `base_enemy.gd` - Shows "bite" as default attack
  - `suction_ability.gd` - Uses metadata pattern to show "life drain"
- Comprehensive documentation added covering:
  - Resources cannot be damage sources (only Nodes)
  - `active_ability_name` metadata takes priority over default attacks
  - Proper attribution delegation patterns
  - Signal parameter changes
  - All four attribution patterns with examples

## 🔧 Contributing to Guides

When adding new guides:

1. Follow the established format
2. Include practical examples
3. Add templates when applicable
4. Update this README
5. Test all code examples

## 📖 Additional Resources

- [Game Architecture](../GAME_ARCHITECTURE.md) - Overall system design
- [Tag System](../systems/tag_system/README.md) - Universal tagging
- [Entity System](../systems/entity_system/README.md) - Base entity framework

## 💡 Tips for LLMs

When using these guides to implement features:

1. **Always check existing patterns** - Consistency is key
2. **Use the templates** - They handle edge cases
3. **Follow the checklist** - It prevents common mistakes
4. **Tag everything** - The tag system is central to interactions
5. **Test edge cases** - Entity death, resource depletion, etc.

## 🎮 Examples

### Implemented Abilities

Here are some abilities already implemented using this system:

- **Fart** (`fart_ability.gd`) - Environmental AoE with DoT
- **Explosion** (`explosion_ability.gd`) - Self-damage AoE
- **Dash** (`dash_ability.gd`) - Movement ability
- **Heart Projectile** (`heart_projectile_ability.gd`) - Healing projectile
- **Suicide Bomb** (`suicide_bomb_ability.gd`) - Proximity-activated self-destruct with AI auto-activation

### Implemented Boons

Here are some boons already implemented using this system:

- **Damage Boon** (`damage_boon.gd`) - Simple stat increase
- **AoE Boon** (`aoe_boon.gd`) - 5% MORE scaling example
- **Arc Extension** (`arc_extension_boon.gd`) - Weapon modifier
- **Glass Cannon** (`glass_cannon_boon.gd`) - Unique risk/reward
- **Vampiric** (`vampiric_boon.gd`) - Unique mechanic
- **Twin Slash** (Mentioned in docs) - Stackable unique

### Implemented NPCs

Here are NPCs already implemented using this system:

- **TwitchRat** (`twitch_rat.gd`) - Basic melee creature with abilities
- **Succubus** (`succubus.gd`) - Evolved ranged creature with projectiles  
- **Woodland Joe** (`woodland_joe.gd`) - Evolved creature with bark shield
- **Ugandan Warrior** (`ugandan_warrior.gd`) - Fast suicide bomber with proximity activation
  - Size: 0.56 scale (30% smaller)
  - Base damage: 1 (melee hit)
  - Explosion damage: 100
  - Uses SuicideBombAbility with AI auto-activation

Study these for real-world examples of the patterns described in the guides.

---

*Remember: The goal isn't just to "make it work" — it's to make it work well, now and years from now.*
