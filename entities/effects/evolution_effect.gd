extends Node2D

## Visual effect for entity evolution
## Shows a dramatic transformation animation

func _ready():
	z_index = 100  # Render on top
	_create_effect()

func _create_effect():
	# Create particle burst
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 1.0
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 2.0
	particles.color = Color(0.8, 0, 0.8)  # Purple for evolution
	particles.gravity = Vector2.ZERO
	add_child(particles)
	
	# Create expanding ring
	var ring = Node2D.new()
	add_child(ring)
	
	# Animate the ring
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Kill tween when ring is freed
	ring.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(ring, "scale", Vector2(5, 5), 0.5)
	tween.tween_property(ring, "modulate:a", 0.0, 0.5)
	
	# Clean up after animation
	tween.finished.connect(queue_free)
	
	# Play evolution sound if available
	if AudioManager.instance:
		var sound_path = "res://audio/evolution_sound.mp3"
		if ResourceLoader.exists(sound_path):
			var stream = load(sound_path)
			AudioManager.instance.play_sfx_at_position(stream, global_position, 0.0, 1.0)
	
func _draw():
	# Draw expanding ring
	draw_arc(Vector2.ZERO, 30.0, 0, TAU, 32, Color(0.8, 0, 0.8, 0.5), 5.0)
