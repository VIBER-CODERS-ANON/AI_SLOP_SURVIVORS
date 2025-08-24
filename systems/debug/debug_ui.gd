extends Control
class_name DebugUI

signal spawn_requested(enemy_id: String, position: Vector2, count: int, owner: String)
signal entity_action(action: String, params: Dictionary)
signal system_control_changed(control: String, value: bool)

# UI References
@onready var panel_container: PanelContainer = $PanelContainer
@onready var main_vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer

# Enemy Spawner
@onready var enemy_dropdown: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/EnemySpawner/EnemyDropdown
@onready var spawn_at_cursor_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/EnemySpawner/SpawnButtons/SpawnAtCursor
@onready var spawn_at_player_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/EnemySpawner/SpawnButtons/SpawnAtPlayer
@onready var count_buttons: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/EnemySpawner/CountButtons

# Entity Inspector
@onready var inspector_label: Label = $PanelContainer/MarginContainer/VBoxContainer/EntityInspector/InspectorLabel
@onready var inspector_content: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/EntityInspector/InspectorContent
@onready var ability_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/EntityInspector/AbilityContainer
@onready var entity_actions: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/EntityInspector/EntityActions

# System Controls
@onready var pause_ai_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/SystemControls/PauseAI
@onready var show_collision_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/SystemControls/ShowCollision
@onready var show_pathfinding_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/SystemControls/ShowPathfinding
@onready var show_performance_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/SystemControls/ShowPerformance
@onready var clear_enemies_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/SystemControls/ActionButtons/ClearEnemies
@onready var reset_session_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/SystemControls/ActionButtons/ResetSession

var selected_enemy_id: String = ""
var spawn_count: int = 1
var current_entity_data: Dictionary = {}

func _ready():
	_setup_ui()
	_populate_enemy_dropdown()
	_connect_signals()
	
	# Ensure UI stays on top
	z_index = 100
	set_process_mode(Node.PROCESS_MODE_ALWAYS)  # Always process, even when paused
	
	# Start hidden
	visible = false

func _setup_ui():
	# Set up panel style
	if panel_container:
		panel_container.custom_minimum_size = Vector2(400, 600)
		panel_container.position = Vector2(10, 50)  # Top-left corner with margin

func _populate_enemy_dropdown():
	if not enemy_dropdown or not SpawnManager.instance:
		return
	
	enemy_dropdown.clear()
	
	# Add header
	enemy_dropdown.add_item("-- Select Enemy --")
	enemy_dropdown.set_item_disabled(0, true)
	enemy_dropdown.add_separator()
	
	# Add minions
	enemy_dropdown.add_item("=== MINIONS ===")
	enemy_dropdown.set_item_disabled(enemy_dropdown.get_item_count() - 1, true)
	
	var minions = SpawnManager.instance.get_enemies_by_category("minion")
	for enemy in minions:
		enemy_dropdown.add_item(enemy.display_name)
		enemy_dropdown.set_item_metadata(enemy_dropdown.get_item_count() - 1, enemy.enemy_id)
	
	enemy_dropdown.add_separator()
	
	# Add bosses
	enemy_dropdown.add_item("=== BOSSES ===")
	enemy_dropdown.set_item_disabled(enemy_dropdown.get_item_count() - 1, true)
	
	var bosses = SpawnManager.instance.get_enemies_by_category("boss")
	for enemy in bosses:
		enemy_dropdown.add_item(enemy.display_name)
		enemy_dropdown.set_item_metadata(enemy_dropdown.get_item_count() - 1, enemy.enemy_id)
	
	# Select first real enemy
	if enemy_dropdown.get_item_count() > 3:
		enemy_dropdown.select(3)
		selected_enemy_id = enemy_dropdown.get_item_metadata(3)

