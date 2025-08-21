extends Control
class_name DeathScreen

## Dark Souls style death screen

var main_label: Label
var killer_label: RichTextLabel

func _ready():
	# Continue processing during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Fill entire screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Create dark background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	
	# Create container for text
	var container = VBoxContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	container.position = Vector2(-300, -150)  # Center the container
	container.custom_minimum_size = Vector2(600, 300)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 30)
	add_child(container)
	
	# Create "YOU DIED" label
	main_label = Label.new()
	main_label.text = "YOU DIED"
	main_label.add_theme_font_size_override("font_size", 80)
	main_label.modulate = Color(0.8, 0.1, 0.1)  # Dark red
	main_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(main_label)
	
	# Create killer info label (RichTextLabel for colored names)
	killer_label = RichTextLabel.new()
	killer_label.add_theme_font_size_override("normal_font_size", 32)
	killer_label.bbcode_enabled = true
	killer_label.fit_content = true
	killer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	killer_label.custom_minimum_size = Vector2(600, 40)
	killer_label.modulate = Color(0.9, 0.9, 0.9)
	container.add_child(killer_label)
	
	# Start hidden
	visible = false
	modulate.a = 0.0

func show_death(killer_name: String = "Unknown", death_cause: String = "", killer_color: Color = Color.WHITE):
	# Set killer text with BBCode for colored username
	killer_label.clear()
	
	# Format the death message with colored username
	var colored_name = "[color=#%s]%s[/color]" % [killer_color.to_html(false), killer_name]
	
	if death_cause != "":
		killer_label.append_text("[center]%s killed you with %s[/center]" % [colored_name, death_cause])
	else:
		killer_label.append_text("[center]%s killed you[/center]" % colored_name)
	
	# Stop background music and play death music
	_switch_to_death_music()
	
	# Show and animate
	visible = true
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Kill tween when death screen is freed
	tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	# Scale effect on main text
	main_label.scale = Vector2(0.8, 0.8)
	tween.parallel().tween_property(main_label, "scale", Vector2(1.0, 1.0), 0.5)
	
	# Wait a bit before allowing restart
	tween.tween_interval(2.0)
	tween.tween_callback(_enable_restart)

func _enable_restart():
	var container = get_child(1)  # Get the VBoxContainer
	
	# Check if restart label already exists
	for child in container.get_children():
		if child is Label and child.text == "Press R to restart":
			return  # Already exists, don't add another
	
	# Add restart instructions
	var restart_label = Label.new()
	restart_label.text = "Press R to restart"
	restart_label.add_theme_font_size_override("font_size", 24)
	restart_label.modulate = Color(0.7, 0.7, 0.7)
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(restart_label)

func _input(event):
	if not visible:
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Restart the game
			if GameController.instance:
				GameController.instance.state_manager.clear_all_pause_states()
			get_tree().reload_current_scene()

func hide_death():
	var tween = create_tween()
	
	# Kill tween when death screen is freed
	tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): visible = false)

func _switch_to_death_music():
	# Stop background music using ResourceManager API
	ResourceManager.stop_music()
	
	# Play death music through AudioManager
	if AudioManager.instance:
		var death_stream = preload("res://music/deathscreenmusic.mp3")
		# Ensure it doesn't loop
		if death_stream is AudioStreamMP3:
			death_stream.loop = false
		AudioManager.instance.play_music(
			death_stream,
			"death_music",
			-6.0,  # Same volume as before
			false
		)
		print("💀 Playing death screen music...")
