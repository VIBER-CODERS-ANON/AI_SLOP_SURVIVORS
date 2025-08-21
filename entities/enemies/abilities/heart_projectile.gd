extends Area2D
class_name HeartProjectile

## Heart-shaped projectile fired by Succubus

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var lifetime: float = 3.0
var owner_entity: Node = null
var source_name: String = "Unknown"  # For death attribution

# Visual
var sprite: Sprite2D
var particles: CPUParticles2D

func _ready():
	# Set up collision
	collision_layer = 4  # Projectiles layer
	collision_mask = 1   # Hit players
	
	# Create heart visual
	_create_heart_visual()
	
	# Create particles
	_create_particles()
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Add to projectiles group
	add_to_group("projectiles")
	add_to_group("enemy_projectiles")

func setup(direction: Vector2, speed: float, damage_amount: float, proj_owner: Node):
	velocity = direction * speed
	damage = damage_amount
	owner_entity = proj_owner
	
	# Store reference to original owner for proper attribution
	if proj_owner:
		set_meta("original_owner", proj_owner)
		# Try to get the owner's name for death messages
		if proj_owner.has_method("get_chatter_username"):
			source_name = proj_owner.get_chatter_username()
		elif proj_owner.has_method("get_display_name"):
			source_name = proj_owner.get_display_name()
		elif proj_owner.has_meta("chatter_username"):
			source_name = proj_owner.get_meta("chatter_username")
		else:
			source_name = proj_owner.name
		set_meta("source_name", source_name)
	
	# Rotate to face direction
	rotation = direction.angle()

func _physics_process(delta):
	# Move projectile
	position += velocity * delta
	
	# Spin the projectile
	rotation += 5.0 * delta  # Rotate at 5 radians per second
	
	# Update lifetime
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _create_heart_visual():
	# Create a simple heart shape using a polygon
	var heart_shape = Polygon2D.new()
	heart_shape.name = "HeartShape"
	
	# Define heart shape points (simplified)
	var points = PackedVector2Array([
		Vector2(0, -8),      # Top center
		Vector2(-6, -12),    # Top left curve
		Vector2(-12, -8),    # Left curve
		Vector2(-12, -2),    # Left side
		Vector2(0, 10),      # Bottom point
		Vector2(12, -2),     # Right side
		Vector2(12, -8),     # Right curve
		Vector2(6, -12),     # Top right curve
		Vector2(0, -8)       # Close shape
	])
	
	heart_shape.polygon = points
	heart_shape.color = Color(1.0, 0.2, 0.4)  # Pink/red color
	add_child(heart_shape)
	
	# Add glow effect
	var glow = Polygon2D.new()
	glow.name = "HeartGlow"
	glow.polygon = points
	glow.color = Color(1.0, 0.4, 0.6, 0.3)
	glow.scale = Vector2(1.2, 1.2)
	glow.z_index = -1
	add_child(glow)

func _create_particles():
	particles = CPUParticles2D.new()
	particles.name = "HeartParticles"
	particles.amount = 20  # More particles
	particles.lifetime = 0.8
	particles.emitting = true
	
	# Particle properties - trail effect
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	particles.direction = Vector2(-1, 0)  # Emit backwards
	particles.spread = 30.0
	particles.initial_velocity_min = 30.0
	particles.initial_velocity_max = 60.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.5
	# particles.scale_amount_curve = null  # No curve needed for now
	
	# Color gradient - pink to transparent
	particles.color = Color(1.0, 0.6, 0.8)
	
	# Trail-like behavior
	particles.gravity = Vector2.ZERO
	particles.damping_min = 2.0
	particles.damping_max = 5.0
	
	# Z-index for proper layering
	particles.z_index = -1
	
	add_child(particles)

func _on_body_entered(body: Node2D):
	# Check if we hit a player
	if body.is_in_group("player") and body != owner_entity:
		# Deal damage - pass self as damage source for proper attribution
		if body.has_method("take_damage"):
			body.take_damage(damage, self)
		
		# Create hit effect
		_create_hit_effect()
		
		# Destroy projectile
		queue_free()

func _on_area_entered(_area: Area2D):
	# Could be used for shield interactions later
	pass

func _create_hit_effect():
	# Create a burst of heart particles on hit
	var hit_particles = CPUParticles2D.new()
	hit_particles.amount = 30
	hit_particles.lifetime = 0.5
	hit_particles.emitting = true
	hit_particles.one_shot = true
	hit_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	hit_particles.emission_sphere_radius = 15.0
	hit_particles.initial_velocity_min = 100.0
	hit_particles.initial_velocity_max = 200.0
	hit_particles.angular_velocity_min = -720.0
	hit_particles.angular_velocity_max = 720.0
	hit_particles.scale_amount_min = 0.2
	hit_particles.scale_amount_max = 0.8
	hit_particles.color = Color(1.0, 0.4, 0.6)
	
	# Add gravity for falling effect
	hit_particles.gravity = Vector2(0, 200)
	hit_particles.damping_min = 1.0
	hit_particles.damping_max = 3.0
	
	# Random colors for variety - removed gradient for now
	
	get_tree().current_scene.add_child(hit_particles)
	hit_particles.global_position = global_position
	
	# Clean up after emission
	await hit_particles.finished
	hit_particles.queue_free()

## Death attribution methods for proper kill credit
func get_killer_display_name() -> String:
	# Delegate to owner entity
	if owner_entity and is_instance_valid(owner_entity):
		if owner_entity.has_method("get_killer_display_name"):
			return owner_entity.get_killer_display_name()
		elif owner_entity.has_method("get_chatter_username"):
			return owner_entity.get_chatter_username()
		elif owner_entity.has_method("get_display_name"):
			return owner_entity.get_display_name()
		else:
			return owner_entity.name
	
	# Check stored reference
	if has_meta("original_owner"):
		var original = get_meta("original_owner")
		if original and is_instance_valid(original):
			if original.has_method("get_killer_display_name"):
				return original.get_killer_display_name()
			elif original.has_method("get_chatter_username"):
				return original.get_chatter_username()
			elif original.has_method("get_display_name"):
				return original.get_display_name()
	
	return "Someone"

func get_chatter_username() -> String:
	# Delegate to owner entity
	if owner_entity and is_instance_valid(owner_entity) and owner_entity.has_method("get_chatter_username"):
		return owner_entity.get_chatter_username()
	
	# Check stored reference
	if has_meta("original_owner"):
		var original = get_meta("original_owner")
		if original and is_instance_valid(original) and original.has_method("get_chatter_username"):
			return original.get_chatter_username()
	
	return ""

func get_attack_name() -> String:
	return "heart projectile"
