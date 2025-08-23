extends Node
class_name CursorManager

## Handles all cursor-related functionality including custom cursors, debug tools, and hotspot management

# Unused signal - kept for potential future use
# signal cursor_hotspot_changed(new_hotspot: Vector2)

# Cursor configuration
var cursor_hotspot: Vector2 = Vector2(42, 37)  # Fine-tuned 5px left for perfect alignment

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func setup_custom_cursor():
	var cursor_texture = load("res://ui/gauntlet_cursor_small.png")
	if cursor_texture:
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, cursor_hotspot)
