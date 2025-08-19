# NPC Entity Implementation Guide

## Quick Start Template
```gdscript
extends BaseCreature  # or BaseEvolvedCreature for evolved forms
class_name MyNPC

# Abilities (if any)
var my_ability: MyAbility

func _entity_ready():
    super._entity_ready()
    _setup_npc()

func _setup_npc():
    # REQUIRED: Core properties
    creature_type = "MyNPCType"
    base_scale = 1.0
    abilities = ["ability1", "ability2"]  # Empty array if no abilities
    
    # REQUIRED: Stats
    max_health = 50
    current_health = max_health
    move_speed = 150
    damage = 10
    attack_range = 50  # Melee: 50-60, Ranged: 150+
    attack_cooldown = 1.0
    attack_type = AttackType.MELEE  # or RANGED
    
    # REQUIRED: Tags
    if taggable:
        taggable.add_tag("Enemy")
        taggable.add_tag("TwitchMob")  # If Twitch-spawned
        taggable.add_tag("MyType")
        taggable.add_tag("Melee")  # or "Ranged"
    
    # REQUIRED: Groups
    add_to_group("enemies")
    add_to_group("ai_controlled")
    
    # OPTIONAL: Abilities setup (deferred)
    if abilities.size() > 0:
        call_deferred("_setup_abilities")

func _setup_abilities():
    await get_tree().create_timer(0.1).timeout
    
    if ability_manager and ability_holder:
        ability_manager.ability_holder = ability_holder
    
    # Add abilities
    my_ability = MyAbility.new()
    add_ability(my_ability)
```

## Class Hierarchy

```
BaseEntity → BaseEnemy → BaseCreature → Your NPC
                      ↘ BaseEvolvedCreature → Evolved NPCs
```

### When to Use Each Base Class
- **BaseCreature**: Standard NPCs (Rats, basic enemies)
- **BaseEvolvedCreature**: Advanced forms with evolution mechanics (Succubus, special units)

## Scene Structure (.tscn)

```
CharacterBody2D (YourNPC)
├── Sprite2D or AnimatedSprite2D
├── CollisionShape2D
└── [Optional] AggroArea
    └── AggroRadius (CollisionShape2D)
```

### Scene Properties
```
[node name="YourNPC" type="CharacterBody2D"]
z_index = 4
collision_layer = 2  # Enemies layer
collision_mask = 3   # Detect Player(1) + Enemies(2)
script = ExtResource("your_npc.gd")
```

## Core Implementation Patterns

### 1. Aggro System (Standardized AI Behavior)

**⚠️ IMPORTANT: Use the Built-in AI System**
All enemies should use the standardized `EnemyAIBehavior` component that's automatically created by `BaseEnemy`. DO NOT implement custom aggro or wandering logic unless absolutely necessary.

```gdscript
# In _setup_npc(), configure the existing AI behavior component:
if ai_behavior:
    ai_behavior.aggro_radius = 1500.0         # Screen-wide detection
    ai_behavior.enable_wandering = true
    ai_behavior.wander_radius = 250.0
    ai_behavior.wander_change_interval = 2.0  # Time between wander target changes
```

**Why this matters:** Custom aggro systems can conflict with MXP buffs, rarity modifiers, and other game systems. The standardized AI behavior ensures consistent enemy behavior across all entity types.

### 2. Movement Patterns

The `EnemyAIBehavior` component handles all standard movement patterns automatically:
- **Wandering**: When not aggroed, enemies wander within their wander radius
- **Aggro**: When player enters aggro radius, enemy pursues
- **De-aggro**: When player exits de-aggro radius, enemy returns to wandering

For custom movement patterns, override `_entity_physics_process()` but always call `super._entity_physics_process(delta)` to maintain core functionality.

#### Example: Special Ability Movement
```gdscript
func _entity_physics_process(delta):
    # Always call super to maintain standard behavior
    super._entity_physics_process(delta)
    
    # Add custom ability checks on top
    if not is_channeling_ability:
        _check_special_abilities()
```

### 3. Sprite Direction

