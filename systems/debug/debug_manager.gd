extends Node
class_name DebugManager

## COMPREHENSIVE DEBUG SYSTEM
## Provides complete visibility and control over game state
## Integrates enemy spawning, inspection, and player status monitoring

static var instance: DebugManager

signal debug_mode_toggled(enabled: bool)

# Debug state
var is_debug_mode: bool = false
var debug_ui: Control
var debug_container: VBoxContainer

# Debug panels
var enemy_debug_panel: EnemyDebugPanel
var player_status_panel: PlayerStatusDebugPanel

# Selection state
var selected_entity_id: int = -1
var is_selection_enabled: bool = false

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_debug_ui()
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent):
	# F12 toggles debug mode (check key directly, no InputMap dependency)
	if event is InputEventKey and event.keycode == KEY_F12 and event.pressed:
		toggle_debug_mode()
		get_viewport().set_input_as_handled()
	
	# Click selection in debug mode
	if is_debug_mode and is_selection_enabled and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_handle_entity_click(event.position)

func toggle_debug_mode():
	is_debug_mode = !is_debug_mode
	
	if is_debug_mode:
		_enter_debug_mode()
	else:
		_exit_debug_mode()
	
	debug_mode_toggled.emit(is_debug_mode)

func _enter_debug_mode():
	# Pause normal spawning
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.set_process(false)
	
	# Show debug UI
	debug_ui.visible = true
	
	# Enable entity selection
	is_selection_enabled = true
	
	# Update displays
	_update_all_panels()
	
	print("🔧 Debug Mode ENABLED - Press F12 to exit")

func _exit_debug_mode():
	# Resume normal spawning
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.set_process(true)
	
	# Hide debug UI
	debug_ui.visible = false
	
	# Disable entity selection
	is_selection_enabled = false
	selected_entity_id = -1
	
	print("🔧 Debug Mode DISABLED")

func _create_debug_ui():
	# Create a CanvasLayer to ensure UI renders on screen, not in world
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DebugCanvasLayer"
	add_child(canvas_layer)
	
	# Main debug container
	debug_ui = Control.new()
	debug_ui.name = "DebugUI"
	debug_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_ui.mouse_filter = Control.MOUSE_FILTER_PASS  # Changed from IGNORE to PASS
	debug_ui.visible = false
	canvas_layer.add_child(debug_ui)
	
	# Main panel background
	var panel_bg = Panel.new()
	panel_bg.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel_bg.position = Vector2(10, 10)
	panel_bg.size = Vector2(500, 800)
	panel_bg.modulate.a = 0.95
	panel_bg.mouse_filter = Control.MOUSE_FILTER_PASS  # Ensure panel accepts mouse input
	debug_ui.add_child(panel_bg)
	
	# Scrollable container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.set_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.add_child(scroll)
	
	# Main vertical container
	debug_container = VBoxContainer.new()
	debug_container.add_theme_constant_override("separation", 10)
	scroll.add_child(debug_container)
	
	# Title
	var title = Label.new()
	title.text = "Debug Mode (F12)"
	title.add_theme_font_size_override("font_size", 20)
	# Labels don't have style overrides, only certain controls do
	debug_container.add_child(title)
	
	# Create panels
	_create_enemy_debug_panel()
	_create_player_status_panel()
	_create_system_controls()

func _create_enemy_debug_panel():
	# Enemy section header
	var enemy_header = _create_section_header("Enemy Controls")
	debug_container.add_child(enemy_header)
	
	# Enemy debug panel
	enemy_debug_panel = EnemyDebugPanel.new()
	enemy_debug_panel.entity_selected.connect(_on_entity_selected)
	debug_container.add_child(enemy_debug_panel)

func _create_player_status_panel():
	# Player section header
	var player_header = _create_collapsible_section("Player Status")
	debug_container.add_child(player_header)
	
	# Player status panel
	player_status_panel = PlayerStatusDebugPanel.new()
	player_header.add_child(player_status_panel)

