class_name AoEAbilityTemplate
extends BaseAbility

## Template for Area of Effect abilities (Explosion, Nova, Earthquake, etc.)
## Copy this file and rename for your specific AoE ability

# AoE properties
@export_group("Area of Effect Settings")
@export var damage: float = 50.0
@export var effect_radius: float = 150.0
@export var telegraph_time: float = 0.5  # Warning before effect
@export var effect_duration: float = 0.1  # How long the damage lasts
@export var knockback_force: float = 200.0
@export var max_targets: int = -1  # -1 = unlimited

# Targeting options
@export_group("Targeting")
@export var target_enemies: bool = true
@export var target_allies: bool = false
@export var affects_caster: bool = false
@export var damage_falloff: bool = false  # Less damage at edges

# Visual/Audio
@export_group("Visual and Audio")
@export var effect_scene_path: String = "res://entities/effects/your_aoe_effect.tscn"
@export var telegraph_scene_path: String = "res://entities/effects/aoe_telegraph.tscn"
@export var impact_sound_path: String = ""
@export var cast_animation: String = "cast_aoe"
@export var screen_shake_intensity: float = 5.0
@export var screen_shake_duration: float = 0.3

# Cached resources
var effect_scene: PackedScene
var telegraph_scene: PackedScene
var impact_sound: AudioStream

func _init() -> void:
    # TODO: Set unique ability ID
    ability_id = "aoe_template"
    ability_name = "AoE Template"
    ability_description = "Creates an area effect that damages enemies"
    
    # TODO: Set appropriate tags
    ability_tags = ["AoE", "Physical"]  # Add element tags
    
    ability_type = 0  # ACTIVE
    base_cooldown = 5.0
    
    # TODO: Adjust resource costs
    resource_costs = {
        "mana": 30.0
    }
    
    # TODO: Choose targeting type
    targeting_type = 5  # AREA_AROUND_SELF
    # targeting_type = 3  # AREA (ground targeted)
    base_range = 0.0  # For self-centered, or set range for ground-targeted

func on_added(holder) -> void:
    super.on_added(holder)
    
    # Preload resources
    if effect_scene_path != "":
        effect_scene = load(effect_scene_path)
    if telegraph_scene_path != "":
        telegraph_scene = load(telegraph_scene_path)
    if impact_sound_path != "":
        impact_sound = load(impact_sound_path)
    
    print("💥 ", ability_name, " added to ", _get_entity_name(holder))

func can_execute(holder, target_data) -> bool:
    if not super.can_execute(holder, target_data):
        return false
    
    var entity = _get_entity(holder)
    if not entity:
        return false
    
    # Check if entity is alive
    if entity.has_method("is_alive") and not entity.is_alive:
        return false
    
    # TODO: Add custom checks
    # Example: Check if grounded for earthquake
    # if entity.has_method("is_grounded") and not entity.is_grounded():
    #     return false
    
    return true

func _execute_ability(holder, target_data) -> void:
    var entity = _get_entity(holder)
    if not entity:
        return
    
    # Report to action feed
    _report_to_action_feed(entity)
    
    # Play animation
    _play_animation(holder, cast_animation)
    
    # Determine effect position
    var effect_position = _get_effect_position(entity, target_data)
    
    # Show telegraph if configured
    if telegraph_time > 0:
        _show_telegraph(entity, effect_position)
        await entity.get_tree().create_timer(telegraph_time).timeout
    
    # Execute the AoE effect
    _perform_aoe_effect(entity, holder, effect_position)
    
    # Start cooldown
    _start_cooldown(holder)
    
    # Notify systems
    holder.on_ability_executed(self)
    executed.emit(target_data)

func _get_effect_position(entity, target_data) -> Vector2:
    match targeting_type:
        5:  # AREA_AROUND_SELF
            return entity.global_position
        3:  # AREA (ground targeted)
            return target_data.target_position
        _:
            return entity.global_position

func _show_telegraph(entity, position: Vector2) -> void:
    if not telegraph_scene:
        return
    
    var telegraph = telegraph_scene.instantiate()
    entity.get_parent().add_child(telegraph)
    telegraph.global_position = position
    
    # Configure telegraph
    if telegraph.has_method("setup"):
        telegraph.setup(effect_radius, telegraph_time, Color.RED)
    
    # Auto-remove after telegraph time
    telegraph.create_tween().tween_callback(telegraph.queue_free).set_delay(telegraph_time)

