# Advanced Boss Spawner System

An improved boss/monster spawning system using GDScript resource configurations for maximum flexibility and type safety.

## 🌟 Features

- **Type-safe configuration** using GDScript resources
- **Visual editor support** with @export variables
- **Hot-reloading** of boss configurations
- **Weighted spawning** system
- **Integration** with existing V2 enemy system
- **Flexible ability system** for boss special attacks
- **Automatic spawn history** tracking
- **Rarity-based** boss categorization

## 📁 System Architecture

```
systems/boss_spawner/
├── boss_config.gd              # Main boss configuration resource
├── boss_ability_config.gd      # Boss ability definitions
├── advanced_boss_spawner.gd    # Core spawning system
├── boss_spawner_integration.gd # Helper functions
├── boss_spawner_test.gd       # Testing utilities
└── README.md                  # This file

data/boss_configs/             # Generated boss configuration files
├── zzran.tres
├── thor.tres
├── mika.tres
└── forsen.tres
```

## 🚀 Quick Start

### 1. Adding the Spawner to Your Game

The spawner is automatically added to GameController. You can also add it manually:

```gdscript
# Add to your scene
var spawner = AdvancedBossSpawner.new()
spawner.name = "AdvancedBossSpawner"
add_child(spawner)
```

### 2. Spawning a Boss

```gdscript
# Get the spawner
var spawner = BossSpawnerIntegration.get_boss_spawner()

# Spawn by ID
var boss = spawner.spawn_boss("thor", Vector2(100, 100))

# Or use the integration helper
var boss = BossSpawnerIntegration.spawn_boss_by_vote("zzran")
```

### 3. Creating a Custom Boss

```gdscript
# Create the configuration
var config = BossSpawnerIntegration.create_custom_boss_config(
    "fire_demon",
    "Fire Demon", 
    "🔥 Fire Demon - Infernal Destroyer",
    "A powerful demon wreathed in flames"
)

# Customize stats
config.base_health = 200.0
config.base_damage = 15.0
config.move_speed = 55.0
config.rarity = "epic"

# Visual effects
config.color_tint = Color(1.0, 0.3, 0.0)
config.glow_effect = true
config.particle_effect = "fire"

# Save and register
BossSpawnerIntegration.save_boss_config(config)
```

## 🎮 Boss Configuration Properties

### Basic Info
- `id`: Unique identifier
- `name`: Display name
- `display_name`: Full display name with emoji/formatting
- `description`: Boss description

### Visual Assets
- `sprite_texture`: Main sprite texture
- `sprite_frames`: SpriteFrames resource for animation
- `icon_texture`: Icon for UI displays

### Stats
- `base_health`: Starting health points
- `base_damage`: Base damage per attack
- `move_speed`: Movement speed
- `attack_range`: Attack reach distance
- `attack_cooldown`: Time between attacks
- `collision_radius`: Collision detection radius

### Spawn Settings
- `rarity`: "common", "uncommon", "rare", "epic", "legendary", "unique"
- `spawn_weight`: Weight for random selection (higher = more likely)
- `max_spawns_per_session`: Maximum spawns per game session
- `required_mxp_threshold`: MXP required to spawn
- `min_player_level`: Minimum player level requirement

### Visual Effects
- `scale_multiplier`: Size multiplier (1.0 = normal size)
- `color_tint`: Color tint overlay
- `glow_effect`: Enable glow effect
- `particle_effect`: Particle effect type
- `spawn_effect_color`: Color of spawn effects

### AI Behavior
- `ai_type`: "aggressive", "defensive", "spell_caster", "hit_and_run", "chaotic"
- `charge_distance`: Distance at which boss charges player
- `retreat_distance`: Distance boss retreats when low health
- `aggro_range`: Range at which boss detects player
- `special_behavior`: Special behavior flags

### Audio
- `spawn_sound`: Sound played when spawning
- `death_sound`: Sound played when dying
- `attack_sound`: Sound played when attacking
- `hurt_sound`: Sound played when taking damage

### Rewards
- `xp_multiplier`: XP reward multiplier
- `mxp_bonus`: Bonus MXP awarded to chatters
- `special_drops`: Array of special items dropped

## 🎯 Integration with Existing Systems

