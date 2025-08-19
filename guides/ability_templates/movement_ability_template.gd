class_name MovementAbilityTemplate
extends BaseAbility

## Template for movement abilities (Dash, Teleport, Leap, Charge, etc.)
## Copy this file and rename for your specific movement ability

# Movement properties
@export_group("Movement Settings")
@export var movement_type: String = "dash"  # "dash", "teleport", "leap", "charge"
@export var movement_distance: float = 300.0
@export var movement_speed: float = 1000.0  # For dash/charge
@export var movement_duration: float = 0.3  # Time to complete movement
@export var can_pass_through_enemies: bool = true
@export var stops_on_collision: bool = false  # For charge abilities

# Combat properties
@export_group("Combat Settings")
@export var deals_damage: bool = false
@export var damage: float = 20.0
@export var damage_radius: float = 50.0  # For AoE damage on arrival/path
@export var applies_on_hit_effects: bool = true
@export var grants_invulnerability: bool = true  # During movement
@export var breaks_targeting: bool = true  # Enemies lose target

# Movement modifiers
@export_group("Movement Modifiers")
@export var minimum_distance: float = 50.0  # Can't move less than this
@export var maximum_distance: float = 500.0  # Can't move more than this
@export var requires_ground: bool = false  # For leap abilities
@export var can_cross_gaps: bool = true  # For teleport/leap
@export var snap_to_ground: bool = true  # Land on ground after leap

# Visual/Audio
@export_group("Visual and Audio")
@export var trail_scene_path: String = "res://entities/effects/dash_trail.tscn"
@export var arrival_effect_path: String = "res://entities/effects/teleport_arrival.tscn"
@export var departure_effect_path: String = "res://entities/effects/teleport_departure.tscn"
@export var movement_sound_path: String = ""
@export var impact_sound_path: String = ""
@export var movement_animation: String = "dash"

# After-movement effects
@export_group("After Effects")
@export var leave_trail: bool = false  # Damaging trail
@export var trail_damage_per_second: float = 10.0
@export var trail_duration: float = 2.0
@export var speed_boost_after: float = 0.0  # Percentage speed increase
@export var speed_boost_duration: float = 2.0

# Cached resources
var trail_scene: PackedScene
var arrival_effect: PackedScene
var departure_effect: PackedScene
var movement_sound: AudioStream
var impact_sound: AudioStream

# Movement state
var is_moving: bool = false
var movement_start_pos: Vector2
var movement_target_pos: Vector2
var movement_progress: float = 0.0
var original_collision_mask: int

func _init() -> void:
    # TODO: Set unique ability ID
    ability_id = "movement_template"
    ability_name = "Movement Template"
    ability_description = "Quickly move in a direction"
    
    # TODO: Set appropriate tags
    ability_tags = ["Movement", "Mobility"]
    
    ability_type = 0  # ACTIVE
    base_cooldown = 3.0
    
    # TODO: Adjust resource costs
    resource_costs = {}  # Movement abilities often cost no resources
    
    targeting_type = 4  # DIRECTION - most movement abilities
    base_range = movement_distance

func on_added(holder) -> void:
    super.on_added(holder)
    
    # Preload resources
    if trail_scene_path != "":
        trail_scene = load(trail_scene_path)
    if arrival_effect_path != "":
        arrival_effect = load(arrival_effect_path)
    if departure_effect_path != "":
        departure_effect = load(departure_effect_path)
    if movement_sound_path != "":
        movement_sound = load(movement_sound_path)
    if impact_sound_path != "":
        impact_sound = load(impact_sound_path)
    
    print("💨 ", ability_name, " added to ", _get_entity_name(holder))

func can_execute(holder, target_data) -> bool:
    if not super.can_execute(holder, target_data):
        return false
    
    if is_moving:
        return false  # Can't use while already moving
    
    var entity = _get_entity(holder)
    if not entity:
        return false
    
    # Check if entity is alive
    if entity.has_method("is_alive") and not entity.is_alive:
        return false
    
    # Check if entity can move
    if entity.has_method("can_move") and not entity.can_move():
        return false
    
    # Check if rooted or stunned
    if entity.has_method("has_status") and (entity.has_status("Rooted") or entity.has_status("Stunned")):
        return false
    
    # Check ground requirement for leaps
    if requires_ground and entity.has_method("is_on_floor") and not entity.is_on_floor():
        return false
    
    return true

func update(delta: float, holder) -> void:
    super.update(delta, holder)
    
    # Handle movement update
    if is_moving:
        _update_movement(delta, holder)

