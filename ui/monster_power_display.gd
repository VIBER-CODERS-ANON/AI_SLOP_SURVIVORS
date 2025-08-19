extends Label
class_name MonsterPowerDisplay

## Clean UI component that displays just the monster power threshold number
## Directly references TicketSpawnManager for real-time updates

# Visual settings
var base_color: Color = Color(0.5, 0.5, 0.5)  # Grey default
var danger_color: Color = Color(1.0, 0.2, 0.2)  # Red at high power
var color_gradient: Gradient

# Cached value for smooth display
var display_value: float = 0.0  # Start at base (0)
var target_value: float = 0.0

func _ready():
	# Set up label properties
	add_theme_font_size_override("font_size", 18)  # Half size (was 36)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text = "0.0"  # Start with base value
	modulate = base_color  # Start grey
	
	# Create a small overlay button that sits at the right edge of the label
	var btn := Button.new()
	btn.name = "AddPointOneButton"
	btn.text = "+0.1"
	btn.theme_type_variation = "FlatButton"
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(36, 20)
	add_child(btn)
	btn.anchors_preset = Control.PRESET_RIGHT_WIDE
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.offset_left = -44
	btn.offset_right = -8
	btn.offset_top = -2
	btn.offset_bottom = 22
	btn.pressed.connect(_on_add_point_one_pressed)
	
	# Create gradient for color transitions
	color_gradient = Gradient.new()
	color_gradient.add_point(0.0, base_color)
	color_gradient.add_point(1.0, danger_color)
	
	# Connect to TicketSpawnManager if it exists
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.monster_power_changed.connect(_on_monster_power_changed)
		_update_from_manager()
		print("🎯 Monster Power Display connected to TicketSpawnManager")
	else:
		# Wait for TicketSpawnManager to be ready
		await get_tree().process_frame
		if TicketSpawnManager.instance:
			TicketSpawnManager.instance.monster_power_changed.connect(_on_monster_power_changed)
			_update_from_manager()
			print("🎯 Monster Power Display connected to TicketSpawnManager (delayed)")

func _process(delta):
	# Smooth value display
	display_value = lerp(display_value, target_value, delta * 10.0)
	
	# Update text
	text = "%.1f" % display_value
	
	# Update color based on threshold
	_update_color()

func _update_from_manager():
	if not TicketSpawnManager.instance:
		return
	
	var stats = TicketSpawnManager.instance.get_ramping_stats()
	target_value = stats.get("total", 0.0)

func _on_monster_power_changed(_current_power: float, threshold: float):
	target_value = threshold
	
	# Optional: Add a subtle scale pulse when value changes significantly
	if abs(threshold - display_value) > 0.5:
		_pulse()

func _update_color():
	# Calculate color based on threshold level
	var color_position = clamp((display_value - 1.0) / 10.0, 0.0, 1.0)  # 1-11 range
	modulate = color_gradient.sample(color_position)

func _pulse():
	# Subtle scale animation
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func _on_add_point_one_pressed():
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.adjust_monster_power_threshold(0.1)
