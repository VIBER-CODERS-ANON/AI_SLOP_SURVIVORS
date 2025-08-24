extends Node
class_name DebugManager

static var instance: DebugManager

signal debug_mode_toggled(enabled: bool)
signal entity_selected(entity_data: Dictionary)
signal entity_inspected(entity_data: Dictionary)

var debug_enabled: bool = false
var selected_entity_data: Dictionary = {}
var debug_ui: Control
var entity_selector: EntitySelector
var ability_trigger: DebugAbilityTrigger

# Debug state
var ai_paused: bool = false
var show_collision_shapes: bool = false
var show_pathfinding_grid: bool = false
var show_performance_stats: bool = false

func _ready():
	instance = self
	
	# Create debug subsystems
	entity_selector = EntitySelector.new()
	entity_selector.name = "EntitySelector"
	add_child(entity_selector)
	
	ability_trigger = DebugAbilityTrigger.new()
	ability_trigger.name = "DebugAbilityTrigger"
	add_child(ability_trigger)
	
	# Connect to input for F12 toggle
	set_process_input(true)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:
			toggle_debug_mode()
			get_viewport().set_input_as_handled()

func toggle_debug_mode():
	debug_enabled = !debug_enabled
	emit_signal("debug_mode_toggled", debug_enabled)
	
	if debug_enabled:
		_enter_debug_mode()
	else:
		_exit_debug_mode()

func _enter_debug_mode():
	print("[DebugManager] Entering debug mode")
	
	# Disable Twitch spawning
	if DebugSettings.instance:
		DebugSettings.instance.spawning_enabled = false
	
	# Clear all enemies
	if EnemyManager.instance:
		EnemyManager.instance.clear_all_enemies()
	if BossFactory.instance:
		BossFactory.instance.clear_all_bosses()
	
	# Reset player state for testing
	if GameController.instance and GameController.instance.player:
		GameController.instance.player.current_health = GameController.instance.player.max_health
	
	# Show debug UI
	_show_debug_ui()
	
	# Notify user
	if GameController.instance:
		GameController.instance.display_notification("Debug Mode Enabled", Color.CYAN)

func _exit_debug_mode():
	print("[DebugManager] Exiting debug mode")
	
	# Re-enable normal systems
	if DebugSettings.instance:
		DebugSettings.instance.spawning_enabled = true
	
	# Reset debug states
	ai_paused = false
	show_collision_shapes = false
	show_pathfinding_grid = false
	show_performance_stats = false
	
	# Hide debug UI
	_hide_debug_ui()
	
	# Clear selection
	selected_entity_data = {}
	
	# Notify user
	if GameController.instance:
		GameController.instance.display_notification("Debug Mode Disabled", Color.GRAY)

func _show_debug_ui():
	if not debug_ui:
		# Load debug UI scene
		var debug_ui_scene = load("res://systems/debug/debug_ui.tscn")
		if debug_ui_scene:
			debug_ui = debug_ui_scene.instantiate()
			# Find the UILayer canvas layer
			var ui_layer = get_tree().root.get_node_or_null("Game/UILayer")
			if not ui_layer:
				# Try alternate path
				ui_layer = get_tree().get_first_node_in_group("UILayer")
			if not ui_layer:
				# Try to find any CanvasLayer
				for child in get_tree().root.get_children():
					if child is CanvasLayer:
						ui_layer = child
						break
			
			if ui_layer and ui_layer is CanvasLayer:
				ui_layer.add_child(debug_ui)
			else:
				# Create our own CanvasLayer
				var canvas_layer = CanvasLayer.new()
				canvas_layer.name = "DebugUILayer"
				canvas_layer.layer = 10  # High layer to be on top
				get_tree().root.add_child(canvas_layer)
				canvas_layer.add_child(debug_ui)
			
			debug_ui.connect("spawn_requested", _on_spawn_requested)
			debug_ui.connect("entity_action", _on_entity_action)
			debug_ui.connect("system_control_changed", _on_system_control_changed)
	
	if debug_ui:
		debug_ui.visible = true

func _hide_debug_ui():
	if debug_ui:
		debug_ui.visible = false

# Debug UI callbacks
func _on_spawn_requested(enemy_id: String, position: Vector2, count: int, owner_name: String):
	if not SpawnManager.instance:
		return
	
	for i in count:
		var spawn_pos = position + Vector2(randf() * 50 - 25, randf() * 50 - 25)
		SpawnManager.instance.spawn_entity_by_id(enemy_id, spawn_pos, owner_name)

func _on_entity_action(action: String, params: Dictionary):
	match action:
		"select":
			select_entity_at_position(params.get("position", Vector2.ZERO))
		"kill":
			kill_selected_entity()
		"heal":
			heal_selected_entity(params.get("amount", 999999))
		"damage":
			damage_selected_entity(params.get("amount", 10))
		"trigger_ability":
			trigger_entity_ability(params.get("ability_name", ""))

func _on_system_control_changed(control: String, value: bool):
	match control:
		"ai_paused":
			set_ai_paused(value)
		"show_collision":
			set_show_collision_shapes(value)
		"show_pathfinding":
			set_show_pathfinding_grid(value)
		"show_performance":
			set_show_performance_stats(value)

