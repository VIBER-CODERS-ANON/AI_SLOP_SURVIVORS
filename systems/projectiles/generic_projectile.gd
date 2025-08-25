extends Area2D
class_name GenericProjectile

## Generic sprite-based projectile for simple projectiles
## Lightweight alternative to full scene-based projectiles

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var lifetime: float = 3.0
var owner_entity: Node = null
var source_name: String = "Unknown"

# Visual components
var sprite: Sprite2D
var collision_shape: CollisionShape2D

func _ready():
	# Set up collision layers
	collision_layer = 4  # Projectiles layer
	collision_mask = 1   # Hit players
	
	# Create sprite
	sprite = Sprite2D.new()
	add_child(sprite)
	
	# Create collision
	collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Add to groups
	add_to_group("projectiles")
	add_to_group("enemy_projectiles")

func setup(direction: Vector2, speed: float, damage_amount: float, proj_owner: Node):
	velocity = direction * speed
	damage = damage_amount
	owner_entity = proj_owner
	
	# Store reference for attribution
	if proj_owner:
		set_meta("original_owner", proj_owner)
		# Get source name for death messages
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

func configure_visual(texture: Texture2D, collision_radius: float, scale_factor: Vector2):
	if sprite:
		sprite.texture = texture
		sprite.scale = scale_factor
	
	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape.radius = collision_radius

func _physics_process(delta):
	# Move projectile
	position += velocity * delta
	
	# Update lifetime
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body: Node2D):
	# Check if we hit a player
	if body.is_in_group("player") and body != owner_entity:
		# Deal damage
		if body.has_method("take_damage"):
			body.take_damage(damage, self)
		
		# Destroy projectile
		queue_free()

func _on_area_entered(_area: Area2D):
	# Could be used for shield interactions later
	pass

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
	return "projectile"