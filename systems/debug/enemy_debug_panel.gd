extends Control
class_name EnemyDebugPanel

## ENEMY DEBUG PANEL  
## Spawning, inspection, and control of enemies
## Part of the comprehensive debug system

signal entity_selected(entity_id: int)

# UI elements
var spawn_dropdown: OptionButton
var spawn_count_btns: Array[Button] = []
var inspector_container: VBoxContainer
var selected_label: Label
var stats_container: VBoxContainer
var abilities_container: VBoxContainer

# State
var selected_entity_id: int = -1

func _ready():
	custom_minimum_size = Vector2(460, 400)
	_create_ui()

func _create_ui():
	var main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 10)
	add_child(main_container)
	
	# Enemy Spawner section
	_create_spawner_section(main_container)
	
	# Enemy Inspector section
	_create_inspector_section(main_container)

func _create_spawner_section(container: Control):
	var spawner_container = VBoxContainer.new()
	container.add_child(spawner_container)
	
	# Spawner header
	var header = Label.new()
	header.text = "Enemy Spawner"
	header.add_theme_font_size_override("font_size", 14)
	spawner_container.add_child(header)
	
	# Enemy dropdown
	var dropdown_container = HBoxContainer.new()
	spawner_container.add_child(dropdown_container)
	
	var dropdown_label = Label.new()
	dropdown_label.text = "Enemy: "
	dropdown_container.add_child(dropdown_label)
	
	spawn_dropdown = OptionButton.new()
	spawn_dropdown.custom_minimum_size.x = 200
	_populate_enemy_dropdown()
	dropdown_container.add_child(spawn_dropdown)
	
	# Spawn buttons
	var spawn_btns_container = HBoxContainer.new()
	spawner_container.add_child(spawn_btns_container)
	
	var spawn_cursor_btn = Button.new()
	spawn_cursor_btn.text = "Spawn at Cursor"
	spawn_cursor_btn.pressed.connect(_spawn_at_cursor)
	spawn_btns_container.add_child(spawn_cursor_btn)
	
	var spawn_player_btn = Button.new()
	spawn_player_btn.text = "Spawn at Player"
	spawn_player_btn.pressed.connect(_spawn_at_player)
	spawn_btns_container.add_child(spawn_player_btn)
	
	# Count buttons
	var count_container = HBoxContainer.new()
	spawner_container.add_child(count_container)
	
	var count_label = Label.new()
	count_label.text = "Count: "
	count_container.add_child(count_label)
	
	for count in [1, 10, 100]:
		var count_btn = Button.new()
		count_btn.text = str(count)
		count_btn.toggle_mode = true
		count_btn.pressed.connect(_on_count_selected.bind(count, count_btn))
		count_container.add_child(count_btn)
		spawn_count_btns.append(count_btn)
	
	# Select first count by default
	if spawn_count_btns.size() > 0:
		spawn_count_btns[0].button_pressed = true

func _create_inspector_section(container: Control):
	inspector_container = VBoxContainer.new()
	inspector_container.add_theme_constant_override("separation", 5)
	container.add_child(inspector_container)
	
	# Inspector header
	var header = Label.new()
	header.text = "Inspector - Click enemy to select"
	header.add_theme_font_size_override("font_size", 14)
	inspector_container.add_child(header)
	
	# Selected entity info
	selected_label = Label.new()
	selected_label.text = "No entity selected"
	selected_label.add_theme_font_size_override("font_size", 12)
	inspector_container.add_child(selected_label)
	
	# Stats container
	stats_container = VBoxContainer.new()
	stats_container.visible = false
	inspector_container.add_child(stats_container)
	
	# Create stat controls
	_create_stat_control("Health", stats_container, "health")
	_create_stat_control("Speed", stats_container, "speed")
	_create_stat_control("Damage", stats_container, "damage")
	
	# Abilities container
	abilities_container = VBoxContainer.new()
	abilities_container.visible = false
	inspector_container.add_child(abilities_container)
	
	var abilities_header = Label.new()
	abilities_header.text = "Abilities:"
	abilities_header.add_theme_font_size_override("font_size", 12)
	abilities_container.add_child(abilities_header)

