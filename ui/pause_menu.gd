extends Control
class_name PauseMenu

## Pause menu UI with game controls

signal resume_requested
signal restart_requested
signal quit_requested

# Twitch config
var twitch_config_dialog: TwitchConfigDialog
var current_twitch_channel: String = "quin69"

# Debug panel
var debug_panel: Control
var debug_panel_window: Control

var master_volume_slider: HSlider
var music_volume_slider: HSlider
var sfx_volume_slider: HSlider
var dialog_volume_slider: HSlider

var master_bus_idx: int
var music_bus_idx: int
var sfx_bus_idx: int
var dialog_bus_idx: int

func _ready():
	# This UI should work during pause
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Load saved channel from settings
	_load_saved_channel()
	
	# Get current channel from Twitch bot if available
	_sync_with_twitch_bot()
	
	# Set up fullscreen overlay
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Ensure proper rendering above everything else
	top_level = true
	z_as_relative = false
	z_index = 1000  # High but within valid range
	
	# Create dark background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	# Create main container with scroll
	var scroll_container = ScrollContainer.new()
	scroll_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	scroll_container.position = Vector2(-180, -280)  # Center the container
	scroll_container.custom_minimum_size = Vector2(360, 560)
	scroll_container.follow_focus = true
	add_child(scroll_container)
	
	var main_container = VBoxContainer.new()
	main_container.alignment = BoxContainer.ALIGNMENT_CENTER
	main_container.add_theme_constant_override("separation", 20)
	scroll_container.add_child(main_container)
	
	# Title
	var title = Label.new()
	title.text = "GAME PAUSED"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Spacer
	main_container.add_child(Control.new())
	
	# Button container
	var button_container = VBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 10)
	main_container.add_child(button_container)
	
	# Resume button
	var resume_btn = _create_menu_button("RESUME GAME", Color(0.2, 0.8, 0.2))
	resume_btn.pressed.connect(_on_resume_pressed)
	button_container.add_child(resume_btn)
	
	# Restart button
	var restart_btn = _create_menu_button("RESTART GAME", Color(0.8, 0.6, 0.2))
	restart_btn.pressed.connect(_on_restart_pressed)
	button_container.add_child(restart_btn)
	
	# Quit button
	var quit_btn = _create_menu_button("QUIT TO DESKTOP", Color(0.8, 0.2, 0.2))
	quit_btn.pressed.connect(_on_quit_pressed)
	button_container.add_child(quit_btn)
	
	# Debug Panel button
	var debug_btn = _create_menu_button("🔧 DEBUG PANEL", Color(1, 0.3, 1))
	debug_btn.pressed.connect(_on_debug_pressed)
	button_container.add_child(debug_btn)
	
	# Spacer
	main_container.add_child(Control.new())
	
	# Display settings section title
	var display_title = Label.new()
	display_title.text = "DISPLAY SETTINGS"
	display_title.add_theme_font_size_override("font_size", 20)
	display_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	display_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(display_title)
	
	# Display settings container
	var display_container = VBoxContainer.new()
	display_container.add_theme_constant_override("separation", 10)
	main_container.add_child(display_container)
	
	# Resolution dropdown
	var resolution_container = HBoxContainer.new()
	resolution_container.alignment = BoxContainer.ALIGNMENT_CENTER
	display_container.add_child(resolution_container)
	
	var resolution_label = Label.new()
	resolution_label.text = "Resolution"
	resolution_label.custom_minimum_size = Vector2(100, 25)
	resolution_label.add_theme_font_size_override("font_size", 14)
	resolution_container.add_child(resolution_label)
	
	var resolution_dropdown = OptionButton.new()
	resolution_dropdown.custom_minimum_size = Vector2(160, 25)
	resolution_dropdown.add_theme_font_size_override("font_size", 12)
	# Add common resolutions
	resolution_dropdown.add_item("3840x2160 (4K)")
	resolution_dropdown.add_item("2560x1440 (1440p)")
	resolution_dropdown.add_item("1920x1080 (1080p)")
	resolution_dropdown.add_item("1600x900")
	resolution_dropdown.add_item("1366x768")
	resolution_dropdown.add_item("1280x720 (720p)")
	
	# Set current resolution based on saved settings or current window size
	var saved_width = 1920
	var saved_height = 1080
	if SettingsManager.instance:
		saved_width = SettingsManager.instance.get_setting("display", "resolution_width", 1920)
		saved_height = SettingsManager.instance.get_setting("display", "resolution_height", 1080)
	
	var target_size = Vector2i(saved_width, saved_height)
	if target_size == Vector2i(3840, 2160):
		resolution_dropdown.selected = 0
	elif target_size == Vector2i(2560, 1440):
		resolution_dropdown.selected = 1
	elif target_size == Vector2i(1920, 1080):
		resolution_dropdown.selected = 2
	elif target_size == Vector2i(1600, 900):
		resolution_dropdown.selected = 3
	elif target_size == Vector2i(1366, 768):
		resolution_dropdown.selected = 4
	elif target_size == Vector2i(1280, 720):
		resolution_dropdown.selected = 5
	else:
		resolution_dropdown.selected = 2  # Default to 1080p
	
	resolution_dropdown.item_selected.connect(_on_resolution_selected)
	resolution_container.add_child(resolution_dropdown)
	
	# Fullscreen toggle
	var fullscreen_container = HBoxContainer.new()
	fullscreen_container.alignment = BoxContainer.ALIGNMENT_CENTER
	display_container.add_child(fullscreen_container)
	
	var fullscreen_label = Label.new()
	fullscreen_label.text = "Borderless"
	fullscreen_label.custom_minimum_size = Vector2(100, 25)
	fullscreen_label.add_theme_font_size_override("font_size", 14)
	fullscreen_container.add_child(fullscreen_label)
	
	var fullscreen_check = CheckBox.new()
	var current_mode = DisplayServer.window_get_mode()
	fullscreen_check.button_pressed = (current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	fullscreen_container.add_child(fullscreen_check)
	
	# VSync toggle
	var vsync_container = HBoxContainer.new()
	vsync_container.alignment = BoxContainer.ALIGNMENT_CENTER
	display_container.add_child(vsync_container)
	
	var vsync_label = Label.new()
	vsync_label.text = "VSync"
	vsync_label.custom_minimum_size = Vector2(100, 25)
	vsync_label.add_theme_font_size_override("font_size", 14)
	vsync_container.add_child(vsync_label)
	
	var vsync_check = CheckBox.new()
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED
	vsync_check.toggled.connect(_on_vsync_toggled)
	vsync_container.add_child(vsync_check)
	
	# Spacer
	main_container.add_child(Control.new())
	
	# Volume controls section title
	var volume_title = Label.new()
	volume_title.text = "AUDIO SETTINGS"
	volume_title.add_theme_font_size_override("font_size", 20)
	volume_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	volume_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(volume_title)
	
	# Volume controls container
	var volume_container = VBoxContainer.new()
	volume_container.custom_minimum_size = Vector2(280, 160)
	volume_container.add_theme_constant_override("separation", 10)
	main_container.add_child(volume_container)
	
	# Get bus indices
	master_bus_idx = AudioServer.get_bus_index("Master")
	music_bus_idx = AudioServer.get_bus_index("Music")
	sfx_bus_idx = AudioServer.get_bus_index("SFX")
	dialog_bus_idx = AudioServer.get_bus_index("Dialog")
	
	# Create volume sliders
	master_volume_slider = _create_volume_control(volume_container, "Master Volume", master_bus_idx, _on_master_volume_changed)
	music_volume_slider = _create_volume_control(volume_container, "Music Volume", music_bus_idx, _on_music_volume_changed)
	sfx_volume_slider = _create_volume_control(volume_container, "SFX Volume", sfx_bus_idx, _on_sfx_volume_changed)
	dialog_volume_slider = _create_volume_control(volume_container, "Dialog Volume", dialog_bus_idx, _on_dialog_volume_changed)
	
	# Spacer before Twitch settings
	main_container.add_child(Control.new())
	
	# Twitch Integration section
	_setup_twitch_integration_section(main_container)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Press ESC to close menu"
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(instructions)
	
	# Start hidden
	visible = false

func _create_menu_button(text: String, color: Color) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 45)
	button.add_theme_font_size_override("font_size", 18)
	
	# Create style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	normal_style.border_width_left = 3
	normal_style.border_width_right = 3
	normal_style.border_width_top = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = color
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = color * Color(0.3, 0.3, 0.3, 1.0)
	hover_style.border_width_left = 5
	hover_style.border_width_right = 5
	hover_style.border_width_top = 5
	hover_style.border_width_bottom = 5
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = color * Color(0.5, 0.5, 0.5, 1.0)
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	return button