**⚠️ CRITICAL: MXP Buff Compatibility**
When implementing sprite direction flipping, you MUST account for the `scale_multiplier` that gets modified by MXP buffs (like !hp which increases size). Never use `abs(sprite.scale.x)` as it will compound scaling effects!

```gdscript
func _face_movement_direction():
    if not sprite:
        return
    
    if velocity.x != 0:
        # IMPORTANT: Calculate actual scale including MXP buffs
        var actual_scale = base_scale * scale_multiplier
        # Sprite faces RIGHT by default
        if velocity.x > 0:
            sprite.scale.x = actual_scale
        else:
            sprite.scale.x = -actual_scale
```

**Why this matters:** The base creature's `_update_visual_scale()` sets `sprite.scale = original_sprite_scale * base_scale * scale_multiplier`. If you use `abs(sprite.scale.x)` when flipping, you're preserving the already-multiplied scale, causing exponential scaling bugs when MXP buffs are applied.

**NEVER use `sprite.flip_h`**: Using flip_h might seem simpler, but it bypasses the scale multiplier system entirely and can cause visual inconsistencies with MXP buffs.

## Ability Integration

### Setup Pattern
```gdscript
func _setup_abilities():
    await get_tree().create_timer(0.1).timeout
    
    # Link ability system
    if ability_manager and ability_holder:
        ability_manager.ability_holder = ability_holder
    
    # Create and configure abilities
    explosion_ability = ExplosionAbility.new()
    explosion_ability.base_cooldown = 2.0
    add_ability(explosion_ability)
```

### Execution Pattern
```gdscript
# For compatibility with old names
func execute_ability(ability_name: String, target_data = null) -> bool:
    match ability_name:
        "old_name":
            return execute_ability("new_ability_id", target_data)
        _:
            return super.execute_ability(ability_name, target_data)
```

## Attack Types Configuration

### Melee Attacker
```gdscript
attack_type = AttackType.MELEE
attack_range = 60
preferred_attack_distance = -1  # Uses attack_range * 0.8
taggable.add_tag("Melee")
```

### Ranged Attacker
```gdscript
attack_type = AttackType.RANGED
attack_range = 150
preferred_attack_distance = 140  # Stay at shooting distance
taggable.add_tag("Ranged")
```

## Critical Implementation Details

### 1. Entity Ready Pattern
```gdscript
func _entity_ready():
    # ALWAYS call super first
    super._entity_ready()
    _setup_npc()
    
    # Defer ability setup to ensure components are ready
    if abilities.size() > 0:
        call_deferred("_setup_abilities")
```

### 2. Death Attribution
```gdscript
func get_killer_display_name() -> String:
    return chatter_username

func get_attack_name() -> String:
    return "bite"  # or specific attack name
```

### 3. Required Exports in .gd
```gdscript
# None required - all configuration in code
# Optional: Visual/audio resource paths
```

### 4. Collision Setup
- **Layer 2**: Enemy bodies
- **Mask 3**: Detect players (1) + enemies (2)
- **Z-index 4**: Above ground, below UI

### 5. Movement Controller
NPCs automatically get `ZombieMovementController` from `BaseEnemy._entity_ready()`

## Common NPC Types

### Basic Melee (Rat Pattern)
- Low health (10-20)
- Slow speed (120-150)
- Contact damage
- Simple abilities (explode, boost)

### Advanced Ranged (Succubus Pattern)
- Medium health (50+)
- Fast speed (180+)
- Projectile attacks
- Complex abilities (channeled, AoE)

### Flying Units
- Add "Flying" tag
- Higher wander range
- No ground collision needed

## Checklist for New NPC

- [ ] Choose correct base class (BaseCreature/BaseEvolvedCreature)
- [ ] Set creature_type, base_scale, abilities array
- [ ] Configure all stats (health, speed, damage, etc.)
- [ ] Set attack_type and appropriate ranges
- [ ] Add required tags (Enemy, type-specific, attack style)
- [ ] Add to required groups (enemies, ai_controlled)
- [ ] Implement aggro system if needed
- [ ] Set up abilities with deferred loading
- [ ] Create scene file with proper structure
- [ ] Set collision layers (2) and masks (3)
- [ ] Test wandering behavior
- [ ] Test combat behavior
- [ ] Verify ability execution
- [ ] Check death attribution

