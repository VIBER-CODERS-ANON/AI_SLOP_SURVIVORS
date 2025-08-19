extends Node2D
class_name BossSpawnEffect

## Default boss spawn effect with particles and dramatic visuals
## Can be overridden per boss for custom effects

signal spawn_complete

# Configuration
@export var effect_duration: float = 2.0
@export var portal_color: Color = Color(0.8, 0.2, 1.0)
@export var particle_color: Color = Color(1.0, 0.5, 0.0)
@export var use_lightning: bool = true
@export var use_shockwave: bool = true
@export var use_portal: bool = true

var time_elapsed: float = 0.0
var portal_radius: float = 0.0
var max_portal_radius: float = 100.0

func _ready():
	# Ensure effect pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	z_index = 15  # Draw above most things but below UI
	
	# Start the effect
	_start_spawn_effect()

func _start_spawn_effect():
	# Play spawn sound
	if AudioManager.instance:
		AudioManager.instance.play_sfx(
			preload("res://audio/sfx_Epic__20250811_111128.mp3"),
			global_position,
			0,  # Normal volume
			0.8   # Slightly lower pitch for drama
		)
	
	# Create portal particles
	if use_portal:
		_create_portal_particles()
	
	# Create lightning strikes
	if use_lightning:
		_create_lightning_effects()
	
	# Create ground shockwave
	if use_shockwave:
		_create_shockwave()

func _create_portal_particles():
	# Inner swirling particles
	var inner_particles = CPUParticles2D.new()
	inner_particles.amount = 100
	inner_particles.lifetime = 1.5
	inner_particles.emitting = true
	# Use sphere shape instead of ring (ring not available in CPUParticles2D)
	inner_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	inner_particles.emission_sphere_radius = 50.0
	inner_particles.spread = 0.0
	inner_particles.initial_velocity_min = 100.0
	inner_particles.initial_velocity_max = 150.0
	inner_particles.angular_velocity_min = -360.0
	inner_particles.angular_velocity_max = -180.0
	inner_particles.gravity = Vector2.ZERO
	inner_particles.scale_amount_min = 0.5
	inner_particles.scale_amount_max = 1.5
	inner_particles.color = portal_color
	add_child(inner_particles)
	
	# Outer energy particles
	var outer_particles = CPUParticles2D.new()
	outer_particles.amount = 50
	outer_particles.lifetime = 2.0
	outer_particles.emitting = true
	outer_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	outer_particles.emission_sphere_radius = 80.0
	outer_particles.spread = 45.0
	outer_particles.initial_velocity_min = -50.0
	outer_particles.initial_velocity_max = -100.0
	outer_particles.gravity = Vector2.ZERO
	outer_particles.scale_amount_min = 2.0
	outer_particles.scale_amount_max = 3.0
	outer_particles.color = particle_color
	add_child(outer_particles)

func _create_lightning_effects():
	# Create multiple lightning strikes
	for i in range(3):
		var timer = Timer.new()
		timer.wait_time = randf() * 0.5  # Random delay up to 0.5 seconds
		timer.one_shot = true
		timer.timeout.connect(func(): _spawn_lightning_strike(); timer.queue_free())
		add_child(timer)
		timer.start()

func _spawn_lightning_strike():
	# Create a simple lightning effect
	var lightning = Line2D.new()
	lightning.width = 8.0
	lightning.default_color = Color(1, 1, 0.5, 1)
	lightning.z_index = 20
	
	# Generate lightning path
	var points: Array[Vector2] = []
	var start_pos = Vector2(randf_range(-50, 50), -200)
	var end_pos = Vector2(randf_range(-20, 20), 0)
	points.append(start_pos)
	
	# Add zigzag points
	var segments = 5
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = start_pos.lerp(end_pos, t)
		var offset = Vector2(randf_range(-30, 30), 0)
		points.append(base_pos + offset)
	
	points.append(end_pos)
	lightning.points = points
	add_child(lightning)
	
	# Fade out the lightning
	var tween = create_tween()
	
	# Kill tween when lightning is freed
	lightning.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(lightning, "modulate:a", 0.0, 0.3)
	tween.tween_callback(lightning.queue_free)

func _create_shockwave():
	# Visual shockwave that expands outward
	var shockwave = Node2D.new()
	shockwave.z_index = -1  # Behind the boss
	add_child(shockwave)
	
	# We'll draw the shockwave in _draw
	set_process(true)

func _process(_delta):
	time_elapsed += _delta
	
	# Update portal radius
	if use_portal:
		var progress = min(time_elapsed / effect_duration, 1.0)
		portal_radius = max_portal_radius * progress
	
	# Redraw for animated effects
	queue_redraw()
	
	# Check if effect is complete
	if time_elapsed >= effect_duration:
		spawn_complete.emit()
		queue_free()

func _draw():
	if use_portal and portal_radius > 0:
		# Draw expanding portal
		var alpha = 1.0 - (time_elapsed / effect_duration)
		draw_circle(Vector2.ZERO, portal_radius, Color(portal_color.r, portal_color.g, portal_color.b, alpha * 0.3))
		draw_arc(Vector2.ZERO, portal_radius, 0, TAU, 64, portal_color * alpha, 3.0)
		
		# Inner ring
		if portal_radius > 20:
			draw_arc(Vector2.ZERO, portal_radius - 20, 0, TAU, 32, portal_color * alpha * 0.5, 2.0)
	
	if use_shockwave:
		# Draw expanding shockwave
		var shockwave_progress = min(time_elapsed * 2, 1.0)  # Faster expansion
		var shockwave_radius = 200.0 * shockwave_progress
		var shockwave_alpha = 1.0 - shockwave_progress
		
		if shockwave_alpha > 0:
			for i in range(3):
				var radius = shockwave_radius - (i * 10)
				if radius > 0:
					var alpha = shockwave_alpha * (1.0 - float(i) / 3.0) * 0.5
					draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, alpha * 0.2))

## Override this in boss-specific spawn effects
func _on_spawn_effect_start():
	pass

## Override this for custom completion behavior
func _on_spawn_effect_complete():
	pass