### Boss Vote System
```gdscript
# Update boss_vote_manager.gd to use new spawner
func spawn_winning_boss(boss_id: String):
    return BossSpawnerIntegration.spawn_boss_by_vote(boss_id)
```

### V2 Enemy System
The spawner automatically integrates with EnemyManagerV2:
- Maps boss configs to V2 enemy types
- Applies boss modifications through V2 API
- Maintains compatibility with data-oriented approach

### Legacy Boss Functions
Legacy functions like `spawn_zzran_boss()` now automatically use the new system with fallback to old methods.

## 🧪 Testing

### Debug Commands
- `Shift + F5`: Spawn Thor
- `Shift + F6`: Spawn ZZran  
- `Shift + F7`: Spawn Custom Demon
- `Shift + F8`: List All Bosses

### Console Commands (if limbo_console available)
- `boss_spawn_thor`
- `boss_spawn_zzran`
- `boss_spawn_demon`
- `boss_list`
- `boss_reset`

### Programmatic Testing
```gdscript
# Add test node to your scene
var tester = BossSpawnerTest.new()
add_child(tester)

# Or call test functions directly
BossSpawnerIntegration.test_spawn_custom_boss()
```

## 🔧 Advanced Usage

### Custom Ability System
```gdscript
# Create boss ability
var ability = BossAbilityConfig.new()
ability.ability_id = "fire_blast"
ability.ability_name = "Fire Blast"
ability.cooldown = 5.0
ability.damage_multiplier = 2.0
ability.aoe_radius = 80.0
ability.effect_color = Color.RED

# Add custom parameters
ability.set_parameter("burn_duration", 3.0)
ability.set_parameter("burn_damage", 5.0)

# Add to boss config
boss_config.ability_configs.append(ability)
```

### Weighted Spawning
```gdscript
# Get available bosses based on conditions
var available = spawner.get_available_bosses(player_level, mxp_amount)

# Select using weighted probability
var selected = spawner.get_weighted_random_boss(available)
```

### Spawn History Tracking
```gdscript
# Check spawn statistics
var stats = spawner.get_spawn_statistics()
print("Bosses spawned this session: %s" % stats.spawn_history)

# Reset for new session
spawner.reset_spawn_history()
```

## 🛠️ Extending the System

### Adding New Rarity Types
Edit `BossConfig.get_rarity_color()`:
```gdscript
func get_rarity_color() -> Color:
    match rarity.to_lower():
        "mythic": return Color.MAGENTA
        "divine": return Color.WHITE
        # ... existing cases
```

### Custom AI Types
Add new AI behaviors in the enemy V2 system and reference them in boss configs:
```gdscript
config.ai_type = "custom_berserker"
config.special_behavior = "rage_mode_on_low_health"
```

### Integration with Other Systems
```gdscript
# Connect to boss events
spawner.boss_spawned.connect(_on_boss_spawned)
spawner.boss_spawn_failed.connect(_on_boss_spawn_failed)

func _on_boss_spawned(boss_id: String, boss_node: Node):
    print("Boss spawned: %s" % boss_id)
    # Add to boss tracking systems
    # Update UI displays
    # Play spawn announcements
```

## 📈 Performance Considerations

- Boss configs are cached in memory after first load
- .tres files provide fast binary serialization
- Weighted selection uses O(n) algorithm
- Integration with V2 system maintains data-oriented performance
- No runtime JSON/YAML parsing overhead

## 🐛 Troubleshooting

### Boss Not Spawning
1. Check if boss config exists: `spawner.boss_configs.has(boss_id)`
2. Verify spawn conditions: `config.is_spawn_allowed()`
3. Check concurrent boss limit: `spawner.active_bosses.size()`

### Configuration Issues
1. Ensure .tres files are in `res://data/boss_configs/`
2. Check for resource loading errors in debugger
3. Verify BossConfig class is properly extended

### Integration Problems
1. Confirm AdvancedBossSpawner is added to scene tree
2. Check GameController.instance is available
3. Verify V2 enemy system is initialized

## 📚 Future Enhancements

- [ ] Visual boss editor in Godot IDE
- [ ] Boss behavior trees
- [ ] Dynamic difficulty scaling
- [ ] Seasonal/event bosses
- [ ] Boss mutation system
- [ ] Multiplayer boss synchronization

---

*This system provides a solid foundation for scalable boss management while maintaining compatibility with the existing V2 architecture.*