## Quick Debug Commands
```gdscript
print("🎮 %s spawned: %s" % [creature_type, chatter_username])
print("💥 %s aggroed!" % chatter_username)
print("⚔️ %s attacking with %s" % [chatter_username, ability_name])
```

## Recent Updates (Post-Forsen Implementation)

### 1. Boss Health Bar System (OOP)
All bosses now use a reusable `BossHealthBar` component that automatically handles health display:

```gdscript
# In base_boss.gd _ready():
if shows_health_bar:
    boss_health_bar = BossHealthBar.new()
    boss_health_bar.name = "BossHealthBar"
    add_child(boss_health_bar)
```

The BossHealthBar component (`systems/ui_system/boss_health_bar.gd`):
- Automatically creates health bar and label
- Connects to parent's health_changed signal
- Updates display on damage
- Configurable appearance (color, size, offset)
- No manual UI creation needed in game_controller

### 2. Sprite Reference Fixes
When using AnimatedSprite2D instead of Sprite2D, manually update sprite reference after super._ready():

```gdscript
# Fix for bosses using AnimatedSprite2D
func _ready():
    # ... boss setup ...
    super._ready()
    
    # Fix sprite reference if using AnimatedSprite2D
    sprite = get_node_or_null("AnimatedSprite2D")
    if sprite and sprite_texture:
        var frames = SpriteFrames.new()
        frames.add_animation("default")
        frames.add_frame("default", sprite_texture)
        sprite.sprite_frames = frames
        sprite.play("default")
```

### 3. Chat Integration for Boss Abilities
For chat-reactive abilities, the game_controller now emits a signal for all chat messages:

```gdscript
# In game_controller.gd:
signal chat_message_received(username: String, message: String, color: Color)

# In boss script:
func _ready():
    super._ready()
    var game_controller = get_node("/root/GameController")
    if game_controller:
        game_controller.chat_message_received.connect(_on_chat_message)

func _on_chat_message(username: String, message: String, _color: Color):
    # Process chat for ability triggers
    if is_channeling_ability:
        # Check for emotes, keywords etc.
```