func _perform_aoe_effect(entity, holder, position: Vector2) -> void:
    # Visual effect
    _spawn_visual_effect(entity, position)
    
    # Sound effect
    _play_impact_sound(entity, position)
    
    # Screen shake
    _apply_screen_shake(entity)
    
    # Find and damage targets
    var targets = _find_targets_in_area(entity, position)
    _apply_damage_to_targets(entity, holder, targets, position)

func _spawn_visual_effect(entity, position: Vector2) -> void:
    if not effect_scene:
        return
    
    var effect = effect_scene.instantiate()
    entity.get_parent().add_child(effect)
    effect.global_position = position
    
    # Configure effect
    if effect.has_property("radius"):
        effect.radius = effect_radius
    if effect.has_property("duration"):
        effect.duration = effect_duration
    
    # Apply AoE scaling from entity
    if entity.has_method("get_aoe_multiplier"):
        var aoe_scale = entity.get_aoe_multiplier()
        if effect.has_property("scale"):
            effect.scale *= aoe_scale
        if effect.has_property("radius"):
            effect.radius *= aoe_scale

func _find_targets_in_area(entity, position: Vector2) -> Array:
    var targets = []
    
    # Use physics query to find targets
    var space_state = entity.get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = effect_radius
    
    query.shape = circle
    query.transform = Transform2D(0, position)
    query.collision_mask = 0
    
    # Set collision mask based on target settings
    if target_enemies:
        query.collision_mask |= 2  # Enemy layer
    if target_allies:
        query.collision_mask |= 1  # Player layer
    
    var results = space_state.intersect_shape(query)
    
    for result in results:
        var target = result.collider
        
        # Skip invalid targets
        if not is_instance_valid(target):
            continue
            
        # Skip self unless affects_caster is true
        if target == entity and not affects_caster:
            continue
        
        # Check if target can take damage
        if not target.has_method("take_damage"):
            continue
        
        # Check if target is alive
        if target.has_method("is_alive") and not target.is_alive:
            continue
        
        targets.append({
            "node": target,
            "distance": position.distance_to(target.global_position)
        })
    
    # Sort by distance for damage falloff or max target limiting
    targets.sort_custom(func(a, b): return a.distance < b.distance)
    
    # Limit targets if configured
    if max_targets > 0 and targets.size() > max_targets:
        targets = targets.slice(0, max_targets)
    
    return targets

func _apply_damage_to_targets(entity, holder, targets: Array, effect_position: Vector2) -> void:
    for target_data in targets:
        var target = target_data.node
        var distance = target_data.distance
        
        # Calculate damage with falloff if enabled
        var final_damage = get_modified_value(damage, "spell_power", holder)
        if damage_falloff and effect_radius > 0:
            var falloff_factor = 1.0 - (distance / effect_radius) * 0.5
            final_damage *= max(0.5, falloff_factor)  # Min 50% damage
        
        # Apply damage
        # NOTE: For instant AoE, passing entity is correct
        # For persistent effects (DoT areas), the effect should pass itself
        # and implement get_killer_display_name() to delegate to entity
        target.take_damage(final_damage, entity, ability_tags)
        
        # Apply knockback if configured
        if knockback_force > 0 and target.has_method("apply_knockback"):
            var knockback_dir = (target.global_position - effect_position).normalized()
            target.apply_knockback(knockback_dir * knockback_force)
        
        # Notify ability hit
        holder.on_ability_hit(self, target)

func _play_impact_sound(entity, position: Vector2) -> void:
    if impact_sound and AudioManager.instance:
        # Create temporary node for positional audio
        var audio_node = Node2D.new()
        entity.get_parent().add_child(audio_node)
        audio_node.global_position = position
        
        AudioManager.instance.play_sfx_on_node(
            impact_sound,
            audio_node,
            0.1,  # slight pitch variation
            1.0   # volume
        )
        
        # Clean up after sound
        audio_node.create_tween().tween_callback(audio_node.queue_free).set_delay(3.0)

func _apply_screen_shake(entity) -> void:
    if screen_shake_intensity <= 0:
        return
    
    # Try to shake camera through entity
    if entity.has_method("shake_camera"):
        entity.shake_camera(screen_shake_duration, screen_shake_intensity)
    # Or through game controller
    elif GameController.instance and GameController.instance.has_method("shake_camera"):
        GameController.instance.shake_camera(screen_shake_duration, screen_shake_intensity)

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

func _play_animation(holder, anim_name: String) -> void:
    if holder.has_method("play_animation"):
        holder.play_animation(anim_name)

# Override to show AoE range
func get_range() -> float:
    if targeting_type == 3:  # Ground targeted
        return base_range
    else:  # Self-centered
        return effect_radius
