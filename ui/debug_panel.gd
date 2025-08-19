extends Control
class_name DebugPanel

## Debug panel with performance testing switches
## Allows toggling various systems to identify bottlenecks

var debug_settings: DebugSettings

func _ready():
	# Create or get debug settings
	if not DebugSettings.instance:
		debug_settings = DebugSettings.new()
		debug_settings.name = "DebugSettings"
		get_tree().root.add_child(debug_settings)
	else:
		debug_settings = DebugSettings.instance
	
	_setup_ui()

func _setup_ui():
	# Main container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.custom_minimum_size = Vector2(500, 600)
	add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "🔧 PERFORMANCE DEBUG PANEL"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	vbox.add_child(title)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# Quick presets
	var preset_label = Label.new()
	preset_label.text = "QUICK PRESETS:"
	preset_label.add_theme_font_size_override("font_size", 16)
	preset_label.add_theme_color_override("font_color", Color(1, 1, 0))
	vbox.add_child(preset_label)
	
	var preset_container = HBoxContainer.new()
	vbox.add_child(preset_container)
	
	var minimal_btn = Button.new()
	minimal_btn.text = "MINIMAL"
	minimal_btn.tooltip_text = "Turn off everything except core gameplay"
	minimal_btn.pressed.connect(_on_minimal_preset)
	preset_container.add_child(minimal_btn)
	
	var no_visuals_btn = Button.new()
	no_visuals_btn.text = "NO VISUALS"
	no_visuals_btn.tooltip_text = "Keep gameplay but remove visual extras"
	no_visuals_btn.pressed.connect(_on_no_visuals_preset)
	preset_container.add_child(no_visuals_btn)
	
	var no_ai_btn = Button.new()
	no_ai_btn.text = "NO AI"
	no_ai_btn.tooltip_text = "Disable all AI/movement for static testing"
	no_ai_btn.pressed.connect(_on_no_ai_preset)
	preset_container.add_child(no_ai_btn)
	
	var reset_btn = Button.new()
	reset_btn.text = "RESET ALL"
	reset_btn.tooltip_text = "Reset to default settings"
	reset_btn.pressed.connect(_on_reset_preset)
	preset_container.add_child(reset_btn)
	
	vbox.add_child(HSeparator.new())
	
	# Visual Systems
	_add_category(vbox, "🎨 VISUAL SYSTEMS", Color(0.5, 1, 0.5))
	_add_toggle(vbox, "Nameplates", "nameplates_enabled", "Hide all entity name labels")
	_add_toggle(vbox, "Health Bars", "health_bars_enabled", "Hide all health bars")
	_add_toggle(vbox, "Damage Numbers", "damage_numbers_enabled", "Hide floating damage text")
	_add_toggle(vbox, "Pillars/Pits", "pillars_pits_enabled", "Disable map obstacles")
	_add_toggle(vbox, "Lighting", "lighting_enabled", "Disable all lighting effects")
	_add_toggle(vbox, "Shadows", "shadows_enabled", "Disable all shadow rendering")
	_add_toggle(vbox, "Particles", "particles_enabled", "Disable all particle effects")
	_add_toggle(vbox, "Animations", "animations_enabled", "Disable sprite animations")
	_add_toggle(vbox, "Visual Effects", "visual_effects_enabled", "Disable screen effects")
	_add_toggle(vbox, "Post Processing", "post_processing_enabled", "Disable post-process effects")
	
	vbox.add_child(HSeparator.new())
	
	# Collision Systems
	_add_category(vbox, "💥 COLLISION SYSTEMS", Color(1, 0.5, 0.5))
	_add_toggle(vbox, "Player Collision", "player_collision_enabled", "Player phases through enemies")
	_add_toggle(vbox, "Mob-to-Mob Collision", "mob_to_mob_collision_enabled", "Enemies phase through each other")
	_add_toggle(vbox, "Projectile Collision", "projectile_collision_enabled", "Projectiles phase through targets")
	
	vbox.add_child(HSeparator.new())
	
	# AI/Movement Systems
	_add_category(vbox, "🤖 AI & MOVEMENT", Color(0.5, 0.5, 1))
	_add_toggle(vbox, "Mob Movement", "mob_movement_enabled", "Freeze all enemy movement")
	_add_toggle(vbox, "Mob AI", "mob_ai_enabled", "Disable enemy decision making")
	_add_toggle(vbox, "Pathfinding", "pathfinding_enabled", "Disable navigation pathfinding")
	_add_toggle(vbox, "Flocking Forces", "flocking_enabled", "Disable mob-to-mob forces")
	
	vbox.add_child(HSeparator.new())
	
	# Audio Systems
	_add_category(vbox, "🔊 AUDIO", Color(1, 1, 0.5))
	_add_toggle(vbox, "Sound Effects", "sfx_enabled", "Mute all sound effects")
	_add_toggle(vbox, "Music", "music_enabled", "Mute background music")
	_add_toggle(vbox, "Voice Lines", "voice_lines_enabled", "Mute character voices")
	
	vbox.add_child(HSeparator.new())
	
	# Game Systems
	_add_category(vbox, "⚙️ GAME SYSTEMS", Color(0.7, 0.7, 0.7))
	_add_toggle(vbox, "Ability System", "ability_system_enabled", "Disable all abilities")
	_add_toggle(vbox, "Weapon System", "weapon_system_enabled", "Disable player weapons")
	_add_toggle(vbox, "Enemy Spawning", "spawning_enabled", "Stop spawning new enemies")
	_add_toggle(vbox, "XP Drops", "xp_drops_enabled", "Disable XP orb drops")
	
	vbox.add_child(HSeparator.new())
	
	# Rendering
	_add_category(vbox, "🖥️ RENDERING", Color(1, 0.5, 1))
	# VSync removed - handled by SettingsManager in pause menu
	_add_toggle(vbox, "Physics Interpolation", "physics_interpolation_enabled", "Toggle physics smoothing")
	
	vbox.add_child(HSeparator.new())
	
	# Status display
	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = debug_settings.get_debug_string()
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)
	
	# Warning
	var warning = Label.new()
	warning.text = "⚠️ Changes take effect immediately. Some may require scene reload."
	warning.add_theme_font_size_override("font_size", 10)
	warning.add_theme_color_override("font_color", Color(1, 0.7, 0))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(warning)

