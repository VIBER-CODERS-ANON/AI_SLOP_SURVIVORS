extends BaseCreature
class_name HorseEnemy

## Horse - Fast charging enemy spawned by HORSEN
## Performs a single charge attack then despawns

# Horse specific properties
@export var charge_damage: float = 50.0
@export var charge_speed: float = 400.0  # Speed during charge
@export var charge_prep_time: float = 1.0  # Lock-on time before charge
@export var charge_distance: float = 1400.0  # How far to charge past target (long telegraph line)

# State
var is_preparing_charge: bool = false
var is_charging: bool = false
var charge_target: Node2D = null
var charge_direction: Vector2 = Vector2.ZERO
var charge_end_position: Vector2 = Vector2.ZERO
var has_charged: bool = false
var charge_timer: float = 0.0
var has_dealt_damage: bool = false

# Visual
var charge_line: Line2D

func _entity_ready():
	super._entity_ready()
	_setup_horse()
	_play_spawn_animation()

func _setup_horse():
	# REQUIRED: Core properties
	creature_type = "Horse"
	base_scale = 1.2
	abilities = []  # No special abilities, just charge attack
	
	# REQUIRED: Stats
	max_health = 100.0
	current_health = max_health
	move_speed = 200.0  # Normal movement speed
	damage = charge_damage
	attack_range = 1000.0  # Long range to initiate charge
	attack_cooldown = 999.0  # Only charges once
	attack_type = AttackType.RANGED  # Uses ranged AI to maintain distance before charge
	preferred_attack_distance = 300.0  # Ideal distance to start charge
	
	# REQUIRED: Tags
	if taggable:
		taggable.add_tag("Enemy")
		taggable.add_tag("Horse")
		taggable.add_tag("Summon")
		taggable.add_tag("Charger")
		taggable.add_tag("Lesser")
	
	# REQUIRED: Groups
	add_to_group("enemies")
	add_to_group("ai_controlled")
	add_to_group("horses")

	# AI always targets player now - no configuration needed
	
	# Set up sprite
	_setup_sprite()

	# Immediately begin telegraphed charge on spawn
	call_deferred("_start_charge_preparation")

func _setup_sprite():
	# Get the AnimatedSprite2D node
	sprite = get_node_or_null("AnimatedSprite2D")
	if not sprite:
		return
		
	# Ensure crisp sampling and no frame bleeding
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED

	# Create sprite frames programmatically for 6-frame spritesheet
	var frames = SpriteFrames.new()
	var texture = load("res://BespokeAssetSources/forsen/HorseHorseSprite6Frames.png")
	
	if not texture:
		push_error("Failed to load horse spritesheet!")
		return
	
	# Add run animation with all frames (6)
	frames.add_animation("run")
	frames.set_animation_speed("run", 18.0)  # tuned for a crisp gallop with 6 frames
	frames.set_animation_loop("run", true)
	
	# Compute frame dimensions from spritesheet (6 columns)
	var frames_count := 6
	var frame_width: int = int(floor(texture.get_width() / float(frames_count)))
	var frame_height: int = texture.get_height()
	
	# Add all frames
	for i in range(frames_count):
		var atlas_texture = AtlasTexture.new()
		atlas_texture.atlas = texture
		atlas_texture.region = Rect2i(i * frame_width, 0, frame_width, frame_height)
		atlas_texture.filter_clip = true
		frames.add_frame("run", atlas_texture)
	
	# Apply frames and start animation
	sprite.sprite_frames = frames
	sprite.play("run")
	
	# Adjust scale - new sheet is smaller; use 0.5 for clarity
	sprite.scale = Vector2(0.5, 0.5)

func _entity_physics_process(delta):
	# Update sprite direction based on movement
	if sprite and velocity.x != 0 and not is_preparing_charge:
		sprite.flip_h = velocity.x > 0  # Flip when moving right (inverted because base sprite is flipped)
	
	# Handle charge states
	if is_preparing_charge:
		_handle_charge_preparation(delta)
	elif is_charging:
		_handle_charging(delta)
	elif not has_charged:
		# Do not run to the player; just start (or keep) the prep
		if not is_preparing_charge:
			if not charge_target:
				charge_target = _find_player()
			_start_charge_preparation()
	else:
		# After charging, move off screen to despawn
		_handle_despawn_movement(delta)

# Disable base auto-attack; horses only deal damage via charge collision
func _perform_attack():
	return