func _create_volume_control(parent: Node, label_text: String, bus_idx: int, callback: Callable) -> HSlider:
	# Container for this control
	var control_container = HBoxContainer.new()
	control_container.add_theme_constant_override("separation", 10)
	parent.add_child(control_container)
	
	# Label
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(100, 20)
	label.add_theme_font_size_override("font_size", 12)
	control_container.add_child(label)
	
	# Slider
	var slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(120, 20)
	
	# Set initial value from current bus
	var current_db = AudioServer.get_bus_volume_db(bus_idx)
	slider.value = db_to_linear(current_db)
	
	slider.value_changed.connect(callback)
	control_container.add_child(slider)
	
	# Percentage label
	var percent_label = Label.new()
	percent_label.name = label_text.replace(" ", "") + "Percent"
	percent_label.text = "%d%%" % int(slider.value * 100)
	percent_label.custom_minimum_size = Vector2(40, 20)
	percent_label.add_theme_font_size_override("font_size", 12)
	control_container.add_child(percent_label)
	
	return slider

func _setup_twitch_integration_section(parent: Node):
	# Twitch Integration section title
	var twitch_title = Label.new()
	twitch_title.text = "TWITCH INTEGRATION"
	twitch_title.add_theme_font_size_override("font_size", 20)
	twitch_title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	twitch_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(twitch_title)
	
	# Twitch config container
	var twitch_container = HBoxContainer.new()
	twitch_container.add_theme_constant_override("separation", 10)
	twitch_container.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(twitch_container)
	
	# Config button
	var config_button = _create_twitch_config_button()
	config_button.pressed.connect(_on_twitch_config_pressed)
	twitch_container.add_child(config_button)
	
	# Create and setup the dialog
	twitch_config_dialog = TwitchConfigDialog.new()
	twitch_config_dialog.set_current_channel(current_twitch_channel)
	twitch_config_dialog.channel_changed.connect(_on_twitch_channel_changed)
	add_child(twitch_config_dialog)

