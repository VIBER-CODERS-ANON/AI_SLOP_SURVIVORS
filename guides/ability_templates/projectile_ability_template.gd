class_name ProjectileAbilityTemplate
extends BaseAbility

## Template for projectile-based abilities (Fireball, Arrow, Magic Missile, etc.)
## Copy this file and rename for your specific projectile ability

# Projectile properties
@export_group("Projectile Settings")
@export var damage: float = 25.0
@export var projectile_speed: float = 400.0
@export var projectile_lifetime: float = 5.0
@export var pierce_count: int = 0  # 0 = no pierce, -1 = infinite pierce
@export var projectile_count: int = 1  # For multi-shot abilities
@export var spread_angle: float = 15.0  # Degrees between projectiles if count > 1

# Visual/Audio
@export_group("Visual and Audio")
@export var projectile_scene_path: String = "res://entities/projectiles/your_projectile.tscn"
@export var muzzle_flash_scene_path: String = ""
@export var cast_sound_path: String = ""
@export var cast_animation: String = "cast"

# Advanced options
@export_group("Advanced")
@export var homing_strength: float = 0.0  # 0 = no homing, higher = stronger homing
@export var gravity_scale: float = 0.0  # For arcing projectiles
@export var spawn_offset: float = 30.0  # Distance from caster to spawn

# Cached resources
var projectile_scene: PackedScene
var muzzle_flash_scene: PackedScene
var cast_sound: AudioStream

func _init() -> void:
    # TODO: Set unique ability ID
    ability_id = "projectile_template"
    ability_name = "Projectile Template"
    ability_description = "Fires a projectile in the target direction"
    
    # TODO: Set appropriate tags
    ability_tags = ["Projectile", "Physical"]  # Add element tags like "Fire", "Ice", etc.
    
    ability_type = 0  # ACTIVE
    base_cooldown = 1.0
    
    # TODO: Adjust resource costs
    resource_costs = {
        "mana": 10.0
    }
    
    targeting_type = 4  # DIRECTION
    base_range = 800.0  # Max projectile range

func on_added(holder) -> void:
    super.on_added(holder)
    
    # Preload resources
    if projectile_scene_path != "":
        projectile_scene = load(projectile_scene_path)
    if muzzle_flash_scene_path != "":
        muzzle_flash_scene = load(muzzle_flash_scene_path)
    if cast_sound_path != "":
        cast_sound = load(cast_sound_path)
    
    print("🎯 ", ability_name, " added to ", _get_entity_name(holder))

func can_execute(holder, target_data) -> bool:
    if not super.can_execute(holder, target_data):
        return false
    
    var entity = _get_entity(holder)
    if not entity:
        return false
    
    # Check if entity is alive
    if entity.has_method("is_alive") and not entity.is_alive:
        return false
    
    # TODO: Add custom checks (ammo, special conditions, etc.)
    
    return true

func _execute_ability(holder, target_data) -> void:
    var entity = _get_entity(holder)
    if not entity:
        return
    
    # Report to action feed for chatters
    _report_to_action_feed(entity)
    
    # Play sound
    _play_ability_sound(entity)
    
    # Play animation
    _play_animation(holder, cast_animation)
    
    # Spawn muzzle flash
    _spawn_muzzle_flash(entity, target_data)
    
    # Spawn projectile(s)
    _spawn_projectiles(entity, holder, target_data)
    
    # Start cooldown
    _start_cooldown(holder)
    
    # Notify systems
    holder.on_ability_executed(self)
    executed.emit(target_data)

func _spawn_projectiles(entity, holder, target_data) -> void:
    if not projectile_scene:
        push_error("No projectile scene set for " + ability_name)
        return
    
    var base_direction = target_data.target_direction
    
    # Calculate spread for multiple projectiles
    var angle_step = spread_angle if projectile_count > 1 else 0
    var start_angle = -(projectile_count - 1) * angle_step * 0.5
    
    for i in projectile_count:
        var projectile = projectile_scene.instantiate()
        
        # Calculate direction with spread
        var angle_offset = start_angle + (i * angle_step)
        var direction = base_direction.rotated(deg_to_rad(angle_offset))
        
        # Set projectile properties
        _configure_projectile(projectile, entity, holder, direction)
        
        # Add to scene
        entity.get_parent().add_child(projectile)
        
        # Position with offset
        projectile.global_position = entity.global_position + direction * spawn_offset
        
        # Apply initial velocity if projectile has it
        if projectile.has_method("set_velocity"):
            projectile.set_velocity(direction * projectile_speed)

func _configure_projectile(projectile, entity, holder, direction) -> void:
    # Set basic properties
    if projectile.has_method("setup") or projectile.has_property("damage"):
        projectile.damage = get_modified_value(damage, "spell_power", holder)
        projectile.speed = projectile_speed
        projectile.direction = direction
        projectile.lifetime = projectile_lifetime
        projectile.pierce_count = pierce_count
        projectile.source_entity = entity
    
    # IMPORTANT: Ensure projectile has proper death attribution
    # The projectile should pass itself (not entity) as damage source
    # and implement get_killer_display_name() to delegate to entity
    
    # Set advanced properties
    if homing_strength > 0 and projectile.has_property("homing_strength"):
        projectile.homing_strength = homing_strength
    
    if gravity_scale > 0 and projectile.has_property("gravity_scale"):
        projectile.gravity_scale = gravity_scale
    
    # Add ability tags to projectile
    if projectile.has_method("add_tag"):
        for tag in ability_tags:
            projectile.add_tag(tag)
    
    # Set source information for kill attribution
    if entity.has_method("get_chatter_username"):
        projectile.set_meta("source_name", entity.get_chatter_username())
    elif entity.has_method("get_display_name"):
        projectile.set_meta("source_name", entity.get_display_name())

func _spawn_muzzle_flash(entity, target_data) -> void:
    if not muzzle_flash_scene:
        return
    
    var flash = muzzle_flash_scene.instantiate()
    entity.add_child(flash)
    flash.position = Vector2.ZERO
    
    # Rotate to face direction
    flash.rotation = target_data.target_direction.angle()

# Helper methods
func _get_entity(holder):
    if holder.has_method("get_entity_node"):
        return holder.get_entity_node()
    return holder

func _get_entity_name(holder) -> String:
    var entity = _get_entity(holder)
    if entity:
        return entity.name
    return "Unknown"

func _report_to_action_feed(entity) -> void:
    if entity.has_method("get_chatter_username") and GameController.instance:
        var action_feed = GameController.instance.get_action_feed()
        if action_feed and action_feed.has_method("custom_ability"):
            action_feed.custom_ability(entity.get_chatter_username(), ability_name)

func _play_ability_sound(entity) -> void:
    if cast_sound and AudioManager.instance:
        AudioManager.instance.play_sfx_on_node(
            cast_sound,
            entity,
            0.0,  # pitch variation
            1.0   # volume
        )

func _play_animation(holder, anim_name: String) -> void:
    if holder.has_method("play_animation"):
        holder.play_animation(anim_name)

# Override for custom range display
func get_range() -> float:
    return base_range
