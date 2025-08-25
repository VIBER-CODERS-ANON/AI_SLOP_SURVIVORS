extends BaseAbilityBehavior
class_name DashBehavior

## Dash ability behavior implementation
## Handles dash movement, visual effects, and temporary invulnerability

func execute(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Get the entity to dash
	var entity = _get_entity(entity_id)
	if not entity:
		print("❌ DashBehavior: Could not find entity with ID %d" % entity_id)
		return false
	
	# Get dash parameters from ability resource (use main properties first)
	var params = ability.additional_parameters
	var dash_distance = ability.ability_range  # Use main resource property
	var dash_duration = ability.duration  # Use main resource property
	var invuln_duration = params.get("invulnerability_duration", 0.2)
	var flash_color = params.get("visual_flash_color", Color(0.5, 0.5, 1.0, 0.7))
	var movement_type = params.get("movement_type", "physics")
	var stop_on_wall = params.get("stop_on_wall_collision", true)
	var shrink_collision = params.get("shrink_collision_during_dash", true)
	
	# Determine dash direction like old system (movement input priority)
	var dash_direction = Vector2.ZERO
	
	# Try to get current movement direction from movement controller
	var movement_dir = _get_movement_input(entity)
	if movement_dir.length() > 0.1:
		dash_direction = movement_dir
	# Otherwise, fallback to provided target direction if valid
	elif target_data.has("direction") and target_data.direction.length() > 0.1:
		dash_direction = target_data.direction
	# Finally, use entity facing direction or default right
	else:
		if entity.has_method("get_facing_direction"):
			dash_direction = entity.get_facing_direction()
		else:
			dash_direction = Vector2.RIGHT
	
	# Ensure normalized
	dash_direction = dash_direction.normalized()
	
	# Calculate target position
	var start_pos = entity.global_position
	var end_pos = start_pos + dash_direction.normalized() * dash_distance
	
	# Validate end position (basic bounds checking could be added here)
	
	# Setup collision handling if it's a CharacterBody2D
	if entity is CharacterBody2D:
		_setup_dash_collision(entity, stop_on_wall, shrink_collision)
	
	# Execute dash movement
	_execute_dash_movement(entity, start_pos, end_pos, dash_duration, movement_type)
	
	# Apply visual effects
	_apply_visual_effects(entity, flash_color, dash_duration)
	
	# Create ghost trail if physics movement
	if movement_type == "physics" and params.get("create_ghost_trail", true):
		_create_ghost_trail(entity, dash_duration, params.get("ghost_count", 5))
	
	# Create speed lines
	if params.get("create_speed_lines", true):
		_create_speed_lines(entity, dash_direction, params.get("speed_line_count", 8))
	
	# Apply temporary invulnerability (for player only)
	if entity_id == -1:
		_apply_invulnerability(entity, invuln_duration)
	
	# Play sound effect
	if ability.sound_effect:
		_play_sound_at(ability.sound_effect, pos)
	
	print("💨 Dash executed: %s distance=%.0f duration=%.2f" % [dash_direction, dash_distance, dash_duration])
	return true

# Physics-based dash state tracking
var active_dashes: Dictionary = {}  # entity -> dash_data

func _execute_physics_dash(entity: CharacterBody2D, start_pos: Vector2, end_pos: Vector2, duration: float):
	"""Execute physics-based dash movement with collision handling"""
	var dash_direction = (end_pos - start_pos).normalized()
	var dash_distance = start_pos.distance_to(end_pos)
	var dash_velocity = dash_direction * (dash_distance / duration) * 1.2  # Add push force
	
	# Store dash state
	var dash_data = {
		"velocity": dash_velocity,
		"original_velocity": dash_velocity,
		"time_remaining": duration,
		"start_pos": start_pos,
		"target_pos": end_pos,
		"stop_on_wall": entity.get_meta("dash_stop_on_wall", true)
	}
	active_dashes[entity] = dash_data
	
	# Start physics update loop
	_start_physics_update(entity)

func _start_physics_update(entity: CharacterBody2D):
	"""Start the physics update loop for this entity"""
	if not entity.has_meta("dash_update_timer"):
		var timer = Timer.new()
		timer.wait_time = 0.016  # ~60 FPS
		timer.timeout.connect(_update_dash_physics.bind(entity))
		entity.add_child(timer)
		entity.set_meta("dash_update_timer", timer)
		timer.start()

func _update_dash_physics(entity: CharacterBody2D):
	"""Update physics-based dash movement"""
	if not active_dashes.has(entity) or not is_instance_valid(entity):
		_end_physics_dash(entity)
		return
	
	var dash_data = active_dashes[entity]
	dash_data.time_remaining -= 0.016
	
	# Apply dash velocity
	entity.velocity = dash_data.velocity
	entity.move_and_slide()
	
	# Handle wall collisions
	if entity.get_slide_collision_count() > 0:
		var collision = entity.get_slide_collision(0)
		var collider = collision.get_collider()
		
		# Check if we hit a wall (assuming world collision layer exists)
		if dash_data.stop_on_wall and collider and "collision_layer" in collider:
			# Stop dash if hitting world geometry
			if _is_world_collision(collider):
				_end_physics_dash(entity)
				return
		
		# Otherwise slide along the surface
		var normal = collision.get_normal()
		dash_data.velocity = dash_data.velocity.slide(normal)
	
	# End dash when time expires
	if dash_data.time_remaining <= 0:
		_end_physics_dash(entity)

func _end_physics_dash(entity: CharacterBody2D):
	"""End physics-based dash and cleanup"""
	if active_dashes.has(entity):
		# Restore original velocity (usually zero)
		entity.velocity = Vector2.ZERO
		active_dashes.erase(entity)
	
	# Restore collision settings
	_restore_dash_collision(entity)
	
	# Cleanup timer
	if entity.has_meta("dash_update_timer"):
		var timer = entity.get_meta("dash_update_timer")
		if is_instance_valid(timer):
			timer.queue_free()
		entity.remove_meta("dash_update_timer")

func _setup_dash_collision(entity: CharacterBody2D, stop_on_wall: bool, shrink_collision: bool):
	"""Setup collision handling for dash"""
	# Store original collision settings
	if "collision_mask" in entity:
		entity.set_meta("original_collision_mask", entity.collision_mask)
	if "collision_layer" in entity:
		entity.set_meta("original_collision_layer", entity.collision_layer)
	entity.set_meta("dash_stop_on_wall", stop_on_wall)
	
	# Modify collision during dash
	if stop_on_wall:
		# Keep world collisions but ignore enemies/projectiles
		if "collision_mask" in entity:
			# Assume layer 1 is WORLD, 2 is PICKUPS (adjust as needed)
			entity.collision_mask = 1 | 4  # WORLD + PICKUPS
	else:
		# Allow passing through most things
		if "collision_mask" in entity:
			entity.collision_mask = 4  # Only PICKUPS
	
	# Shrink collision shape if requested
	if shrink_collision:
		_shrink_collision_shape(entity)

func _restore_dash_collision(entity: CharacterBody2D):
	"""Restore original collision settings"""
	if entity.has_meta("original_collision_mask"):
		entity.collision_mask = entity.get_meta("original_collision_mask")
		entity.remove_meta("original_collision_mask")
	
	if entity.has_meta("original_collision_layer"):
		entity.collision_layer = entity.get_meta("original_collision_layer")
		entity.remove_meta("original_collision_layer")
	
	_restore_collision_shape(entity)
	
	if entity.has_meta("dash_stop_on_wall"):
		entity.remove_meta("dash_stop_on_wall")

func _shrink_collision_shape(entity: Node):
	"""Shrink collision shape during dash"""
	var collision_shape = entity.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape2D:
			collision_shape.set_meta("original_radius", collision_shape.shape.radius)
			collision_shape.set_meta("original_height", collision_shape.shape.height)
			collision_shape.shape.radius *= 0.8
			collision_shape.shape.height *= 0.9
		elif collision_shape.shape is CircleShape2D:
			collision_shape.set_meta("original_radius", collision_shape.shape.radius)
			collision_shape.shape.radius *= 0.8

func _restore_collision_shape(entity: Node):
	"""Restore original collision shape"""
	var collision_shape = entity.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape2D:
			if collision_shape.has_meta("original_radius"):
				collision_shape.shape.radius = collision_shape.get_meta("original_radius")
				collision_shape.remove_meta("original_radius")
			if collision_shape.has_meta("original_height"):
				collision_shape.shape.height = collision_shape.get_meta("original_height")
				collision_shape.remove_meta("original_height")
		elif collision_shape.shape is CircleShape2D:
			if collision_shape.has_meta("original_radius"):
				collision_shape.shape.radius = collision_shape.get_meta("original_radius")
				collision_shape.remove_meta("original_radius")

func _is_world_collision(collider: Node) -> bool:
	"""Check if collider is world geometry"""
	# This is a simplified check - adjust based on your layer setup
	return "collision_layer" in collider and (int(collider.collision_layer) & 1) != 0

func _execute_dash_movement(entity: Node, start_pos: Vector2, end_pos: Vector2, duration: float, movement_type: String):
	"""Execute the actual movement based on movement type"""
	match movement_type:
		"teleport":
			# Instant teleport
			entity.global_position = end_pos
		"physics":
			# Physics-based movement like old system
			if entity is CharacterBody2D:
				_execute_physics_dash(entity, start_pos, end_pos, duration)
			else:
				# Fallback to tween for non-physics entities
				var tween = entity.create_tween()
				tween.tween_property(entity, "global_position", end_pos, duration)
		"tween":
			# Smooth movement via tween
			var tween = entity.create_tween()
			tween.tween_property(entity, "global_position", end_pos, duration)
		_:
			# Default to physics for CharacterBody2D, tween otherwise
			if entity is CharacterBody2D:
				_execute_physics_dash(entity, start_pos, end_pos, duration)
			else:
				var tween = entity.create_tween()
				tween.tween_property(entity, "global_position", end_pos, duration)

func _apply_visual_effects(entity: Node, flash_color: Color, duration: float):
	"""Apply visual feedback effects"""
	if not entity.has_method("set_modulate") and not "modulate" in entity:
		return
	
	# Flash effect
	entity.modulate = flash_color
	
	# Restore normal color after duration
	var restore_tween = entity.create_tween()
	restore_tween.tween_property(entity, "modulate", Color.WHITE, duration * 0.3).set_delay(duration * 0.5)
	
	# Create particle effects
	_create_dash_particles(entity)

func _create_dash_particles(entity: Node):
	"""Create dash particle effect like the old system"""
	# Create burst particles at dash start
	_create_dash_burst_particles(entity)

func _create_dash_burst_particles(entity: Node):
	"""Create burst particles at dash start like the old system"""
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.speed_scale = 2.0
	
	# Emission shape
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.spread = 45.0
	
	# Movement
	particles.initial_velocity_min = 150.0
	particles.initial_velocity_max = 300.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.damping_min = 50.0
	particles.damping_max = 100.0
	
	# Size
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	
	# Color gradient like old system
	var gradient = Gradient.new()
	var trail_color = Color(0.5, 0.8, 1.0, 0.6)
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.5, trail_color)
	gradient.add_point(1.0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	particles.color_ramp = gradient
	
	particles.global_position = entity.global_position
	particles.z_index = (entity.z_index + 1) if "z_index" in entity else 1
	
	var scene_root = entity.get_tree().current_scene
	if scene_root:
		scene_root.add_child(particles)
		
		# Auto cleanup
		var cleanup_timer = Timer.new()
		cleanup_timer.wait_time = 1.0
		cleanup_timer.one_shot = true
		cleanup_timer.timeout.connect(func(): 
			if is_instance_valid(particles):
				particles.queue_free()
			cleanup_timer.queue_free()
		)
		scene_root.add_child(cleanup_timer)
		cleanup_timer.start()

func _apply_invulnerability(entity: Node, duration: float):
	"""Apply temporary invulnerability"""
	if not entity.has_method("set_invulnerable"):
		return
	
	entity.set_invulnerable(true)
	
	# Create timer to remove invulnerability
	var invuln_timer = Timer.new()
	invuln_timer.wait_time = duration
	invuln_timer.one_shot = true
	invuln_timer.timeout.connect(func(): 
		if is_instance_valid(entity) and entity.has_method("set_invulnerable"):
			entity.set_invulnerable(false)
			print("🛡️ Dash invulnerability ended")
		invuln_timer.queue_free()
	)
	entity.add_child(invuln_timer)
	invuln_timer.start()
	
	print("🛡️ Dash invulnerability applied for %.1fs" % duration)

func _create_ghost_trail(entity: Node, duration: float, ghost_count: int):
	"""Create ghost trail effect like the old system"""
	if ghost_count <= 0:
		return
	
	var trail_interval = duration / ghost_count
	var ghosts_created = 0
	
	# Create timer for ghost creation
	var ghost_timer = Timer.new()
	ghost_timer.wait_time = trail_interval
	ghost_timer.timeout.connect(func():
		if ghosts_created < ghost_count and is_instance_valid(entity):
			_create_single_ghost(entity)
			ghosts_created += 1
		else:
			ghost_timer.queue_free()
	)
	
	entity.add_child(ghost_timer)
	ghost_timer.start()
	
	# Cleanup timer after dash duration
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = duration + 0.1
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(ghost_timer):
			ghost_timer.queue_free()
		cleanup_timer.queue_free()
	)
	entity.add_child(cleanup_timer)
	cleanup_timer.start()