func _execute_ability(holder, target_data) -> void:
    var entity = _get_entity(holder)
    if not entity:
        return
    
    # Calculate movement destination
    var direction = target_data.target_direction.normalized()
    var distance = clamp(movement_distance, minimum_distance, maximum_distance)
    movement_start_pos = entity.global_position
    movement_target_pos = movement_start_pos + direction * distance
    
    # Validate movement path
    if not can_cross_gaps:
        movement_target_pos = _validate_movement_path(entity, movement_start_pos, movement_target_pos)
    
    # Report to action feed
    _report_to_action_feed(entity)
    
    # Play animation
    _play_animation(holder, movement_animation)
    
    # Start movement based on type
    match movement_type:
        "teleport":
            _execute_teleport(entity, holder)
        "dash":
            _start_dash(entity, holder)
        "leap":
            _start_leap(entity, holder)
        "charge":
            _start_charge(entity, holder)
        _:
            _start_dash(entity, holder)  # Default to dash
    
    # Start cooldown
    _start_cooldown(holder)
    
    # Notify systems
    holder.on_ability_executed(self)
    executed.emit(target_data)

func _execute_teleport(entity, holder) -> void:
    # Instant movement
    
    # Departure effect
    if departure_effect:
        var effect = departure_effect.instantiate()
        entity.get_parent().add_child(effect)
        effect.global_position = movement_start_pos
    
    # Play sound
    if movement_sound and AudioManager.instance:
        AudioManager.instance.play_sfx_on_node(movement_sound, entity, 0.0, 1.0)
    
    # Break targeting if configured
    if breaks_targeting:
        _break_enemy_targeting(entity)
    
    # Move entity
    entity.global_position = movement_target_pos
    
    # Arrival effect
    if arrival_effect:
        var effect = arrival_effect.instantiate()
        entity.get_parent().add_child(effect)
        effect.global_position = movement_target_pos
    
    # Deal damage if configured
    if deals_damage:
        _deal_arrival_damage(entity, holder, movement_target_pos)
    
    # Apply after effects
    _apply_after_effects(entity, holder)

func _start_dash(entity, holder) -> void:
    is_moving = true
    movement_progress = 0.0
    
    # Store original collision for pass-through
    if can_pass_through_enemies:
        original_collision_mask = entity.collision_mask
        entity.collision_mask = 0  # Disable collisions
    
    # Grant invulnerability
    if grants_invulnerability and entity.has_method("set_invulnerable"):
        entity.set_invulnerable(true)
    
    # Disable movement controller
    if entity.has_method("set_can_move"):
        entity.set_can_move(false)
    
    # Play sound
    if movement_sound and AudioManager.instance:
        AudioManager.instance.play_sfx_on_node(movement_sound, entity, 0.0, 1.0)
    
    # Create trail effect
    if trail_scene:
        _create_movement_trail(entity)

func _start_leap(entity, holder) -> void:
    # Similar to dash but with arc movement
    is_moving = true
    movement_progress = 0.0
    
    # Disable gravity temporarily
    if entity.has_property("gravity_scale"):
        entity.set_meta("original_gravity", entity.gravity_scale)
        entity.gravity_scale = 0
    
    # Rest similar to dash
    _start_dash(entity, holder)

func _start_charge(entity, holder) -> void:
    # Like dash but can be stopped by collision
    is_moving = true
    movement_progress = 0.0
    
    # Don't disable collisions for charge
    if grants_invulnerability and entity.has_method("set_invulnerable"):
        entity.set_invulnerable(true)
    
    # Rest similar to dash
    if entity.has_method("set_can_move"):
        entity.set_can_move(false)
    
    if movement_sound and AudioManager.instance:
        AudioManager.instance.play_sfx_on_node(movement_sound, entity, 0.0, 1.0)

func _update_movement(delta: float, holder) -> void:
    var entity = _get_entity(holder)
    if not entity:
        _end_movement(holder)
        return
    
    # Update progress
    movement_progress += delta / movement_duration
    
    if movement_progress >= 1.0:
        # Movement complete
        entity.global_position = movement_target_pos
        _end_movement(holder)
    else:
        # Update position
        var new_position = movement_start_pos.lerp(movement_target_pos, movement_progress)
        
        # Add arc for leap
        if movement_type == "leap":
            var arc_height = movement_distance * 0.5
            var arc_progress = sin(movement_progress * PI)
            new_position.y -= arc_height * arc_progress
        
        # Check collision for charge
        if movement_type == "charge" and stops_on_collision:
            if _check_charge_collision(entity, entity.global_position, new_position):
                _end_movement(holder)
                return
        
        # Deal damage along path if configured
        if deals_damage and movement_type != "teleport":
            _deal_path_damage(entity, holder, new_position)
        
        entity.global_position = new_position

