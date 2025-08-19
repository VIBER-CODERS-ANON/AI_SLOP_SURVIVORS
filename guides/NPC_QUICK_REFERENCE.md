# NPC Implementation Quick Reference

## Copy-Paste Templates

### Basic Melee NPC
```gdscript
extends BaseCreature
class_name MyMeleeNPC

func _entity_ready():
    super._entity_ready()
    _setup_npc()

func _setup_npc():
    creature_type = "MyCreature"
    base_scale = 1.0
    abilities = []
    
    max_health = 20
    current_health = max_health
    move_speed = 120
    damage = 5
    attack_range = 60
    attack_cooldown = 1.0
    attack_type = AttackType.MELEE
    has_mana = false
    
    if taggable:
        taggable.add_tag("Enemy")
        taggable.add_tag("TwitchMob")
        taggable.add_tag("MyCreature")
        taggable.add_tag("Melee")
    
    add_to_group("enemies")
    add_to_group("ai_controlled")
```

### Basic Ranged NPC
```gdscript
extends BaseCreature
class_name MyRangedNPC

var projectile_ability: ProjectileAbility

func _entity_ready():
    super._entity_ready()
    _setup_npc()

func _setup_npc():
    creature_type = "MyShooter"
    base_scale = 1.0
    abilities = ["shoot"]
    
    max_health = 30
    current_health = max_health
    move_speed = 150
    damage = 3
    attack_range = 200
    attack_cooldown = 1.5
    attack_type = AttackType.RANGED
    preferred_attack_distance = 180
    has_mana = false
    
    if taggable:
        taggable.add_tag("Enemy")
        taggable.add_tag("TwitchMob")
        taggable.add_tag("MyShooter")
        taggable.add_tag("Ranged")
    
    add_to_group("enemies")
    add_to_group("ai_controlled")
    call_deferred("_setup_abilities")

func _setup_abilities():
    await get_tree().create_timer(0.1).timeout
    
    if ability_manager and ability_holder:
        ability_manager.ability_holder = ability_holder
    
    projectile_ability = ProjectileAbility.new()
    add_ability(projectile_ability)
```

### Evolved/Boss NPC
```gdscript
extends BaseEvolvedCreature
class_name MyBossNPC

func _entity_ready():
    evolution_mxp_cost = 50
    evolution_name = "MyBoss"
    
    super._entity_ready()
    _setup_evolution()

func _setup_evolution():
    creature_type = "Boss"
    base_scale = 1.5
    abilities = ["special_attack", "aoe_slam"]
    
    max_health = 200
    current_health = max_health
    move_speed = 100
    damage = 20
    attack_range = 100
    detection_range = 2000
    attack_cooldown = 2.0
    attack_type = AttackType.MELEE
    
    if taggable:
        taggable.permanent_tags = ["Enemy", "Boss", "Evolved", "TwitchMob"]
        taggable.add_tag("Boss")
        taggable.add_tag("Melee")
    
    add_to_group("enemies")
    add_to_group("ai_controlled")
    add_to_group("bosses")
```

## Scene File Template (.tscn)
```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://entities/enemies/my_npc.gd" id="1"]
[ext_resource type="Texture2D" path="res://entities/enemies/my_npc.png" id="2"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 10.0

[node name="MyNPC" type="CharacterBody2D"]
z_index = 4
collision_layer = 2
collision_mask = 3
script = ExtResource("1")

[node name="Sprite" type="Sprite2D" parent="."]
texture = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_1")
```

## Common Patterns

### Aggro + Wander Pattern
```gdscript
@export var aggro_radius: float = 1500.0
var is_aggroed: bool = false
var wander_timer: float = 0.0
var wander_change_interval: float = 2.0

func _entity_physics_process(delta):
    _check_aggro_range()
    
    var ai_controller = get_node_or_null("AIMovementController")
    if ai_controller:
        if is_aggroed:
            super._entity_physics_process(delta)
        else:
            _handle_wandering(delta)
    
    _face_movement_direction()

func _check_aggro_range():
    var player = _find_player()
    if not player:
        return
    
    var distance = global_position.distance_to(player.global_position)
    if not is_aggroed and distance <= aggro_radius:
        is_aggroed = true

func _handle_wandering(delta):
    wander_timer += delta
    if wander_timer >= wander_change_interval:
        _randomize_wander_target()
        wander_timer = 0.0

func _randomize_wander_target():
    var ai_controller = get_node_or_null("AIMovementController")
    if not ai_controller:
        return
    
    if randf() < 0.3:
        ai_controller.set_target_position(global_position)
    else:
        var angle = randf() * TAU
        var offset = Vector2(cos(angle), sin(angle)) * randf_range(50, 250)
        ai_controller.set_target_position(global_position + offset)

func _face_movement_direction():
    if not sprite or movement_velocity.x == 0:
        return
    
    if movement_velocity.x > 0:
        sprite.scale.x = abs(sprite.scale.x) * base_scale
    else:
        sprite.scale.x = -abs(sprite.scale.x) * base_scale
```

### Ability Combat Pattern
```gdscript
func _entity_physics_process(delta):
    super._entity_physics_process(delta)
    
    if is_aggroed and target_player and is_instance_valid(target_player):
        var distance = global_position.distance_to(target_player.global_position)
        
        # Try abilities in priority order
        if ability1 and ability1.can_execute(self, create_target_data()):
            if distance <= ability1.base_range:
                execute_ability("ability1", create_target_data())
        elif ability2 and ability2.can_execute(self, create_target_data()):
            if distance <= ability2.base_range:
                execute_ability("ability2", create_target_data())

func create_target_data():
    return AbilityTargetData.create_single_target(target_player, target_player.global_position)
```

## Quick Stats Reference

### Health Tiers
- Fodder: 10-20 HP
- Standard: 30-50 HP
- Elite: 80-120 HP
- Boss: 200+ HP

### Speed Tiers
- Slow: 80-120
- Normal: 140-180
- Fast: 200-250
- Boost/Special: 300+

### Attack Ranges
- Melee: 50-80
- Mid-range: 100-150
- Ranged: 150-250
- Sniper: 300+

### Damage Tiers
- Weak: 1-5
- Standard: 8-15
- Strong: 20-30
- Boss: 40+

## Common Tags
```gdscript
# Required
"Enemy"

# Type Tags
"TwitchMob", "Boss", "Minion", "Elite"

# Attack Style
"Melee", "Ranged", "Caster"

# Movement
"Flying", "Ground", "Burrowing"

# Special
"Evolved", "Lesser", "Summoned"
```

## Debug One-Liners
```gdscript
print("🎮 %s spawned" % creature_type)
print("⚔️ Attacking %s" % target_player.name)
print("💥 %s died" % get_display_name())
```