func _add_category(parent: Node, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)

func _add_toggle(parent: Node, label_text: String, property: String, tooltip: String):
	var hbox = HBoxContainer.new()
	parent.add_child(hbox)
	
	var check = CheckBox.new()
	check.set_pressed_no_signal(debug_settings.get(property))
	check.tooltip_text = tooltip
	check.toggled.connect(func(pressed): _on_toggle_changed(property, pressed))
	hbox.add_child(check)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 200
	label.tooltip_text = tooltip
	hbox.add_child(label)

func _on_toggle_changed(property: String, value: bool):
	debug_settings.set(property, value)
	debug_settings.apply_settings()
	_update_status()

func _on_minimal_preset():
	debug_settings.set_minimal_mode()
	_refresh_all_toggles()
	_update_status()

func _on_no_visuals_preset():
	debug_settings.set_no_visuals_mode()
	_refresh_all_toggles()
	_update_status()

func _on_no_ai_preset():
	debug_settings.set_no_ai_mode()
	_refresh_all_toggles()
	_update_status()

func _on_reset_preset():
	debug_settings.reset_to_defaults()
	_refresh_all_toggles()
	_update_status()

func _refresh_all_toggles():
	# Update all checkboxes to match current settings
	var checkboxes = get_tree().get_nodes_in_group("debug_toggles")
	for cb in checkboxes:
		if cb is CheckBox:
			cb.queue_free()
	# Recreate UI
	for child in get_children():
		child.queue_free()
	_setup_ui()

func _update_status():
	var status_label = get_node_or_null("StatusLabel")
	if status_label:
		status_label.text = debug_settings.get_debug_string()