func _create_single_ghost(entity: Node):
	"""Create a single ghost sprite"""
	if not is_instance_valid(entity):
		return
	
	var ghost = Sprite2D.new()
	ghost.z_index = (entity.z_index - 1) if "z_index" in entity else -1
	
	# Try to copy sprite texture from entity
	var texture = _get_entity_texture(entity)
	if texture:
		ghost.texture = texture
		
		# Copy sprite properties if available
		var sprite = _get_entity_sprite(entity)
		if sprite:
			ghost.flip_h = sprite.flip_h if "flip_h" in sprite else false
			ghost.scale = sprite.scale * entity.scale if "scale" in entity else sprite.scale
	else:
		# Fallback: create a simple colored rectangle
		var rect = ColorRect.new()
		rect.size = Vector2(16, 16)  # Default size
		rect.color = Color(0.5, 0.8, 1.0, 0.6)
		rect.pivot_offset = rect.size / 2
		ghost = rect
	
	ghost.global_position = entity.global_position
	ghost.modulate = Color(0.5, 0.8, 1.0, 0.6)  # Blue ghost color
	
	# Add to scene
	var scene_root = entity.get_tree().current_scene
	if scene_root:
		scene_root.add_child(ghost)
		
		# Fade out and remove
		var tween = ghost.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.4)
		tween.tween_property(ghost, "scale", ghost.scale * 0.8, 0.4)
		tween.tween_callback(ghost.queue_free).set_delay(0.4)

