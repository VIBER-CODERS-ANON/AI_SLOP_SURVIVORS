extends Control
class_name LevelUpSelection

## UI for selecting permanent buffs on level up

signal buff_selected(buff_type: String)

var buff_options: Array[Dictionary] = [
	{
		"type": "max_health",
		"name": "+10 Max HP",
		"description": "Increases maximum health by 10",
		"color": Color(1, 0.2, 0.2)
	},
	{
		"type": "base_damage", 
		"name": "+1 Base Damage",
		"description": "Increases base damage by 1",
		"color": Color(1, 0.5, 0)
	},
	{
		"type": "move_speed",
		"name": "+2% Move Speed", 
		"description": "Increases movement speed by 2%",
		"color": Color(0.2, 0.8, 1)
	},
	{
		"type": "pickup_radius",
		"name": "+10% Pickup Radius",
		"description": "Increases pickup radius by 10%", 
		"color": Color(0.8, 0.2, 1)
	},
	{
		"type": "crit_chance",
		"name": "+2.5% Crit Chance",
		"description": "Increases critical hit chance by 2.5%",
		"color": Color(1, 1, 0.2)
	},
	{
		"type": "area_of_effect",
		"name": "+10% Area of Effect",
		"description": "Increases the size of AoE abilities by 10%",
		"color": Color(0.8, 0.4, 1)
	}
]

var selected_buffs: Array[Dictionary] = []
var buff_buttons: Array[Button] = []

func _ready():
	# Set up fullscreen overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make sure this UI can process during pause
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Create dark background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Create main container
	var main_container = VBoxContainer.new()
	main_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	main_container.position = Vector2(-400, -150)  # Center the container
	main_container.custom_minimum_size = Vector2(800, 300)
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 20)
	add_child(main_container)
	
	# Title
	var title = Label.new()
	title.text = "LEVEL UP! Choose a Buff:"
	title.add_theme_font_size_override("font_size", 36)
	title.modulate = Color(1, 0.9, 0.2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Buff selection container
	var buff_container = HBoxContainer.new()
	buff_container.alignment = BoxContainer.ALIGNMENT_CENTER
	buff_container.add_theme_constant_override("separation", 30)
	main_container.add_child(buff_container)
	
	# Create buff buttons
	for i in range(3):
		var buff_button = _create_buff_button()
		buff_container.add_child(buff_button)
		buff_buttons.append(buff_button)
	
	# Start hidden
	visible = false

func _create_buff_button() -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(200, 150)
	button.add_theme_font_size_override("font_size", 16)
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2  
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.5, 0.5, 0.5)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	
	return button

func show_selection():
	# Get 3 random buffs
	var available_buffs = buff_options.duplicate()
	available_buffs.shuffle()
	selected_buffs = available_buffs.slice(0, 3)
	
	# Update buttons
	for i in range(3):
		var buff = selected_buffs[i]
		var button = buff_buttons[i]
		
		# Set text with formatting
		button.text = buff.name + "\n\n" + buff.description
		button.modulate = buff.color
		
		# Connect signal
		if button.pressed.is_connected(_on_buff_selected):
			button.pressed.disconnect(_on_buff_selected)
		button.pressed.connect(_on_buff_selected.bind(i))
		
		# Add hover effect
		button.mouse_entered.connect(_on_button_hover.bind(button, buff.color))
		button.mouse_exited.connect(_on_button_unhover.bind(button))
	
	# Show (pause is handled by game controller)
	visible = true

func _on_buff_selected(index: int):
	var selected_buff = selected_buffs[index]
	
	# Flash selection
	var button = buff_buttons[index]
	var tween = create_tween()
	tween.tween_property(button, "modulate", Color.WHITE, 0.1)
	tween.tween_property(button, "modulate", selected_buff.color, 0.1)
	tween.tween_callback(_complete_selection.bind(selected_buff))

func _complete_selection(buff: Dictionary):
	# Emit signal
	buff_selected.emit(buff.type)
	
	# Hide (unpause is handled by game controller)
	visible = false
	
	# Disconnect all signals
	for button in buff_buttons:
		if button.pressed.is_connected(_on_buff_selected):
			button.pressed.disconnect(_on_buff_selected)
		if button.mouse_entered.is_connected(_on_button_hover):
			button.mouse_entered.disconnect(_on_button_hover)
		if button.mouse_exited.is_connected(_on_button_unhover):
			button.mouse_exited.disconnect(_on_button_unhover)

func _on_button_hover(button: Button, color: Color):
	var style = button.get_theme_stylebox("normal") as StyleBoxFlat
	if style:
		style.border_color = color
		style.border_width_left = 4
		style.border_width_right = 4
		style.border_width_top = 4
		style.border_width_bottom = 4

func _on_button_unhover(button: Button):
	var style = button.get_theme_stylebox("normal") as StyleBoxFlat
	if style:
		style.border_color = Color(0.5, 0.5, 0.5)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