# Entity selection and inspection
func select_entity_at_position(world_pos: Vector2):
	selected_entity_data = entity_selector.get_entity_at_position(world_pos)
	if not selected_entity_data.is_empty():
		emit_signal("entity_selected", selected_entity_data)
		_update_entity_inspector()

func _update_entity_inspector():
	if selected_entity_data.is_empty():
		return
	
	var inspection_data = _get_entity_inspection_data()
	emit_signal("entity_inspected", inspection_data)
	
	if debug_ui and debug_ui.has_method("update_entity_inspector"):
		debug_ui.update_entity_inspector(inspection_data)

func _get_entity_inspection_data() -> Dictionary:
	var data = {}
	
	if selected_entity_data.type == "minion":
		# Get minion data from EnemyManager
		var enemy_data = EnemyManager.instance.get_enemy_data(selected_entity_data.id)
		if enemy_data:
			data = {
				"name": enemy_data.get("enemy_type", "Unknown"),
				"id": selected_entity_data.id,
				"owner": enemy_data.get("owner_username", ""),
				"health": enemy_data.get("health", 0),
				"max_health": enemy_data.get("max_health", 0),
				"speed": enemy_data.get("speed", 0),
				"damage": enemy_data.get("damage", 0),
				"state": enemy_data.get("state", ""),
				"position": enemy_data.get("position", Vector2.ZERO),
				"abilities": enemy_data.get("abilities", [])
			}
	elif selected_entity_data.type == "boss":
		# Get boss data from node
		var boss_node = selected_entity_data.node
		if boss_node and boss_node.has_method("get_debug_data"):
			data = boss_node.get_debug_data()
		else:
			data = {
				"name": boss_node.name if boss_node else "Unknown",
				"health": boss_node.current_health if boss_node and "current_health" in boss_node else 0,
				"max_health": boss_node.max_health if boss_node and "max_health" in boss_node else 0
			}
	
	return data

# Entity actions
func kill_selected_entity():
	if selected_entity_data.is_empty():
		return
	
	if selected_entity_data.type == "minion":
		EnemyManager.instance.kill_enemy(selected_entity_data.id)
	elif selected_entity_data.type == "boss" and selected_entity_data.node:
		selected_entity_data.node.queue_free()
	
	selected_entity_data = {}

func heal_selected_entity(amount: float):
	if selected_entity_data.is_empty():
		return
	
	if selected_entity_data.type == "minion":
		EnemyManager.instance.heal_enemy(selected_entity_data.id, amount)
	elif selected_entity_data.type == "boss" and selected_entity_data.node:
		if selected_entity_data.node.has_method("heal"):
			selected_entity_data.node.heal(amount)
		elif "current_health" in selected_entity_data.node and "max_health" in selected_entity_data.node:
			selected_entity_data.node.current_health = min(selected_entity_data.node.current_health + amount, selected_entity_data.node.max_health)
	
	_update_entity_inspector()

func damage_selected_entity(amount: float):
	if selected_entity_data.is_empty():
		return
	
	if selected_entity_data.type == "minion":
		EnemyManager.instance.damage_enemy(selected_entity_data.id, amount, "debug")
	elif selected_entity_data.type == "boss" and selected_entity_data.node:
		if selected_entity_data.node.has_method("take_damage"):
			selected_entity_data.node.take_damage(amount)
		elif "current_health" in selected_entity_data.node:
			selected_entity_data.node.current_health -= amount
	
	_update_entity_inspector()

func trigger_entity_ability(ability_name: String):
	if selected_entity_data.is_empty() or ability_name.is_empty():
		return
	
	ability_trigger.trigger_ability(selected_entity_data, ability_name)

# System controls
func set_ai_paused(paused: bool):
	ai_paused = paused
	if EnemyManager.instance and EnemyManager.instance.has_method("set_ai_enabled"):
		EnemyManager.instance.set_ai_enabled(!paused)
	# TODO: Also pause boss AI when implemented

func set_show_collision_shapes(show: bool):
	show_collision_shapes = show
	get_tree().debug_collisions_hint = show

func set_show_pathfinding_grid(show: bool):
	show_pathfinding_grid = show
	# TODO: Implement pathfinding grid visualization

func set_show_performance_stats(show: bool):
	show_performance_stats = show
	# TODO: Implement performance stats overlay

# Utility functions
func clear_all_enemies():
	if EnemyManager.instance:
		EnemyManager.instance.clear_all_enemies()
	if BossFactory.instance:
		BossFactory.instance.clear_all_bosses()

func reset_session():
	clear_all_enemies()
	
	# Reset player
	if GameController.instance and GameController.instance.player:
		var player = GameController.instance.player
		player.current_health = player.max_health
		player.experience = 0
		player.level = 1
		# TODO: Reset abilities and items
	
	# Clear selection
	selected_entity_data = {}
	
	print("[DebugManager] Session reset")

# Check if debug mode is active
func is_debug_mode() -> bool:
	return debug_enabled
