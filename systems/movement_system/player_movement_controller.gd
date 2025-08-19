extends MovementController
class_name PlayerMovementController

## Player-specific movement controller that handles WASD input

@export var use_controller: bool = true  # Also accept controller input
@export var controller_deadzone: float = 0.2

func _get_movement_input() -> Vector2:
	var input_vector = Vector2.ZERO
	
	# Keyboard input (WASD)
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	# Normalize diagonal movement
	if input_vector.length() > 1.0:
		input_vector = input_vector.normalized()
	
	# Apply controller deadzone if using controller
	if use_controller and input_vector.length() < controller_deadzone:
		input_vector = Vector2.ZERO
	
	return input_vector

## Override to handle input actions
func _unhandled_input(_event):
	# Can add special movement abilities here
	# For example: dash on spacebar
	pass