func _create_twitch_config_button() -> Button:
	var button = Button.new()
	button.text = "Twitch: %s" % current_twitch_channel
	button.custom_minimum_size = Vector2(250, 40)
	button.add_theme_font_size_override("font_size", 14)
	
	# Create clean style
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.6, 0.4, 0.9)  # Purple accent
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	
	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.25, 0.25, 0.9)
	hover_style.border_color = Color(0.8, 0.6, 1.0)  # Brighter purple on hover
	
	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.35, 0.35, 0.35, 0.9)
	
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	return button

func _on_twitch_config_pressed():
	if twitch_config_dialog:
		twitch_config_dialog.popup_centered()

func _on_twitch_channel_changed(new_channel: String):
	current_twitch_channel = new_channel
	
	# Save the new channel to settings
	if SettingsManager.instance:
		SettingsManager.instance.set_twitch_channel(new_channel)
	
	# Update button text
	_update_twitch_button_text()
	
	# Notify game controller about channel change
	if GameController.instance:
		GameController.instance._on_twitch_channel_changed(new_channel)

func _load_saved_channel():
	# Load channel from settings
	if SettingsManager.instance:
		current_twitch_channel = SettingsManager.instance.get_twitch_channel()
		print("📺 Loaded saved Twitch channel: %s" % current_twitch_channel)

