extends Node
class_name AbilityHelper

## Helper module for ability-related utilities and scaling

static func scale_aoe_ability(ability_node: Node, scale_multiplier: float):
	# Scale collision shapes for AoE abilities
	var collision_shape = ability_node.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		# Store original size if not already stored
		if not collision_shape.has_meta("original_shape_scale"):
			if collision_shape.shape is RectangleShape2D:
				collision_shape.set_meta("original_shape_scale", collision_shape.shape.size)
			elif collision_shape.shape is CircleShape2D:
				collision_shape.set_meta("original_shape_scale", collision_shape.shape.radius)
		
		# Apply scaling
		if collision_shape.shape is RectangleShape2D:
			var original_size = collision_shape.get_meta("original_shape_scale")
			collision_shape.shape.size = original_size * scale_multiplier
		elif collision_shape.shape is CircleShape2D:
			var original_radius = collision_shape.get_meta("original_shape_scale")
			collision_shape.shape.radius = original_radius * scale_multiplier

static func reset_aoe_ability_scale(ability_node: Node):
	# Reset collision shape to original size
	var collision_shape = ability_node.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape and collision_shape.has_meta("original_shape_scale"):
		if collision_shape.shape is RectangleShape2D:
			var original_size = collision_shape.get_meta("original_shape_scale")
			collision_shape.shape.size = original_size
		elif collision_shape.shape is CircleShape2D:
			var original_radius = collision_shape.get_meta("original_shape_scale")
			collision_shape.shape.radius = original_radius

static func get_ability_effective_radius(ability_node: Node) -> float:
	# Get the effective radius of an ability for range calculations
	var collision_shape = ability_node.get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return 0.0
	
	if collision_shape.shape is CircleShape2D:
		return collision_shape.shape.radius
	elif collision_shape.shape is RectangleShape2D:
		# Return the diagonal as effective radius
		var size = collision_shape.shape.size
		return size.length() / 2.0
	
	return 0.0