func _get_entity_texture(entity: Node) -> Texture2D:
	"""Get texture from entity sprite"""
	var sprite = _get_entity_sprite(entity)
	if sprite:
		if sprite is AnimatedSprite2D and sprite.sprite_frames:
			return sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		elif sprite is Sprite2D:
			return sprite.texture
	return null

func _get_entity_sprite(entity: Node) -> Node:
	"""Find sprite node in entity hierarchy"""
	# Common sprite locations
	var sprite_paths = [
		"SpriteContainer/Sprite",
		"Sprite", 
		"AnimatedSprite2D",
		"Sprite2D"
	]
	
	for path in sprite_paths:
		var sprite = entity.get_node_or_null(path)
		if sprite:
			return sprite
	
	# Search children recursively
	for child in entity.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	
	return null

func _create_speed_lines(entity: Node, direction: Vector2, line_count: int):
	"""Create speed lines effect like the old system"""
	if line_count <= 0:
		return
	
	var trail_color = Color(0.5, 0.8, 1.0, 0.6)  # Blue trail color
	var entity_pos = entity.global_position
	
	for i in range(line_count):
		var line = Line2D.new()
		line.width = randf_range(1.0, 3.0)
		line.default_color = Color(trail_color.r, trail_color.g, trail_color.b, randf_range(0.2, 0.4))
		line.z_index = (entity.z_index - 2) if "z_index" in entity else -2
		
		# Create perpendicular offset for variety
		var perpendicular = Vector2(-direction.y, direction.x)
		var offset = perpendicular * randf_range(-40, 40)
		
		# Line positions relative to entity
		var line_start = offset - direction * 20
		var line_end = offset - direction * randf_range(80, 120)
		
		line.add_point(line_start)
		line.add_point(line_end)
		
		line.global_position = entity_pos
		
		# Add to scene
		var scene_root = entity.get_tree().current_scene
		if scene_root:
			scene_root.add_child(line)
			
			# Animate and remove
			var tween = line.create_tween()
			tween.set_parallel(true)
			tween.tween_property(line, "modulate:a", 0.0, 0.25)
			tween.tween_property(line, "scale", Vector2(1.5, 0.5), 0.25)
			tween.tween_callback(line.queue_free).set_delay(0.25)

func _get_movement_input(entity: Node) -> Vector2:
	"""Get current movement input from movement controller like old system"""
	# Try to find movement controller
	var movement_controller = entity.get_node_or_null("PlayerMovementController")
	if not movement_controller:
		movement_controller = entity.get_node_or_null("MovementController")
	
	var movement_dir = Vector2.ZERO
	if movement_controller and movement_controller.has_method("get_direction"):
		movement_dir = movement_controller.get_direction()
	
	return movement_dir