func _sync_with_twitch_bot():
	# Get current channel from Twitch bot
	if GameController.instance and GameController.instance.twitch_bot:
		var bot = GameController.instance.twitch_bot
		if bot.has_method("get_current_channel"):
			current_twitch_channel = bot.get_current_channel()
		elif "channel_name" in bot:
			current_twitch_channel = bot.channel_name

func _update_twitch_button_text():
	# Find the Twitch config button more reliably
	var buttons = find_children("*", "Button", true, false)
	for button in buttons:
		if button.text.begins_with("Twitch:"):
			button.text = "Twitch: %s" % current_twitch_channel
			print("🔄 Updated button text to: %s" % button.text)
			return
	
	print("⚠️ Could not find Twitch Integration button to update")

func _on_master_volume_changed(value: float):
	AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(value))
	_update_volume_label("MasterVolumePercent", value)
	# Save settings
	if SettingsManager.instance:
		SettingsManager.instance.save_audio_settings()

func _on_music_volume_changed(value: float):
	AudioServer.set_bus_volume_db(music_bus_idx, linear_to_db(value))
	_update_volume_label("MusicVolumePercent", value)
	# Save settings
	if SettingsManager.instance:
		SettingsManager.instance.save_audio_settings()

func _on_sfx_volume_changed(value: float):
	AudioServer.set_bus_volume_db(sfx_bus_idx, linear_to_db(value))
	_update_volume_label("SFXVolumePercent", value)
	# Save settings
	if SettingsManager.instance:
		SettingsManager.instance.save_audio_settings()

func _on_dialog_volume_changed(value: float):
	AudioServer.set_bus_volume_db(dialog_bus_idx, linear_to_db(value))
	_update_volume_label("DialogVolumePercent", value)
	# Save settings
	if SettingsManager.instance:
		SettingsManager.instance.save_audio_settings()

func _on_resolution_selected(index: int):
	var resolutions = [
		Vector2i(3840, 2160),  # 4K
		Vector2i(2560, 1440),  # 1440p
		Vector2i(1920, 1080),  # 1080p
		Vector2i(1600, 900),
		Vector2i(1366, 768),
		Vector2i(1280, 720)    # 720p
	]
	
	if index >= 0 and index < resolutions.size():
		var res = resolutions[index]
		if SettingsManager.instance:
			SettingsManager.instance.set_resolution(res.x, res.y)

func _on_fullscreen_toggled(pressed: bool):
	if SettingsManager.instance:
		SettingsManager.instance.set_fullscreen(pressed)

func _on_vsync_toggled(pressed: bool):
	if SettingsManager.instance:
		SettingsManager.instance.set_vsync(pressed)

func _update_volume_label(label_name: String, value: float):
	# Find the label more reliably by searching through all children
	var labels = find_children(label_name, "Label", true, false)
	if labels.size() > 0:
		labels[0].text = "%d%%" % int(value * 100)

func _on_resume_pressed():
	hide()
	resume_requested.emit()

func _on_restart_pressed():
	hide()
	restart_requested.emit()

func _on_quit_pressed():
	quit_requested.emit()