### 4. Periodic Ability Pattern
For abilities that trigger on a timer (like Forsen's periodic horse charges):

```gdscript
# Timer-based ability management
var ability_timer: float = 0.0
@export var ability_cooldown: float = 15.0

func _entity_physics_process(delta):
    super._entity_physics_process(delta)
    
    # Update timer
    if ability_timer > 0:
        ability_timer -= delta
    
    # Check abilities
    if not is_channeling and not has_transformed:
        _check_abilities()

func _check_abilities():
    var player = _find_player()
    if not player:
        return
    
    var distance = global_position.distance_to(player.global_position)
    
    # Periodic ability check
    if ability_enabled and ability_timer <= 0:
        if distance < ability_range:
            _trigger_ability()
            ability_timer = ability_cooldown
            return  # Don't use other abilities this frame
```

### 5. Entity Despawning Pattern
For summoned entities that should despawn after their purpose:

```gdscript
# After ability execution (e.g., horse charge)
func _handle_despawn_movement(delta):
    # Continue moving to go off screen
    velocity = direction * move_speed
    move_and_slide()
    
    # Check if off screen
    var viewport_rect = get_viewport_rect()
    var screen_position = get_global_transform_with_canvas().origin
    
    if not viewport_rect.has_point(screen_position):
        _despawn()

func _despawn():
    # No drops per Despawn tag behavior
    queue_free()
```

### 6. Boss Implementation Best Practices
- Always extend BaseBoss for boss entities
- Set all boss_ prefixed properties in _ready()
- Use the OOP BossHealthBar component (automatically added by BaseBoss)
- Handle sprite references properly for AnimatedSprite2D
- Connect to game signals for chat integration
- Use timers for periodic abilities
- Document all abilities and phases clearly

### 7. BaseAbility Helper Functions
The BaseAbility class now includes helper functions for getting entity information:

```gdscript
# Helper functions available in all abilities
func _get_entity(holder):
    # Returns the actual entity from various holder patterns
    
func _get_entity_name(holder) -> String:
    # Returns entity's display name (chatter_username or name)
```

These functions handle different holder patterns:
- Direct entity reference
- AbilityHolder component pattern
- Owner-based references

### 8. Sprite Asset Guidelines
- Godot does not support GIF files directly
- Convert all GIF assets to PNG format before use
- For placeholder sprites, use color modulation to distinguish entities:
  ```gdscript
  sprite.modulate = Color(0.8, 0.4, 0.2)  # Brown for horses
  sprite.modulate = Color(1.2, 0.8, 0.8)  # Red for warriors
  ```

### 9. Programmatic Spritesheet Loading
For entities with large spritesheets (many frames), load them programmatically instead of defining in .tscn:

```gdscript
func _setup_sprite():
    # Get the AnimatedSprite2D node
    sprite = get_node_or_null("AnimatedSprite2D")
    if not sprite:
        return
        
    # Create sprite frames programmatically
    var frames = SpriteFrames.new()
    var texture = load("res://path/to/spritesheet.png")
    
    # Add animation with all frames
    frames.add_animation("run")
    frames.set_animation_speed("run", 30.0)  # FPS
    frames.set_animation_loop("run", true)
    
    # Each frame dimensions
    var frame_width = 354
    var frame_height = 242
    
    # Add all frames from spritesheet
    for i in range(total_frames):
        var atlas_texture = AtlasTexture.new()
        atlas_texture.atlas = texture
        atlas_texture.region = Rect2(i * frame_width, 0, frame_width, frame_height)
        frames.add_frame("run", atlas_texture)
    
    # Apply frames and start animation
    sprite.sprite_frames = frames
    sprite.play("run")
```

This approach is more efficient for spritesheets with 50+ frames and allows dynamic animation control.

### 10. Voice-over and SFX Integration (Event-driven)
- Store boss VO under `res://BespokeAssetSources/character_dialog_sfx/<boss_name>/` with subfolders per event:
  - `spawn/`, `summon_swarm/`, `transform/`, `charge/`, `hit/`, `death/`
- At runtime, use a helper to list all audio files in the event folder and randomly pick one for variety.
- Example boss helper:

```gdscript
func _play_vo(event: String):
    var base := "res://BespokeAssetSources/character_dialog_sfx/forsen"
    var dir_map := {
        "spawn": base + "/spawn",
        "summon_swarm": base + "/summon_swarm",
        "transform": base + "/transform",
        "charge": base + "/charge",
        "hit": base + "/hit",
        "death": base + "/death",
    }
    var path := dir_map.get(event, base)
    var files := _list_audio_files_in(path) # returns .mp3/.ogg/.wav
    if files.is_empty():
        return
    var p := AudioStreamPlayer2D.new()
    add_child(p)
    p.stream = load(files[randi() % files.size()])
    p.play()
```

- For generic SFX sets (e.g., horses), drop files into a shared folder like `res://audio/horses` and pick randomly at runtime.

### 11. WoodlandJoe Fix - Standardized AI Behavior (Post Move Speed Bug Fix)

WoodlandJoe was previously using custom aggro and wandering logic that conflicted with the standardized enemy system. This has been fixed:

**Problems Fixed:**
1. Custom aggro system that bypassed the standard `EnemyAIBehavior` component
2. Manual wandering logic instead of using the built-in system
3. `sprite.flip_h` usage that conflicted with MXP scale multipliers
4. Move speed compounding issue (see `BUG_FIX_MOVE_SPEED_COMPOUNDING.md`)

**Solution Applied:**
- Removed all custom aggro/wandering code
- Let `BaseEnemy` and `EnemyAIBehavior` handle all movement logic
- Fixed sprite direction to use scale-based flipping compatible with MXP buffs
- Ensured move_speed caching in `ChatterEntityManager.apply_upgrades_to_entity()`

**Key Lesson:** Always use the standardized systems rather than implementing custom versions. The built-in AI behavior system handles:
- Aggro detection and state management
- Wandering with configurable parameters
- Movement controller integration
- Proper state transitions

This ensures consistency across all enemies and prevents conflicts with upgrade systems.