func _create_stat_control(stat_name: String, container: Control, stat_key: String):
	var stat_container = VBoxContainer.new()
	container.add_child(stat_container)
	
	# Stat label
	var stat_label = Label.new()
	stat_label.name = stat_key + "_label"
	stat_label.text = "%s: --" % stat_name
	stat_container.add_child(stat_label)
	
	# Control buttons
	var controls = HBoxContainer.new()
	stat_container.add_child(controls)
	
	var input = LineEdit.new()
	input.name = stat_key + "_input"
	input.placeholder_text = "Set..."
	input.custom_minimum_size.x = 60
	controls.add_child(input)
	
	var set_btn = Button.new()
	set_btn.text = "Set"
	set_btn.pressed.connect(_set_entity_stat.bind(stat_key, input))
	controls.add_child(set_btn)
	
	if stat_key == "health":
		var kill_btn = Button.new()
		kill_btn.text = "Kill"
		kill_btn.pressed.connect(_kill_selected_entity)
		controls.add_child(kill_btn)

func _populate_enemy_dropdown():
	spawn_dropdown.clear()
	spawn_dropdown.add_item("Select Enemy...")
	
	# Load from SpawnManager if available
	if SpawnManager.instance:
		for enemy_id in SpawnManager.instance.loaded_resources:
			var resource = SpawnManager.instance.loaded_resources[enemy_id]
			spawn_dropdown.add_item(resource.display_name)
			spawn_dropdown.set_item_metadata(spawn_dropdown.get_item_count() - 1, enemy_id)
	else:
		# Fallback to hardcoded list
		var enemies = ["rat", "succubus", "woodland_joe"]
		for enemy in enemies:
			spawn_dropdown.add_item(enemy.capitalize())
			spawn_dropdown.set_item_metadata(spawn_dropdown.get_item_count() - 1, enemy)

func update_display():
	if selected_entity_id < 0:
		selected_label.text = "No entity selected"
		stats_container.visible = false
		abilities_container.visible = false
		return
	
	# Get entity data
	var data = _get_entity_data(selected_entity_id)
	if not data:
		selected_label.text = "Invalid entity"
		stats_container.visible = false
		abilities_container.visible = false
		return
	
	# Update selection label
	selected_label.text = "Selected: %s #%d" % [data.name, selected_entity_id]
	if data.owner != "":
		selected_label.text += "\nOwner: %s" % data.owner
	
	# Update stats
	stats_container.visible = true
	_update_stat_display("health", "%d/%d" % [data.health, data.max_health])
	_update_stat_display("speed", str(data.speed))
	_update_stat_display("damage", str(data.damage))
	
	# Update abilities
	_update_abilities_display(data.abilities)

func _update_stat_display(stat_key: String, value: String):
	var label = stats_container.get_node_or_null(stat_key + "_label")
	if label:
		var stat_name = stat_key.capitalize()
		label.text = "%s: %s" % [stat_name, value]

func _update_abilities_display(abilities: Array):
	# Clear old ability displays
	for child in abilities_container.get_children():
		if child.has_meta("is_ability"):
			child.queue_free()
	
	if abilities.is_empty():
		abilities_container.visible = false
		return
	
	abilities_container.visible = true
	
	for ability in abilities:
		var ability_container = HBoxContainer.new()
		ability_container.set_meta("is_ability", true)
		
		var ability_label = Label.new()
		var cooldown_text = "Ready" if ability.cooldown_remaining <= 0 else "CD: %.1fs" % ability.cooldown_remaining
		ability_label.text = "• %s (%s)" % [ability.name, cooldown_text]
		ability_container.add_child(ability_label)
		
		var trigger_btn = Button.new()
		trigger_btn.text = "Trigger"
		trigger_btn.disabled = ability.cooldown_remaining > 0
		trigger_btn.pressed.connect(_trigger_ability.bind(ability.id))
		ability_container.add_child(trigger_btn)
		
		abilities_container.add_child(ability_container)

func set_selected_entity(entity_id: int):
	selected_entity_id = entity_id
	update_display()

