# Ability System Quick Reference

## Common Code Patterns

### Getting Entity from Holder
```gdscript
func _get_entity(holder):
    if holder.has_method("get_entity_node"):
        return holder.get_entity_node()
    return holder
```

### Checking Valid Target
```gdscript
if not is_instance_valid(target):
    return false
if target.has_method("is_alive") and not target.is_alive:
    return false
```

### Scaling Values with Stats
```gdscript
var final_damage = get_modified_value(base_damage, "spell_power", holder)
var final_radius = get_modified_value(base_radius, "aoe_size", holder)
```

### Playing Sound Effects
```gdscript
if sound_effect and AudioManager.instance:
    AudioManager.instance.play_sfx_on_node(sound_effect, entity, 0.0, 1.0)
```

### Creating Visual Effects
```gdscript
if effect_scene:
    var effect = effect_scene.instantiate()
    entity.get_parent().add_child(effect)
    effect.global_position = target_position
```

### Action Feed Integration
```gdscript
if entity.has_method("get_chatter_username") and GameController.instance:
    var action_feed = GameController.instance.get_action_feed()
    if action_feed:
        action_feed.custom_ability(entity.get_chatter_username(), ability_name)
```

## Targeting Types

| Type | Value | Use Case |
|------|-------|----------|
| SELF | 0 | Self-buffs, self-heals |
| SINGLE_TARGET | 1 | Targeted spells |
| MULTI_TARGET | 2 | Chain lightning |
| AREA | 3 | Ground-targeted AoE |
| DIRECTION | 4 | Skillshots, dashes |
| AREA_AROUND_SELF | 5 | PBAoE (Point Blank AoE) |

## Common Ability Tags

### Damage Types
- `Physical`
- `Magical`
- `Fire`
- `Ice`
- `Lightning`
- `Poison`
- `Holy`
- `Shadow`

### Ability Types
- `Projectile`
- `AoE`
- `DoT` (Damage over Time)
- `HoT` (Heal over Time)
- `Buff`
- `Debuff`
- `Movement`
- `Summon`

### Special Tags
- `Ultimate`
- `Channeled`
- `Instant`
- `Melee`
- `Ranged`
- `Environmental`

## Resource Types

```gdscript
resource_costs = {
    "mana": 20.0,
    "health": 5.0,
    "stamina": 10.0,
    "rage": 25.0,
    "energy": 15.0
}
```

## Finding Targets in Area

```gdscript
func _find_targets_in_radius(entity, center: Vector2, radius: float, collision_mask: int) -> Array:
    var space_state = entity.get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = radius
    
    query.shape = circle
    query.transform = Transform2D(0, center)
    query.collision_mask = collision_mask
    
    var results = space_state.intersect_shape(query)
    var targets = []
    
    for result in results:
        if is_instance_valid(result.collider):
            targets.append(result.collider)
    
    return targets
```

## Collision Layers (Project Standard)

| Layer | Bit | Purpose |
|-------|-----|---------|
| 1 | 1 | Player |
| 2 | 2 | Enemies |
| 3 | 4 | Terrain/Walls |
| 4 | 8 | Projectiles |
| 5 | 16 | Pickups |
| 6 | 32 | Effects |

## Status Effect Checks

```gdscript
# Check if stunned
if entity.has_method("has_status") and entity.has_status("Stunned"):
    return false

# Check if silenced (can't cast)
if entity.has_method("is_silenced") and entity.is_silenced():
    return false

# Check if rooted (can't move)
if entity.has_method("has_status") and entity.has_status("Rooted"):
    return false
```

## Damage Application

```gdscript
# Basic damage
target.take_damage(damage, source_entity, damage_tags)

# With knockback
if target.has_method("apply_knockback"):
    var direction = (target.global_position - source.global_position).normalized()
    target.apply_knockback(direction * knockback_force)

# With status effect
if target.has_method("add_status_effect"):
    var debuff = preload("res://debuffs/burn.gd").new()
    target.add_status_effect(debuff)
```

## Death Attribution

### For Projectiles
```gdscript
# Setup
func setup(owner: Node):
    self.owner_entity = owner
    set_meta("original_owner", owner)

# Damage - pass self, not owner
body.take_damage(damage, self)

# Attribution methods
func get_killer_display_name() -> String:
    if owner_entity and owner_entity.has_method("get_chatter_username"):
        return owner_entity.get_chatter_username()
    return "Someone"

func get_attack_name() -> String:
    return "projectile"
```

### For Area Effects
```gdscript
# Store spawner
set_meta("original_spawner", spawner)
set_meta("source_name", spawner.get_chatter_username())

# Pass self as damage source
target.take_damage(damage, self, tags)

# Delegate attribution
func get_killer_display_name() -> String:
    var spawner = get_meta("original_spawner")
    if spawner and is_instance_valid(spawner):
        return spawner.get_killer_display_name()
    return get_meta("source_name", "Someone")
```

## Common Pitfalls to Avoid

1. **Passing Resource as damage source**
   ```gdscript
   # WRONG - Abilities are Resources, not Nodes
   target.take_damage(damage, self)  # Crashes!
   
   # CORRECT - Pass entity with metadata
   entity.set_meta("active_ability_name", "spell name")
   target.take_damage(damage, entity)
   ```

2. **Not checking is_instance_valid()**
   ```gdscript
   # BAD
   if target:
   
   # GOOD
   if is_instance_valid(target):
   ```

3. **Forgetting to start cooldown**
   ```gdscript
   func _execute_ability(holder, target_data) -> void:
       # ... ability logic ...
       _start_cooldown(holder)  # Don't forget!
   ```

4. **Not cleaning up effects**
   ```gdscript
   func on_removed(holder) -> void:
       # Clean up any persistent effects
       for effect in active_effects:
           if is_instance_valid(effect):
               effect.queue_free()
   ```

5. **Hardcoding values**
   ```gdscript
   # BAD
   var damage = 50.0
   
   # GOOD
   @export var damage: float = 50.0
   ```

6. **Not using the tag system**
   ```gdscript
   # Always tag abilities and effects
   ability_tags = ["Fire", "DoT", "AoE"]
   ```

## Performance Tips

1. **Limit AoE targets**
   ```gdscript
   @export var max_targets: int = 10
   ```

2. **Use object pooling for frequent abilities**
   ```gdscript
   # Instead of instantiate/free, reuse objects
   ```

3. **Optimize particle counts**
   ```gdscript
   # Balance visual quality with performance
   particles.amount = 50  # Not 500
   ```

4. **Cache resources in on_added()**
   ```gdscript
   func on_added(holder) -> void:
       if scene_path != "":
           cached_scene = load(scene_path)
   ```

## Debugging

### Enable Debug Prints
```gdscript
const DEBUG = true

func _execute_ability(holder, target_data) -> void:
    if DEBUG:
        print("[", ability_name, "] Executing on ", _get_entity_name(holder))
```

### Visual Debug
```gdscript
# Draw ability range
func _draw():
    if DEBUG:
        draw_circle(Vector2.ZERO, base_range, Color(1, 0, 0, 0.3))
```

### Common Debug Checks
```gdscript
print("Cooldown: ", is_on_cooldown)
print("Can execute: ", can_execute(holder, target_data))
print("Target valid: ", is_instance_valid(target))
print("Resources: ", entity.current_mana, "/", resource_costs.get("mana", 0))
```
