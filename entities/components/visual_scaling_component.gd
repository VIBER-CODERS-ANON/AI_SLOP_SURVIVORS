class_name VisualScalingComponent
extends Node

@export var base_scale: float = 1.0
@export var scale_multiplier: float = 1.0
@export var auto_update: bool = true

var sprite: Node2D
var collision_shape: CollisionShape2D
var original_sprite_scale: Vector2
var original_collision_radius: float
var original_collision_extents: Vector2

func initialize(entity: Node2D) -> void:
	sprite = entity.get_node_or_null("Sprite2D")
	if not sprite:
		sprite = entity.get_node_or_null("AnimatedSprite2D")
	
	collision_shape = entity.get_node_or_null("CollisionShape2D")
	
	if sprite:
		original_sprite_scale = sprite.scale
	
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CircleShape2D:
			original_collision_radius = collision_shape.shape.radius
		elif collision_shape.shape is RectangleShape2D:
			original_collision_extents = collision_shape.shape.size

func update_scale() -> void:
	var total_scale = base_scale * scale_multiplier
	
	if sprite and original_sprite_scale:
		sprite.scale = original_sprite_scale * total_scale
	
	if collision_shape and collision_shape.shape:
		if collision_shape.shape is CircleShape2D and original_collision_radius > 0:
			collision_shape.shape.radius = original_collision_radius * total_scale
		elif collision_shape.shape is RectangleShape2D and original_collision_extents:
			collision_shape.shape.size = original_collision_extents * total_scale

func set_base_scale(value: float) -> void:
	base_scale = value
	if auto_update:
		update_scale()

func set_scale_multiplier(value: float) -> void:
	scale_multiplier = value
	if auto_update:
		update_scale()

func get_total_scale() -> float:
	return base_scale * scale_multiplier