func set_charge_target(target: Node2D):
	charge_target = target

func _start_charge_preparation():
	if has_charged or is_preparing_charge or is_charging:
		return
	
	is_preparing_charge = true
	charge_timer = 0.0
	move_speed = 0  # Stop moving
	has_dealt_damage = false
	
	# Create charge telegraph line
	_create_charge_telegraph()
	
	# Visual feedback - horse rears up and slows animation
	if sprite:
		# Slow down animation during preparation
		if sprite is AnimatedSprite2D:
			sprite.speed_scale = 0.3  # Slow motion effect
		
		var tween = create_tween()
		tween.tween_property(sprite, "scale:y", sprite.scale.y * 1.3, 0.3)
		tween.tween_property(sprite, "scale:y", sprite.scale.y, 0.2)

func _handle_charge_preparation(delta):
	charge_timer += delta
	
	# Update charge direction to track player
	if charge_target and is_instance_valid(charge_target):
		var to_target = charge_target.global_position - global_position
		charge_direction = to_target.normalized()
		
		# Update telegraph line
		if charge_line:
			charge_line.points[1] = charge_direction * charge_distance
	
	# Start charge after prep time
	if charge_timer >= charge_prep_time:
		_execute_charge()

func _execute_charge():
	is_preparing_charge = false
	is_charging = true
	has_charged = true
	
	# Calculate charge end position (through and past the target)
	# Lock the end position from the prep phase to avoid immediate hit on spawn
	if charge_end_position == Vector2.ZERO:
		charge_end_position = global_position + charge_direction * charge_distance
	
	# Remove telegraph
	if charge_line:
		charge_line.queue_free()
		charge_line = null
	
	# Restore animation speed for the charge
	if sprite and sprite is AnimatedSprite2D:
		sprite.speed_scale = 2.0  # Fast charge animation

	# Safety despawn after charge completes (fallback)
	var despawn_timer := get_tree().create_timer(2.0)
	despawn_timer.timeout.connect(func():
		if is_instance_valid(self):
			_despawn()
	)
	
	# Sound effect
	_play_charge_sound()
	
	# Action feed
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message("🐴 Horse charges!", Color(0.8, 0.4, 0))

func _handle_charging(_delta):
	# Move in charge direction at high speed
	velocity = charge_direction * charge_speed
	move_and_slide()
	
	# Update sprite direction during charge
	if sprite and charge_direction.x != 0:
		sprite.flip_h = charge_direction.x > 0  # Flip when charging right (inverted because base sprite is flipped)
	
	# Check if we've reached the end position
	var distance_to_end = global_position.distance_to(charge_end_position)
	if distance_to_end < 10:
		is_charging = false
		# Start moving off screen
		_start_despawn_movement()
	
	# Deal damage to anything we hit
	_check_charge_collision()

func _check_charge_collision():
	# Check for player collision during charge
	var player = _find_player()
	if player and player.has_method("take_damage") and not has_dealt_damage and is_charging:
		var distance = global_position.distance_to(player.global_position)
		if distance < 40:  # Hit radius
			has_dealt_damage = true
			player.take_damage(charge_damage, self, ["Physical", "Charge"])
			
			# Apply knockback
			if player.has_method("apply_knockback"):
				player.apply_knockback(charge_direction, 500)

			# Begin despawn movement after hit
			_start_despawn_movement()

func _handle_despawn_movement(_delta):
	# Continue moving in charge direction to go off screen
	velocity = charge_direction * move_speed
	move_and_slide()
	
	# Check if we're far enough off screen
	var viewport_rect = get_viewport_rect()
	var screen_position = get_global_transform_with_canvas().origin
	
	if not viewport_rect.has_point(screen_position):
		# We're off screen, despawn
		_despawn()

func _start_despawn_movement():
	# Set a direction to move off screen if not already moving
	if charge_direction == Vector2.ZERO:
		# Pick a random direction
		var angle = randf() * TAU
		charge_direction = Vector2(cos(angle), sin(angle))
	
	move_speed = 200.0  # Normal speed for leaving

func _despawn():
	# Play despawn animation before removing
	_play_despawn_animation()

func _create_charge_telegraph():
	# Telegraph line removed for immersion - keeping function for charge mechanics
	pass

var sfx_player: AudioStreamPlayer2D

