extends Node
class_name MovementController

## Handles movement input and physics for entities
## Can be extended for different movement types (player, AI, etc.)

signal movement_started()
signal movement_stopped()
signal direction_changed(new_direction: Vector2)

@export var acceleration: float = 2000.0
@export var friction: float = 1500.0
@export var max_speed_override: float = -1.0  # -1 means use entity's move_speed

var entity  # BaseEntity - untyped to avoid circular dependency
var current_direction: Vector2 = Vector2.ZERO
var is_moving: bool = false

func _ready():
	# Get parent entity
	entity = get_parent()
	if not entity or not entity.has_method("_physics_process"):
		push_error("MovementController must be a child of BaseEntity")
		queue_free()

func _physics_process(_delta):
	# Get movement input (virtual function)
	var input_vector = _get_movement_input()
	
	# Update movement state
	if input_vector.length() > 0 and not is_moving:
		is_moving = true
		movement_started.emit()
	elif input_vector.length() == 0 and is_moving:
		is_moving = false
		movement_stopped.emit()
	
	# Update direction
	if input_vector.length() > 0:
		current_direction = input_vector.normalized()
		direction_changed.emit(current_direction)
	
	# Calculate target speed - use effective speed if available (for boss buffs)
	var base_speed = entity.move_speed
	if entity.has_method("get_effective_move_speed"):
		base_speed = entity.get_effective_move_speed()
	var target_speed = base_speed if max_speed_override < 0 else max_speed_override
	
	# Apply acceleration or friction
	if input_vector.length() > 0:
		# Accelerate towards input direction
		entity.movement_velocity = entity.movement_velocity.move_toward(
			input_vector.normalized() * target_speed,
			acceleration * _delta
		)
	else:
		# Apply friction
		entity.movement_velocity = entity.movement_velocity.move_toward(
			Vector2.ZERO,
			friction * _delta
		)

## Virtual function - override in subclasses
func _get_movement_input() -> Vector2:
	return Vector2.ZERO

## Get current movement direction (normalized)
func get_direction() -> Vector2:
	return current_direction

## Check if currently moving
func is_entity_moving() -> bool:
	return is_moving

## Stop movement immediately
func stop_movement():
	entity.movement_velocity = Vector2.ZERO
	is_moving = false
	movement_stopped.emit()



