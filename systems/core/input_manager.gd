extends Node
class_name InputManager

## Handles core game inputs (all debug functionality moved to DebugManager)

signal pause_toggled()

# References (set by GameController)
var player: Player
var game_controller: Node2D

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent):
	if not event.is_pressed():
		return
	
	if not event is InputEventKey:
		return
	
	# Regular game inputs only
	match event.keycode:
		KEY_ESCAPE:
			pause_toggled.emit()
		KEY_P:  # Alternative pause key
			pause_toggled.emit()
		# F12 is handled by DebugManager directly
