extends Area2D
class_name PoisonCloud

## Static poison gas cloud that damages players inside

@export var damage_per_second: float = 1.0
@export var cloud_radius: float = 120.0
@export var duration: float = 8.0
@export var fade_time: float = 2.0

var time_alive: float = 0.0
var players_inside: Dictionary = {}  # Track players and their damage timers
var cloud_particles: CPUParticles2D
var is_fading: bool = false
var applied_aoe_scale: float = 1.0  # Track AoE scale for this cloud
var source_name: String = "Unknown"  # Who created this cloud

func _ready():
	# Ensure poison cloud pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Set up collision
	collision_layer = 0  # Effects don't have their own layer
	collision_mask = 1   # Only detect players
	
	# Create collision shape
	var shape = CircleShape2D.new()
	shape.radius = cloud_radius * applied_aoe_scale
	var collision = CollisionShape2D.new()
	collision.shape = shape
	collision.modulate = Color(0, 1, 0, 0.2)
	add_child(collision)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create the poison cloud visuals
	_create_cloud_visuals()
	
	# Start lifetime timer
	set_physics_process(true)
	
	# Set name for death messages
	name = "Poison Cloud"
	
	# Store source information for proper death attribution
	var spawner: Node = null
	if has_meta("spawner"):
		spawner = get_meta("spawner")
	
	# Set up proper killer attribution methods
	if spawner:
		# Store reference to original spawner for method delegation
		set_meta("original_spawner", spawner)
	
	# Ensure we have a source name for display
	if not has_meta("source_name"):
		if spawner:
			if spawner.has_method("get_killer_display_name"):
				set_meta("source_name", spawner.get_killer_display_name())
			elif spawner.has_method("get_chatter_username"):
				set_meta("source_name", spawner.get_chatter_username())
			elif spawner.has_method("get_display_name"):
				set_meta("source_name", spawner.get_display_name())
			else:
				set_meta("source_name", spawner.name)
		else:
			set_meta("source_name", "Someone")
	
	print("☠️ Poison cloud spawned at ", global_position)

func _create_cloud_visuals():
	# Create particle system for the cloud
	cloud_particles = CPUParticles2D.new()
	cloud_particles.amount = 200
	cloud_particles.lifetime = 3.0
	cloud_particles.preprocess = 1.0  # Pre-fill the cloud
	cloud_particles.emitting = true
	cloud_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	cloud_particles.emission_sphere_radius = cloud_radius * applied_aoe_scale * 0.8
	cloud_particles.spread = 10.0
	cloud_particles.initial_velocity_min = 5.0
	cloud_particles.initial_velocity_max = 15.0
	cloud_particles.angular_velocity_min = -30.0
	cloud_particles.angular_velocity_max = 30.0
	cloud_particles.gravity = Vector2(0, -10)  # Slight upward drift
	cloud_particles.scale_amount_min = 1.5
	cloud_particles.scale_amount_max = 3.0
	cloud_particles.color = Color(0.2, 0.8, 0.2, 0.5)  # Green poison color
	cloud_particles.color_initial_ramp = create_gradient_texture()
	add_child(cloud_particles)
	
	# Add some bigger, slower particles for depth
	var big_particles = CPUParticles2D.new()
	big_particles.amount = 50
	big_particles.lifetime = 4.0
	big_particles.preprocess = 1.0
	big_particles.emitting = true
	big_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	big_particles.emission_sphere_radius = cloud_radius * applied_aoe_scale
	big_particles.spread = 5.0
	big_particles.initial_velocity_min = 2.0
	big_particles.initial_velocity_max = 8.0
	big_particles.gravity = Vector2(0, -5)
	big_particles.scale_amount_min = 4.0
	big_particles.scale_amount_max = 6.0
	big_particles.color = Color(0.1, 0.6, 0.1, 0.3)  # Darker green
	add_child(big_particles)

func create_gradient_texture() -> Gradient:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.2, 0.8, 0.2, 0.0))
	gradient.set_color(1, Color(0.2, 1.0, 0.2, 0.5))
	return gradient

func _physics_process(_delta):
	time_alive += _delta
	
	# Check if it's time to fade out
	if time_alive >= duration and not is_fading:
		_start_fade_out()
	
	# Apply damage to players inside
	for player in players_inside.keys():
		if is_instance_valid(player):
			players_inside[player] += _delta
			# Deal damage once per second
			if players_inside[player] >= 1.0:
				players_inside[player] = 0.0
				if player.has_method("take_damage"):
					# Pass null as source if the original source is freed
					var damage_source = self
					player.take_damage(damage_per_second, damage_source, ["Poison", "DoT", "Environmental", "AoE"])
					print("☠️ Poison cloud dealing ", damage_per_second, " damage to ", player.name)
		else:
			# Player no longer valid, remove from dict
			players_inside.erase(player)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		players_inside[body] = 0.0
		print("☠️ Player entered poison cloud!")

func _on_body_exited(body: Node2D):
	if body.is_in_group("player"):
		players_inside.erase(body)
		print("☠️ Player left poison cloud")

func _start_fade_out():
	is_fading = true
	
	# Stop emitting new particles
	for child in get_children():
		if child is CPUParticles2D:
			child.emitting = false
	
	# Fade out and then remove
	var tween = create_tween()
	
	# Kill tween when cloud is freed
	tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(queue_free)

func _draw():
	# Draw a subtle circle to show the damage area
	draw_circle(Vector2.ZERO, cloud_radius * applied_aoe_scale, Color(0, 1, 0, 0.1))
	
	# Draw thicker edge
	draw_arc(Vector2.ZERO, cloud_radius * applied_aoe_scale, 0, TAU, 64, Color(0, 1, 0, 0.3), 3.0)

## Death attribution methods for proper kill credit
func get_killer_display_name() -> String:
	# Try to get from original spawner first
	if has_meta("original_spawner"):
		var spawner = get_meta("original_spawner")
		if spawner and is_instance_valid(spawner):
			if spawner.has_method("get_killer_display_name"):
				return spawner.get_killer_display_name()
			elif spawner.has_method("get_chatter_username"):
				return spawner.get_chatter_username()
			elif spawner.has_method("get_display_name"):
				return spawner.get_display_name()
	
	# Fall back to stored source name
	return get_meta("source_name", "Someone") + "'s"

func get_chatter_username() -> String:
	# Delegate to original spawner if available
	if has_meta("original_spawner"):
		var spawner = get_meta("original_spawner")
		if spawner and is_instance_valid(spawner) and spawner.has_method("get_chatter_username"):
			return spawner.get_chatter_username()
	
	# Fall back to source name
	return get_meta("source_name", "Someone")

func get_attack_name() -> String:
	return "toxic fart cloud"