func _connect_signals():
	# Enemy spawner
	if enemy_dropdown:
		enemy_dropdown.item_selected.connect(_on_enemy_selected)
	
	if spawn_at_cursor_btn:
		spawn_at_cursor_btn.pressed.connect(_on_spawn_at_cursor)
	if spawn_at_player_btn:
		spawn_at_player_btn.pressed.connect(_on_spawn_at_player)
	
	# Count buttons
	if count_buttons:
		for child in count_buttons.get_children():
			if child is Button:
				child.pressed.connect(_on_count_button_pressed.bind(child.text.to_int()))
	
	# Entity actions
	if entity_actions:
		for child in entity_actions.get_children():
			if child is Button:
				match child.name:
					"KillSelected":
						child.pressed.connect(func(): entity_action.emit("kill", {}))
					"HealFull":
						child.pressed.connect(func(): entity_action.emit("heal", {"amount": 999999}))
					"Damage10":
						child.pressed.connect(func(): entity_action.emit("damage", {"amount": 10}))
	
	# System controls
	if pause_ai_check:
		pause_ai_check.toggled.connect(func(pressed): system_control_changed.emit("ai_paused", pressed))
	if show_collision_check:
		show_collision_check.toggled.connect(func(pressed): system_control_changed.emit("show_collision", pressed))
	if show_pathfinding_check:
		show_pathfinding_check.toggled.connect(func(pressed): system_control_changed.emit("show_pathfinding", pressed))
	if show_performance_check:
		show_performance_check.toggled.connect(func(pressed): system_control_changed.emit("show_performance", pressed))
	
	if clear_enemies_btn:
		clear_enemies_btn.pressed.connect(_on_clear_enemies)
	if reset_session_btn:
		reset_session_btn.pressed.connect(_on_reset_session)

func _on_enemy_selected(index: int):
	var metadata = enemy_dropdown.get_item_metadata(index)
	if metadata:
		selected_enemy_id = metadata

func _on_count_button_pressed(count: int):
	spawn_count = count
	# Update button visuals to show selection
	if count_buttons:
		for child in count_buttons.get_children():
			if child is Button:
				child.modulate = Color.WHITE if child.text.to_int() != count else Color.CYAN

func _on_spawn_at_cursor():
	if selected_enemy_id.is_empty():
		return
	
	var mouse_pos = get_global_mouse_position()
	spawn_requested.emit(selected_enemy_id, mouse_pos, spawn_count, "debug_user")

func _on_spawn_at_player():
	if selected_enemy_id.is_empty():
		return
	
	var player_pos = Vector2.ZERO
	if GameController.instance and GameController.instance.player:
		player_pos = GameController.instance.player.global_position
	
	spawn_requested.emit(selected_enemy_id, player_pos, spawn_count, "debug_user")

func _on_clear_enemies():
	if DebugManager.instance:
		DebugManager.instance.clear_all_enemies()

func _on_reset_session():
	if DebugManager.instance:
		DebugManager.instance.reset_session()

func _input(event):
	# Handle entity selection with mouse click
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT):
			# Shift+Click to select entity
			var world_pos = get_global_mouse_position()
			entity_action.emit("select", {"position": world_pos})
			get_viewport().set_input_as_handled()

# Update entity inspector with entity data
func update_entity_inspector(entity_data: Dictionary):
	current_entity_data = entity_data
	
	if not inspector_label or not inspector_content:
		return
	
	if entity_data.is_empty():
		inspector_label.text = "No Entity Selected"
		inspector_content.text = ""
		_clear_ability_buttons()
		return
	
	# Update header
	inspector_label.text = "Selected: %s #%s" % [entity_data.get("name", "Unknown"), entity_data.get("id", "?")]
	
	# Update content
	var content = ""
	if entity_data.has("owner") and not entity_data.owner.is_empty():
		content += "Owner: %s\n" % entity_data.owner
	
	content += "Health: %d/%d\n" % [entity_data.get("health", 0), entity_data.get("max_health", 0)]
	content += "Speed: %.1f\n" % entity_data.get("speed", 0)
	content += "Damage: %.1f\n" % entity_data.get("damage", 0)
	
	if entity_data.has("state"):
		content += "State: %s\n" % entity_data.state
	
	if entity_data.has("position"):
		content += "Position: (%.0f, %.0f)" % [entity_data.position.x, entity_data.position.y]
	
	inspector_content.text = content
	
	# Update ability buttons
	_update_ability_buttons(entity_data.get("abilities", []))

func _clear_ability_buttons():
	if not ability_container:
		return
	
	for child in ability_container.get_children():
		if child.name != "AbilitiesLabel":  # Keep the label
			child.queue_free()

func _update_ability_buttons(abilities: Array):
	_clear_ability_buttons()
	
	if not ability_container or abilities.is_empty():
		return
	
	for ability in abilities:
		var btn = Button.new()
		btn.text = "Trigger %s" % ability
		btn.custom_minimum_size.y = 30
		btn.pressed.connect(func(): entity_action.emit("trigger_ability", {"ability_name": ability}))
		ability_container.add_child(btn)

# Show/hide the debug UI
func show_debug_ui():
	visible = true

func hide_debug_ui():
	visible = false