func _create_system_controls():
	var system_section = _create_section_header("System")
	debug_container.add_child(system_section)
	
	var system_container = VBoxContainer.new()
	debug_container.add_child(system_container)
	
	# Checkboxes
	var disable_spawning = CheckBox.new()
	disable_spawning.text = "Disable Twitch Spawning"
	disable_spawning.toggled.connect(_on_spawning_toggled)
	system_container.add_child(disable_spawning)
	
	var show_collisions = CheckBox.new()
	show_collisions.text = "Show Collision Shapes"
	show_collisions.toggled.connect(_on_collisions_toggled)
	system_container.add_child(show_collisions)
	
	var show_flow_field = CheckBox.new()
	show_flow_field.text = "Show Flow Field"
	show_flow_field.toggled.connect(_on_flow_field_toggled)
	system_container.add_child(show_flow_field)
	
	var show_stats = CheckBox.new()
	show_stats.text = "Show Performance Stats"
	show_stats.toggled.connect(_on_stats_toggled)
	system_container.add_child(show_stats)
	
	# Buttons
	var button_container = HBoxContainer.new()
	system_container.add_child(button_container)
	
	var clear_all_btn = Button.new()
	clear_all_btn.text = "Clear All Enemies"
	clear_all_btn.pressed.connect(_clear_all_enemies)
	button_container.add_child(clear_all_btn)
	
	var reload_resources_btn = Button.new()
	reload_resources_btn.text = "Reload Resources"
	reload_resources_btn.pressed.connect(_reload_resources)
	button_container.add_child(reload_resources_btn)

func _create_section_header(text: String) -> Label:
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 16)
	header.modulate = Color(1.2, 1.2, 1.2)
	return header

func _create_collapsible_section(text: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	
	var header_btn = Button.new()
	header_btn.text = "▼ " + text
	header_btn.flat = true
	header_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header_btn.add_theme_font_size_override("font_size", 16)
	section.add_child(header_btn)
	
	var content = VBoxContainer.new()
	section.add_child(content)
	
	header_btn.pressed.connect(func():
		content.visible = !content.visible
		header_btn.text = ("▼ " if content.visible else "▶ ") + text
	)
	
	return section

func _update_all_panels():
	if enemy_debug_panel:
		enemy_debug_panel.update_display()
	if player_status_panel:
		player_status_panel.update_display()

func _handle_entity_click(screen_pos: Vector2):
	# Convert screen position to world position
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	
	var world_pos = camera.get_global_mouse_position()
	
	# Check enemies at position
	var clicked_enemy = _get_enemy_at_position(world_pos)
	if clicked_enemy >= 0:
		_on_entity_selected(clicked_enemy)

func _get_enemy_at_position(world_pos: Vector2) -> int:
	if not EnemyManager.instance:
		return -1
	
	var closest_id = -1
	var closest_dist = 50.0  # Click radius
	
	for i in range(EnemyManager.instance.positions.size()):
		if EnemyManager.instance.alive_flags[i] == 0:
			continue
		
		var dist = EnemyManager.instance.positions[i].distance_to(world_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_id = i
	
	return closest_id

func _on_entity_selected(entity_id: int):
	selected_entity_id = entity_id
	if enemy_debug_panel:
		enemy_debug_panel.set_selected_entity(entity_id)

# System control callbacks
func _on_spawning_toggled(enabled: bool):
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.set_process(!enabled)

func _on_collisions_toggled(enabled: bool):
	get_tree().debug_collisions_hint = enabled

func _on_flow_field_toggled(enabled: bool):
	# Would need custom visualization implementation
	pass

func _on_stats_toggled(enabled: bool):
	# Would need performance monitor implementation
	pass

func _clear_all_enemies():
	if not EnemyManager.instance:
		return
	
	for i in range(EnemyManager.instance.alive_flags.size()):
		if EnemyManager.instance.alive_flags[i] > 0:
			EnemyManager.instance.despawn_enemy(i)
	
	print("🗑️ Cleared all enemies")

func _reload_resources():
	if SpawnManager.instance:
		SpawnManager.instance._load_all_enemy_resources()
		print("🔄 Reloaded enemy resources")

# Public API
func spawn_enemy_at_cursor(enemy_id: String):
	var mouse_pos = get_viewport().get_camera_2d().get_global_mouse_position()
	spawn_enemy_at_position(enemy_id, mouse_pos)

func spawn_enemy_at_position(enemy_id: String, position: Vector2):
	if SpawnManager.instance:
		var result = SpawnManager.instance.spawn_entity_by_id(enemy_id, position, "debug")
		if result.success:
			print("🐛 Spawned %s at %s" % [enemy_id, position])