func _play_charge_sound():
	# Ensure audio player exists
	if not sfx_player:
		sfx_player = AudioStreamPlayer2D.new()
		add_child(sfx_player)
	
	# Pick a random horse SFX from res://audio/horses
	var files = _list_audio_files_in("res://audio/horses")
	if files.is_empty():
		return
	
	var path = files[randi() % files.size()]
	var stream = load(path)
	if stream:
		sfx_player.stream = stream
		sfx_player.volume_db = -2.0
		sfx_player.play()

func _list_audio_files_in(dir_path: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var lower := file_name.to_lower()
				if lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav"):
					files.append(dir_path + "/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

func die():
	# Award reduced XP since it's a summon
	_spawn_xp_orb(2)
	super.die()

func _spawn_xp_orb(value: int):
	var xp_orb_scene = preload("res://entities/pickups/xp_orb.tscn")
	if xp_orb_scene:
		var orb = xp_orb_scene.instantiate()
		orb.xp_value = value
		orb.global_position = global_position
		get_parent().call_deferred("add_child", orb)

func get_killer_display_name() -> String:
	return "Horse"

func get_attack_name() -> String:
	return "charge"

func get_action_feed():
	var game = get_tree().get_first_node_in_group("game_controller")
	if game and game.has_method("get_action_feed"):
		return game.get_action_feed()
	return null

func _play_spawn_animation():
	# Create portal effect for spawn
	_create_portal_effect(true)
	
	# Start horse invisible and fade in
	if sprite:
		sprite.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 1.0, 0.8)
	
	# Scale up from center
	scale = Vector2(0.1, 0.1)
	var scale_tween = create_tween()
	scale_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _play_despawn_animation():
	# Stop movement during despawn
	velocity = Vector2.ZERO
	move_speed = 0
	
	# Create portal effect for despawn
	_create_portal_effect(false)
	
	# Fade out and scale down
	if sprite:
		var tween = create_tween()
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.6)
		tween.parallel().tween_property(self, "scale", Vector2(0.1, 0.1), 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(queue_free)
	else:
		# Fallback if no sprite
		var tween = create_tween()
		tween.tween_property(self, "scale", Vector2(0.1, 0.1), 0.6)
		tween.tween_callback(queue_free)

func _create_portal_effect(is_spawn: bool):
	# Create a swirling void portal effect using particles and visuals
	
	# Portal circle backdrop
	var portal_bg = Node2D.new()
	add_child(portal_bg)
	portal_bg.z_index = -1
	
	# Create multiple animated circles for portal effect using Line2D
	for i in range(3):
		var circle = Line2D.new()
		portal_bg.add_child(circle)
		
		# Create circle points
		var radius = 40.0 + i * 15.0
		var point_count = 32
		for j in range(point_count + 1):
			var angle = (j / float(point_count)) * TAU
			var point = Vector2(cos(angle), sin(angle)) * radius
			circle.add_point(point)
		
		# Style the circle
		circle.width = 3.0
		circle.default_color = Color(0.5, 0.1, 0.6, 0.6 - i * 0.2)
		circle.closed = true
		
		# Spin animation
		var spin_tween = create_tween()
		spin_tween.set_loops(3)
		spin_tween.tween_property(circle, "rotation", TAU * (1 if i % 2 == 0 else -1), 0.5)
	
	# Create particle burst effect
	var particles = CPUParticles2D.new()
	add_child(particles)
	particles.z_index = 50
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.preprocess = 0.0
	particles.speed_scale = 1.5
	
	# Particle properties
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 150.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	
	# Portal colors (purple/red hellish theme)
	particles.color = Color(0.8, 0.2, 0.9, 1.0)
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.9, 0.1, 0.5, 1.0))
	gradient.set_color(1, Color(0.3, 0.0, 0.4, 0.0))
	particles.color_ramp = gradient
	
	if is_spawn:
		particles.direction = Vector2(0, -1)  # Upward burst for spawn
	else:
		particles.direction = Vector2(0, 0)  # Inward collapse for despawn
		particles.initial_velocity_min = -150.0
		particles.initial_velocity_max = -50.0
	
	# Clean up portal effect after animation
	var cleanup_timer = get_tree().create_timer(1.5)
	cleanup_timer.timeout.connect(func():
		if is_instance_valid(portal_bg):
			portal_bg.queue_free()
		if is_instance_valid(particles):
			particles.queue_free()
	)
