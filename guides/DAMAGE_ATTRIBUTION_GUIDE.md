# Damage Attribution Guide

## Overview
This guide explains how to properly implement damage attribution in AI SLOP SURVIVORS to ensure death messages correctly identify who killed the player and with what ability/effect.

## The Problem
Without proper attribution, death messages show generic names like:
- "Explosion killed you with explosion"
- "PoisonCloud killed you with toxic fart cloud"
- "HeartProjectile killed you with heart projectile"

Instead of the actual chatter's username who triggered the effect.

## Core Principles

### 1. Every Damage Source Needs Attribution
Any Node that can deal damage to the player MUST have:
- A `source_name` property to store the killer's username
- A meta value "source_name" for backup attribution
- Proper setup when the damage source is created

### 2. Attribution Chain
The attribution flows through this chain:
1. **Chatter Username** → stored in enemy data
2. **Enemy/Entity** → passes username to effects/projectiles
3. **Effect/Projectile** → stores username in `source_name` and meta
4. **BaseEntity** → reads attribution when player dies
5. **Death Screen** → displays proper username

## Implementation Patterns

### For Explosion Effects

```gdscript
# In explosion_effect.gd
var source_name: String = "Explosion"  # Fallback name

# When creating explosion (e.g., in TicketSpawnManager)
func _create_explosion_at_position(pos: Vector2, username: String = ""):
    var explosion = explosion_scene.instantiate()
    explosion.global_position = pos
    
    # Set the source name for proper death attribution
    if username != "":
        explosion.source_name = username
        explosion.set_meta("source_name", username)
    
    # Apply any upgrades...
    add_child(explosion)
```

### For Poison Clouds

```gdscript
# In poison_cloud.gd
var source_name: String = "Unknown"  # Who created this cloud

# When creating cloud (e.g., in EnemyBridge)
func _trigger_fart_cloud(enemy_id: int, pos: Vector2, config: Dictionary):
    var username = ""
    
    # Get username from enemy data
    if enemy_manager and enemy_id >= 0:
        username = enemy_manager.chatter_usernames[enemy_id]
    
    var cloud = load(cloud_scene_path).instantiate()
    cloud.global_position = pos
    
    # Set source name for proper death attribution
    if username != "":
        cloud.source_name = username
        cloud.set_meta("source_name", username)
    
    add_child(cloud)
```

### For Projectiles

```gdscript
# In heart_projectile.gd
var source_name: String = "Unknown"

func setup(direction: Vector2, speed: float, damage: float, proj_owner: Node):
    owner_entity = proj_owner
    
    if proj_owner:
        set_meta("original_owner", proj_owner)
        
        # Try to get the owner's name
        if proj_owner.has_method("get_chatter_username"):
            source_name = proj_owner.get_chatter_username()
        elif proj_owner.has_method("get_display_name"):
            source_name = proj_owner.get_display_name()
        elif proj_owner.has_meta("chatter_username"):
            source_name = proj_owner.get_meta("chatter_username")
        else:
            source_name = proj_owner.name
        
        set_meta("source_name", source_name)
```

## BaseEntity Death Attribution

The `base_entity.gd` file handles reading attribution from damage sources:

```gdscript
func _get_killer_info() -> Dictionary:
    var killer_name = "Unknown"
    var death_cause = ""
    
    if has_meta("last_damage_source"):
        var source = get_meta("last_damage_source")
        if source and is_instance_valid(source):
            # Try multiple methods to get killer name
            if source.has_method("get_killer_display_name"):
                killer_name = source.get_killer_display_name()
            elif source.has_method("get_chatter_username"):
                killer_name = source.get_chatter_username()
            elif source.has_meta("source_name"):
                killer_name = source.get_meta("source_name")
            elif source.get("source_name"):
                killer_name = source.source_name
            # ... more fallbacks
            
            # Handle specific effect types
            if source is ExplosionEffect and source.source_name != "Explosion":
                killer_name = source.source_name
            elif source is PoisonCloud and killer_name == "PoisonCloud":
                killer_name = "Unknown"  # Don't show class name
```

## Common Mistakes to Avoid

### 1. Variable Scope Issues
```gdscript
# BAD - username only exists in if block
if enemy_manager:
    var username = enemy_manager.chatter_usernames[enemy_id]
# username not accessible here!
if username != "":  # ERROR

# GOOD - declare at function scope
var username = ""
if enemy_manager:
    username = enemy_manager.chatter_usernames[enemy_id]
if username != "":  # Works!
```

### 2. Not Setting Both Property and Meta
```gdscript
# BAD - only setting property
explosion.source_name = username

# GOOD - set both for redundancy
explosion.source_name = username
explosion.set_meta("source_name", username)
```

### 3. Not Checking for Empty Username
```gdscript
# BAD - always setting even if empty
explosion.source_name = username

# GOOD - only set if we have a valid username
if username != "":
    explosion.source_name = username
    explosion.set_meta("source_name", username)
```

## Testing Attribution

To test if attribution is working:
1. Use !explode command → should show chatter's name
2. Use !fart command → should show chatter's name
3. Get hit by projectile → should show enemy's name
4. Die to any effect → should never show class names like "ExplosionEffect"

## Adding New Damage Sources

When adding any new damage-dealing effect:

1. **Add source_name property**
   ```gdscript
   var source_name: String = "Unknown"
   ```

2. **Accept username/owner in creation**
   ```gdscript
   func create_effect(pos: Vector2, username: String = ""):
   ```

3. **Set attribution on creation**
   ```gdscript
   if username != "":
       effect.source_name = username
       effect.set_meta("source_name", username)
   ```

4. **Test death messages**
   - Verify correct username appears
   - Check death cause is descriptive
   - Ensure no class names leak through

## V2 Enemy System Integration

For data-oriented enemies, username is stored in arrays:
```gdscript
# In EnemyManager
var chatter_usernames: PackedStringArray

# In EnemyBridge when creating effects
var username = ""
if enemy_manager and enemy_id >= 0:
    username = enemy_manager.chatter_usernames[enemy_id]

# Pass to effect creation
_create_effect(pos, username)
```

## Best Practices

1. **Always initialize username as empty string** at function scope
2. **Set both property and meta** for redundancy
3. **Check for valid username** before setting
4. **Use descriptive death causes** not class names
5. **Test with actual gameplay** not just code review
6. **Apply AOE scaling** when username is available (for upgraded chatters)
7. **Document attribution flow** in new effect classes