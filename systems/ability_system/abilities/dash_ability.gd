class_name DashAbility
extends BaseAbility

# Dash-specific properties
var base_dash_distance: float = 150.0
var dash_duration: float = 0.2
var dash_push_force: float = 1.2  # Extra force to push through tight spaces
var base_iframe_duration: float = 0.0  # No i-frames by default
var remove_collision_during_dash: bool = true
var leave_trail: bool = true
var trail_ghost_count: int = 5

# Visual effects
var dash_start_particles: bool = true
var dash_speed_lines: bool = true
var trail_color: Color = Color(0.5, 0.8, 1.0, 0.6)  # Blue tint

# Internal state
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO
var dash_time_remaining: float = 0.0
var original_collision_mask: int = 0
var original_collision_layer: int = 0
var entity_node = null  # CharacterBody2D

# Collision behavior
var stop_on_wall_collision: bool = true

func _init() -> void:
	# Set base properties
	ability_id = "dash"
	ability_name = "Dash"
	ability_description = "Quickly dash in your current movement direction"
	ability_tags = ["Movement", "Utility"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = 5.0
	resource_costs = {}  # Free to use
	
	# Targeting
	targeting_type = 4  # DIRECTION
	base_range = 0.0  # Self-cast

func can_execute(holder, target_data) -> bool:
	if is_dashing:
		return false
	if holder.has_method("can_move") and not holder.can_move():
		return false
	return super.can_execute(holder, target_data)

func on_added(holder) -> void:
	super.on_added(holder)
	entity_node = holder.get_entity_node()
	if entity_node:
		if "collision_mask" in entity_node:
			original_collision_mask = entity_node.collision_mask
		if "collision_layer" in entity_node:
			original_collision_layer = entity_node.collision_layer
	# DashAbility connected to entity

func _execute_ability(holder, target_data) -> void:
	entity_node = holder.get_entity_node()
	if not entity_node:
		push_error("DashAbility: No entity node found!")
		return
	
	# Get dash direction from movement controller
	var movement_controller = entity_node.get_node_or_null("PlayerMovementController")
	if not movement_controller:
		movement_controller = entity_node.get_node_or_null("MovementController")
	
	var dash_direction = Vector2.ZERO
	var movement_dir = Vector2.ZERO
	if movement_controller and movement_controller.has_method("get_direction"):
		movement_dir = movement_controller.get_direction()
	
	# Prefer current movement direction first
	if movement_dir.length() > 0.1:
		dash_direction = movement_dir
	# Otherwise, fallback to provided target direction if valid
	elif target_data and "target_direction" in target_data and target_data.target_direction.length() > 0.1:
		dash_direction = target_data.target_direction
	# Finally, use facing direction
	else:
		dash_direction = holder.get_facing_direction()
	
	# Ensure normalized
	dash_direction = dash_direction.normalized()
	
	# Calculate dash parameters
	var actual_distance = base_dash_distance
	var actual_duration = dash_duration
	var actual_iframes = base_iframe_duration
	
	# Start dash
	is_dashing = true
	dash_time_remaining = actual_duration
	dash_velocity = dash_direction.normalized() * (actual_distance / actual_duration) * dash_push_force
	
	# Modify collision if needed
	if entity_node:
		# If we want to stop on walls, keep WORLD collisions during dash
		if stop_on_wall_collision:
			if "collision_mask" in entity_node:
				original_collision_mask = entity_node.collision_mask
				# Collide with WORLD and PICKUPS during dash (ignore enemies/projectiles)
				entity_node.collision_mask = GameConfig.CollisionLayer.WORLD | GameConfig.CollisionLayer.PICKUPS
			if "collision_layer" in entity_node:
				original_collision_layer = entity_node.collision_layer
				# Keep our original layer so collisions are detected symmetrically
				entity_node.collision_layer = original_collision_layer
			_shrink_collision_shape()
		# Otherwise preserve old behavior: disable most collisions to slide through
		elif remove_collision_during_dash:
			if "collision_mask" in entity_node:
				original_collision_mask = entity_node.collision_mask
				# During dash, only keep collision with selected layers (projectiles/pickups)
				entity_node.collision_mask = (1 << 2) | (1 << 3)
			if "collision_layer" in entity_node:
				original_collision_layer = entity_node.collision_layer
				entity_node.collision_layer = 0
			_shrink_collision_shape()
	
	# Apply i-frames if any
	if actual_iframes > 0 and entity_node.has_method("set_invulnerable"):
		entity_node.set_invulnerable(true)
		# Schedule removal of i-frames
		entity_node.get_tree().create_timer(actual_iframes).timeout.connect(
			func(): 
				if entity_node and entity_node.has_method("set_invulnerable"):
					entity_node.set_invulnerable(false)
		)
	
	# Create visual effects
	if dash_start_particles:
		_create_dash_burst_particles(holder)
	
	if dash_speed_lines:
		_create_speed_lines(holder, dash_direction)
	
	if leave_trail:
		_create_dash_trail(holder, actual_duration)
	
	# No dash animation available currently
	
	# Camera shake removed per user request
	
	# Start cooldown
	_start_cooldown(holder)
	
	# Notify holder
	holder.on_ability_executed(self)
	executed.emit(target_data)

func update(delta: float, holder) -> void:
	super.update(delta, holder)
	
	# Update dash state
	if is_dashing and entity_node:
		dash_time_remaining -= delta
		
		# Apply dash velocity
		entity_node.velocity = dash_velocity
		entity_node.move_and_slide()
		
		# Handle wall sliding
		if entity_node.get_slide_collision_count() > 0:
			var collision = entity_node.get_slide_collision(0)
			# If configured, stop dash when colliding with WORLD
			if stop_on_wall_collision:
				var collider = collision.get_collider()
				if collider and "collision_layer" in collider:
					if int(collider.collision_layer) & GameConfig.CollisionLayer.WORLD != 0:
						_end_dash()
						return
			# Otherwise, slide along the collision normal
			var normal = collision.get_normal()
			var slide_velocity = dash_velocity.slide(normal)
			entity_node.velocity = slide_velocity
			entity_node.move_and_slide()
		
		# End dash if time is up
		if dash_time_remaining <= 0:
			_end_dash()

func _end_dash() -> void:
	is_dashing = false
	dash_velocity = Vector2.ZERO
	dash_time_remaining = 0
	
	# Restore collision
	if entity_node:
		if "collision_mask" in entity_node:
			entity_node.collision_mask = original_collision_mask
		if "collision_layer" in entity_node:
			entity_node.collision_layer = original_collision_layer
		_restore_collision_shape()

func _shrink_collision_shape() -> void:
	if not entity_node:
		return
		
	var collision_shape = entity_node.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape2D:
			collision_shape.set_meta("original_radius", collision_shape.shape.radius)
			collision_shape.set_meta("original_height", collision_shape.shape.height)
			collision_shape.shape.radius *= 0.8
			collision_shape.shape.height *= 0.9
		elif collision_shape.shape is CircleShape2D:
			collision_shape.set_meta("original_radius", collision_shape.shape.radius)
			collision_shape.shape.radius *= 0.8

func _restore_collision_shape() -> void:
	if not entity_node:
		return
		
	var collision_shape = entity_node.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CapsuleShape2D:
			collision_shape.shape.radius = collision_shape.get_meta("original_radius", 16.0)
			collision_shape.shape.height = collision_shape.get_meta("original_height", 60.0)
		elif collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = collision_shape.get_meta("original_radius", 16.0)

func _create_dash_burst_particles(holder) -> void:
	if not entity_node:
		return
		
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
	
	# Color gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.add_point(0.5, trail_color)
	gradient.add_point(1.0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	particles.color_ramp = gradient
	
	particles.global_position = holder.get_global_position()
	particles.z_index = (entity_node.z_index + 1) if entity_node else 0
	
	var scene_root = entity_node.get_tree().current_scene
	if not scene_root:
		particles.queue_free()
		return
		
	scene_root.add_child(particles)
	
	# Use a timer instead of await for cleanup
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 1.0
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(func(): particles.queue_free())
	scene_root.add_child(cleanup_timer)
	cleanup_timer.start()

func _create_speed_lines(holder, direction: Vector2) -> void:
	for i in range(8):
		var line = Line2D.new()
		line.width = randf_range(1.0, 3.0)
		line.default_color = Color(trail_color.r, trail_color.g, trail_color.b, randf_range(0.2, 0.4))
		line.z_index = (entity_node.z_index - 2) if entity_node else -2
		
		var perpendicular = Vector2(-direction.y, direction.x)
		var offset = perpendicular * randf_range(-40, 40)
		
		var line_start = offset - direction * 20
		var line_end = offset - direction * randf_range(80, 120)
		
		line.add_point(line_start)
		line.add_point(line_end)
		
		line.global_position = holder.get_global_position()
		
		var scene_root = entity_node.get_tree().current_scene
		scene_root.add_child(line)
		
		# Animate and remove
		var tween = line.create_tween()
		tween.set_parallel()
		tween.tween_property(line, "modulate:a", 0.0, 0.25)
		tween.tween_property(line, "scale", Vector2(1.5, 0.5), 0.25)
		tween.chain().tween_callback(line.queue_free)

func _create_dash_trail(holder, duration: float) -> void:
	if not entity_node:
		return
		
	var trail_interval = duration / trail_ghost_count
	var timer = Timer.new()
	timer.wait_time = trail_interval
	timer.timeout.connect(func(): _create_single_ghost(holder))
	
	entity_node.add_child(timer)
	timer.start()
	
	# Stop and remove timer when dash ends
	await entity_node.get_tree().create_timer(duration).timeout
	timer.queue_free()

func _create_single_ghost(_holder) -> void:
	if not entity_node:
		return
		
	var ghost = Sprite2D.new()
	ghost.z_index = entity_node.z_index - 1
	
	# Copy sprite texture
	var sprite_container = entity_node.get_node_or_null("SpriteContainer")
	if sprite_container:
		var sprite = sprite_container.get_node_or_null("Sprite")
		if sprite and sprite is AnimatedSprite2D:
			ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
			ghost.flip_h = sprite.flip_h
			ghost.scale = sprite.scale * entity_node.scale
	
	ghost.global_position = entity_node.global_position
	ghost.modulate = trail_color
	
	entity_node.get_tree().current_scene.add_child(ghost)
	
	# Fade out and remove
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.4)
	tween.tween_property(ghost, "scale", ghost.scale * 0.8, 0.4)
	tween.tween_callback(ghost.queue_free)