func _on_debug_pressed():
	# Create debug panel window if it doesn't exist
	if not debug_panel_window:
		debug_panel_window = Control.new()
		debug_panel_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		debug_panel_window.z_index = 100
		debug_panel_window.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Work during pause
		debug_panel_window.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture mouse events
		call_deferred("add_child", debug_panel_window)
		
		# Dark background that allows click-through to panel
		var bg = ColorRect.new()
		bg.color = Color(0, 0, 0, 0.85)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Pass through to panel
		bg.z_index = -1  # Behind panel content
		debug_panel_window.add_child(bg)
		
		# Main container with margin
		var margin = MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 100)
		margin.add_theme_constant_override("margin_right", 100)
		margin.add_theme_constant_override("margin_top", 50)
		margin.add_theme_constant_override("margin_bottom", 50)
		margin.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow interaction with children
		debug_panel_window.add_child(margin)
		
		# Panel background
		var panel_bg = PanelContainer.new()
		panel_bg.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow interaction with children
		margin.add_child(panel_bg)
		
		# Vertical container for header and content
		var vbox = VBoxContainer.new()
		panel_bg.add_child(vbox)
		
		# Header with close button
		var header = HBoxContainer.new()
		vbox.add_child(header)
		
		var title = Label.new()
		title.text = "  🔧 DEBUG PANEL"
		title.add_theme_font_size_override("font_size", 20)
		header.add_child(title)
		
		# Spacer
		var spacer = Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(spacer)
		
		# Close button
		var close_btn = Button.new()
		close_btn.text = " ✕ "
		close_btn.add_theme_font_size_override("font_size", 20)
		close_btn.add_theme_color_override("font_color", Color.WHITE)
		close_btn.add_theme_color_override("font_hover_color", Color.RED)
		close_btn.custom_minimum_size = Vector2(40, 30)
		close_btn.tooltip_text = "Close debug panel"
		close_btn.pressed.connect(func(): 
			print("🔧 Closing debug panel...")
			debug_panel_window.visible = false
		)
		header.add_child(close_btn)
		
		# Create debug panel
		var DebugPanelClass = load("res://ui/debug_panel.gd")
		debug_panel = DebugPanelClass.new()
		debug_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
		vbox.add_child(debug_panel)
		
		debug_panel_window.visible = false  # Start hidden
	
	# Toggle visibility
	debug_panel_window.visible = !debug_panel_window.visible

func show_menu():
	visible = true
	# z_index = 8192 already ensures we're on top
	
	# Sync with current Twitch channel and update button
	_sync_with_twitch_bot()
	_update_twitch_button_text()
	
	# Update volume sliders to current values
	if master_volume_slider:
		var current_db = AudioServer.get_bus_volume_db(master_bus_idx)
		master_volume_slider.value = db_to_linear(current_db)
		_update_volume_label("MasterVolumePercent", master_volume_slider.value)
	
	if music_volume_slider:
		var current_db = AudioServer.get_bus_volume_db(music_bus_idx)
		music_volume_slider.value = db_to_linear(current_db)
		_update_volume_label("MusicVolumePercent", music_volume_slider.value)
	
	if sfx_volume_slider:
		var current_db = AudioServer.get_bus_volume_db(sfx_bus_idx)
		sfx_volume_slider.value = db_to_linear(current_db)
		_update_volume_label("SFXVolumePercent", sfx_volume_slider.value)
	
	if dialog_volume_slider:
		var current_db = AudioServer.get_bus_volume_db(dialog_bus_idx)
		dialog_volume_slider.value = db_to_linear(current_db)
		_update_volume_label("DialogVolumePercent", dialog_volume_slider.value)
	
	# Focus the resume button for keyboard navigation
	var scroll = get_child(1)  # Get scroll container (after background)
	if scroll and scroll.get_child_count() > 0:
		var main_cont = scroll.get_child(0)  # Get main container
		if main_cont and main_cont.get_child_count() > 2:
			var button_cont = main_cont.get_child(2)  # Get button container
			if button_cont and button_cont.get_child_count() > 0:
				button_cont.get_child(0).grab_focus()

func hide_menu():
	visible = false