func _get_entity_data(entity_id: int) -> Dictionary:
	if not EnemyManager.instance or entity_id < 0:
		return {}
	
	if entity_id >= EnemyManager.instance.alive_flags.size():
		return {}
	
	if EnemyManager.instance.alive_flags[entity_id] == 0:
		return {}
	
	var data = {
		"name": _get_entity_type_name(entity_id),
		"owner": "",
		"health": 0,
		"max_health": 0,
		"speed": 0,
		"damage": 0,
		"abilities": []
	}
	
	# Get basic stats
	if entity_id < EnemyManager.instance.healths.size():
		data.health = EnemyManager.instance.healths[entity_id]
		data.max_health = EnemyManager.instance.max_healths[entity_id]
		data.speed = EnemyManager.instance.move_speeds[entity_id]
		data.damage = EnemyManager.instance.attack_damages[entity_id]
	
	# Get owner
	if entity_id < EnemyManager.instance.chatter_usernames.size():
		data.owner = EnemyManager.instance.chatter_usernames[entity_id]
	
	# Get abilities
	if AbilityExecutor.instance and AbilityExecutor.instance.active_abilities.has(entity_id):
		for ability_res in AbilityExecutor.instance.active_abilities[entity_id]:
			var cooldown_remaining = 0.0
			if AbilityExecutor.instance.entity_cooldowns.has(entity_id):
				cooldown_remaining = AbilityExecutor.instance.entity_cooldowns[entity_id].get(ability_res.ability_id, 0.0)
			
			data.abilities.append({
				"id": ability_res.ability_id,
				"name": ability_res.display_name,
				"cooldown_remaining": cooldown_remaining
			})
	
	return data

func _get_entity_type_name(entity_id: int) -> String:
	if not EnemyManager.instance or entity_id >= EnemyManager.instance.entity_types.size():
		return "Unknown"
	
	var type_id = EnemyManager.instance.entity_types[entity_id]
	match type_id:
		0: return "Rat"
		1: return "Succubus"
		2: return "Woodland Joe"
		_: return "Unknown Type %d" % type_id

# Spawning functions
func _spawn_at_cursor():
	var count = _get_selected_count()
	var enemy_id = _get_selected_enemy_id()
	if enemy_id == "":
		return
	
	var mouse_pos = get_viewport().get_camera_2d().get_global_mouse_position()
	_spawn_enemies(enemy_id, mouse_pos, count)

func _spawn_at_player():
	var count = _get_selected_count()
	var enemy_id = _get_selected_enemy_id()
	if enemy_id == "":
		return
	
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("No player found")
		return
	
	_spawn_enemies(enemy_id, player.global_position, count)

func _spawn_enemies(enemy_id: String, position: Vector2, count: int):
	for i in count:
		var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		var spawn_pos = position + offset
		
		if DebugManager.instance:
			DebugManager.instance.spawn_enemy_at_position(enemy_id, spawn_pos)

func _get_selected_enemy_id() -> String:
	if spawn_dropdown.selected <= 0:
		return ""
	return spawn_dropdown.get_item_metadata(spawn_dropdown.selected)

func _get_selected_count() -> int:
	for i in range(spawn_count_btns.size()):
		if spawn_count_btns[i].button_pressed:
			return [1, 10, 100][i]
	return 1

func _on_count_selected(count: int, btn: Button):
	# Deselect other buttons
	for other_btn in spawn_count_btns:
		if other_btn != btn:
			other_btn.button_pressed = false

# Inspector functions
func _set_entity_stat(stat_key: String, input: LineEdit):
	if selected_entity_id < 0 or not EnemyManager.instance:
		return
	
	var value = input.text.to_float()
	if value <= 0:
		return
	
	match stat_key:
		"health":
			if selected_entity_id < EnemyManager.instance.healths.size():
				EnemyManager.instance.healths[selected_entity_id] = min(value, EnemyManager.instance.max_healths[selected_entity_id])
		"speed":
			if selected_entity_id < EnemyManager.instance.move_speeds.size():
				EnemyManager.instance.move_speeds[selected_entity_id] = value
		"damage":
			if selected_entity_id < EnemyManager.instance.attack_damages.size():
				EnemyManager.instance.attack_damages[selected_entity_id] = value
	
	input.clear()
	update_display()

func _kill_selected_entity():
	if selected_entity_id < 0 or not EnemyManager.instance:
		return
	
	EnemyManager.instance.despawn_enemy(selected_entity_id)
	selected_entity_id = -1
	update_display()

func _trigger_ability(ability_id: String):
	if selected_entity_id < 0 or not AbilityExecutor.instance:
		return
	
	AbilityExecutor.instance.execute_ability_by_id(selected_entity_id, ability_id, {})