func _end_movement(holder) -> void:
    is_moving = false
    movement_progress = 0.0
    
    var entity = _get_entity(holder)
    if not entity:
        return
    
    # Restore collision
    if can_pass_through_enemies and movement_type != "charge":
        entity.collision_mask = original_collision_mask
    
    # Remove invulnerability
    if grants_invulnerability and entity.has_method("set_invulnerable"):
        entity.set_invulnerable(false)
    
    # Re-enable movement
    if entity.has_method("set_can_move"):
        entity.set_can_move(true)
    
    # Restore gravity for leap
    if movement_type == "leap" and entity.has_meta("original_gravity"):
        entity.gravity_scale = entity.get_meta("original_gravity")
        entity.remove_meta("original_gravity")
    
    # Snap to ground if configured
    if snap_to_ground:
        _snap_to_ground(entity)
    
    # Impact effects
    if movement_type != "teleport":
        if arrival_effect:
            var effect = arrival_effect.instantiate()
            entity.get_parent().add_child(effect)
            effect.global_position = entity.global_position
        
        if impact_sound and AudioManager.instance:
            AudioManager.instance.play_sfx_on_node(impact_sound, entity, 0.0, 1.0)
    
    # Deal arrival damage
    if deals_damage and movement_type != "teleport":
        _deal_arrival_damage(entity, holder, entity.global_position)
    
    # Apply after effects
    _apply_after_effects(entity, holder)

func _create_movement_trail(entity) -> void:
    if not trail_scene:
        return
    
    # Create trail that follows entity during movement
    var trail = trail_scene.instantiate()
    entity.add_child(trail)
    
    if trail.has_method("setup"):
        trail.setup(movement_duration, entity)
    
    # Leave damaging trail if configured
    if leave_trail:
        _create_damaging_trail(entity)

func _create_damaging_trail(entity) -> void:
    # Implementation depends on your trail system
    # This would create Area2D nodes along the path that damage enemies
    pass

func _deal_path_damage(entity, holder, position: Vector2) -> void:
    # Find enemies near current position
    var targets = _get_targets_in_radius(entity, position, damage_radius)
    
    for target in targets:
        if target.has_method("take_damage"):
            target.take_damage(damage * 0.1, entity, ability_tags)  # Reduced damage per tick

func _deal_arrival_damage(entity, holder, position: Vector2) -> void:
    var targets = _get_targets_in_radius(entity, position, damage_radius)
    
    for target in targets:
        if target.has_method("take_damage"):
            var final_damage = get_modified_value(damage, "spell_power", holder)
            target.take_damage(final_damage, entity, ability_tags)
            
            # Knockback on charge
            if movement_type == "charge" and target.has_method("apply_knockback"):
                var knockback_dir = (target.global_position - entity.global_position).normalized()
                target.apply_knockback(knockback_dir * 300)

func _get_targets_in_radius(entity, position: Vector2, radius: float) -> Array:
    var targets = []
    var space_state = entity.get_world_2d().direct_space_state
    var query = PhysicsShapeQueryParameters2D.new()
    var circle = CircleShape2D.new()
    circle.radius = radius
    
    query.shape = circle
    query.transform = Transform2D(0, position)
    query.collision_mask = 2  # Enemy layer
    
    var results = space_state.intersect_shape(query)
    
    for result in results:
        var target = result.collider
        if target != entity and is_instance_valid(target):
            targets.append(target)
    
    return targets

func _apply_after_effects(entity, holder) -> void:
    # Apply speed boost
    if speed_boost_after > 0 and entity.has_method("apply_speed_boost"):
        entity.apply_speed_boost(speed_boost_after, speed_boost_duration)

func _validate_movement_path(entity, start_pos: Vector2, end_pos: Vector2) -> Vector2:
    # Raycast to check for valid path
    var space_state = entity.get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(start_pos, end_pos, 4)  # Terrain layer
    var result = space_state.intersect_ray(query)
    
    if result:
        # Hit terrain, adjust end position
        return result.position - (end_pos - start_pos).normalized() * 10
    
    return end_pos

func _check_charge_collision(entity, from: Vector2, to: Vector2) -> bool:
    # Check if charge hit something
    var space_state = entity.get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(from, to, 2 | 4)  # Enemy + Terrain
    var result = space_state.intersect_ray(query)
    
    return result != null

func _snap_to_ground(entity) -> void:
    # Raycast down to find ground
    var space_state = entity.get_world_2d().direct_space_state
    var query = PhysicsRayQueryParameters2D.create(
        entity.global_position,
        entity.global_position + Vector2.DOWN * 1000,
        4  # Terrain layer
    )
    var result = space_state.intersect_ray(query)
    
    if result:
        entity.global_position.y = result.position.y

func _break_enemy_targeting(entity) -> void:
    # Make all enemies targeting this entity lose their target
    for enemy in get_tree().get_nodes_in_group("enemies"):
        if enemy.has_method("get_target") and enemy.get_target() == entity:
            if enemy.has_method("clear_target"):
                enemy.clear_target()

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

# Override for range display
func get_range() -> float:
    return movement_distance
