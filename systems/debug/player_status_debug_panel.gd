extends Control
class_name PlayerStatusDebugPanel

## PLAYER STATUS DEBUG PANEL
## Complete visibility and control over player stats, boons, and modifiers
## Integrates with DebugManager for comprehensive debugging

# References
var player_ref: Player
var boon_manager: Node

# UI Tabs
var tab_container: TabContainer
var core_stats_tab: Control
var active_boons_tab: Control
var modifiers_tab: Control

# Core Stats Controls
var health_input: LineEdit
var speed_input: LineEdit
var level_input: LineEdit
var xp_input: LineEdit
var pickup_input: LineEdit

# Boon Management
var active_boons_list: VBoxContainer
var add_boon_dropdown: OptionButton

# Display labels
var stats_labels: Dictionary = {}
var calculations_display: RichTextLabel

func _ready():
	custom_minimum_size = Vector2(480, 600)
	_setup_tabs()
	call_deferred("_connect_to_player")

func _setup_tabs():
	# Create tabbed interface
	tab_container = TabContainer.new()
	tab_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(tab_container)
	
	# Core Stats tab
	core_stats_tab = _create_core_stats_tab()
	tab_container.add_child(core_stats_tab)
	core_stats_tab.name = "Core Stats"
	
	# Active Boons tab
	active_boons_tab = _create_active_boons_tab()
	tab_container.add_child(active_boons_tab)
	active_boons_tab.name = "Active Boons"
	
	# Modifiers tab
	modifiers_tab = _create_modifiers_tab()
	tab_container.add_child(modifiers_tab)
	modifiers_tab.name = "Modifiers"

func _connect_to_player():
	player_ref = get_tree().get_first_node_in_group("player") as Player
	if player_ref:
		# Connect to player events for real-time updates
		if player_ref.has_signal("level_up"):
			player_ref.level_up.connect(_on_player_level_up)
		if player_ref.has_signal("experience_gained"):
			player_ref.experience_gained.connect(_on_player_xp_gained)

func _create_core_stats_tab() -> Control:
	var scroll = ScrollContainer.new()
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	scroll.add_child(container)
	
	# Health section
	var health_section = _create_stat_section("Health", container)
	var health_controls = HBoxContainer.new()
	
	health_input = LineEdit.new()
	health_input.placeholder_text = "Set health..."
	health_input.custom_minimum_size.x = 80
	
	var set_health_btn = Button.new()
	set_health_btn.text = "Set"
	set_health_btn.pressed.connect(_set_player_health)
	
	var damage_btn = Button.new()
	damage_btn.text = "Damage 10"
	damage_btn.pressed.connect(func(): 
		if player_ref and player_ref.has_method("take_damage"):
			player_ref.take_damage(10, null))  # Pass null instead of "debug" string
	
	var heal_btn = Button.new()
	heal_btn.text = "Heal Full"
	heal_btn.pressed.connect(func(): 
		if player_ref:
			player_ref.current_health = player_ref.max_health)
	
	health_controls.add_child(health_input)
	health_controls.add_child(set_health_btn)
	health_controls.add_child(damage_btn)
	health_controls.add_child(heal_btn)
	container.add_child(health_controls)
	
	# Move Speed section
	var speed_section = _create_stat_section("Move Speed", container)
	var speed_controls = HBoxContainer.new()
	
	speed_input = LineEdit.new()
	speed_input.placeholder_text = "Set speed..."
	speed_input.custom_minimum_size.x = 80
	
	var set_speed_btn = Button.new()
	set_speed_btn.text = "Set"
	set_speed_btn.pressed.connect(_set_player_speed)
	
	var reset_speed_btn = Button.new()
	reset_speed_btn.text = "Reset to Base"
	reset_speed_btn.pressed.connect(func():
		if player_ref:
			player_ref.bonus_move_speed = 0)
	
	speed_controls.add_child(speed_input)
	speed_controls.add_child(set_speed_btn)
	speed_controls.add_child(reset_speed_btn)
	container.add_child(speed_controls)
	
	# Pickup Range section
	var pickup_section = _create_stat_section("Pickup Range", container)
	var pickup_controls = HBoxContainer.new()
	
	pickup_input = LineEdit.new()
	pickup_input.placeholder_text = "Set range..."
	pickup_input.custom_minimum_size.x = 80
	
	var set_pickup_btn = Button.new()
	set_pickup_btn.text = "Set"
	set_pickup_btn.pressed.connect(_set_player_pickup_range)
	
	var reset_pickup_btn = Button.new()
	reset_pickup_btn.text = "Reset to Base"
	reset_pickup_btn.pressed.connect(func():
		if player_ref:
			player_ref.bonus_pickup_range = 0)
	
	pickup_controls.add_child(pickup_input)
	pickup_controls.add_child(set_pickup_btn)
	pickup_controls.add_child(reset_pickup_btn)
	container.add_child(pickup_controls)
	
	# Level/XP section
	var level_section = _create_stat_section("Level & Experience", container)
	var level_controls = HBoxContainer.new()
	
	level_input = LineEdit.new()
	level_input.placeholder_text = "Level..."
	level_input.custom_minimum_size.x = 60
	
	var set_level_btn = Button.new()
	set_level_btn.text = "Set Level"
	set_level_btn.pressed.connect(_set_player_level)
	
	xp_input = LineEdit.new()
	xp_input.placeholder_text = "XP..."
	xp_input.custom_minimum_size.x = 60
	
	var grant_xp_btn = Button.new()
	grant_xp_btn.text = "Grant XP"
	grant_xp_btn.pressed.connect(_grant_player_xp)
	
	level_controls.add_child(level_input)
	level_controls.add_child(set_level_btn)
	level_controls.add_child(xp_input)
	level_controls.add_child(grant_xp_btn)
	container.add_child(level_controls)
	
	# Combat Stats section
	var combat_header = Label.new()
	combat_header.text = "Combat Stats:"
	combat_header.add_theme_font_size_override("font_size", 14)
	container.add_child(combat_header)
	
	var combat_stats = VBoxContainer.new()
	container.add_child(combat_stats)
	
	# Create labels for each combat stat
	var combat_stat_names = [
		"crit_chance", "crit_multiplier", "damage_bonus",
		"damage_multiplier", "aoe_multiplier", "attack_speed"
	]
	
	for stat_name in combat_stat_names:
		var stat_label = Label.new()
		stats_labels[stat_name] = stat_label
		combat_stats.add_child(stat_label)
	
	return scroll

func _create_active_boons_tab() -> Control:
	var scroll = ScrollContainer.new()
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 5)
	scroll.add_child(container)
	
	# Header
	var header = Label.new()
	header.text = "Active Boons"
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)
	
	# Boons list container
	active_boons_list = VBoxContainer.new()
	active_boons_list.add_theme_constant_override("separation", 5)
	container.add_child(active_boons_list)
	
	# Add controls
	var controls = HBoxContainer.new()
	
	add_boon_dropdown = OptionButton.new()
	add_boon_dropdown.text = "Add Boon"
	add_boon_dropdown.custom_minimum_size.x = 200
	_populate_boon_dropdown()
	
	var add_btn = Button.new()
	add_btn.text = "Add Selected"
	add_btn.pressed.connect(_add_selected_boon)
	
	controls.add_child(add_boon_dropdown)
	controls.add_child(add_btn)
	container.add_child(controls)
	
	return scroll

func _create_modifiers_tab() -> Control:
	var scroll = ScrollContainer.new()
	var container = VBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	scroll.add_child(container)
	
	# Header
	var header = Label.new()
	header.text = "Stat Modifiers Breakdown"
	header.add_theme_font_size_override("font_size", 16)
	container.add_child(header)
	
	# Real-time calculation displays
	calculations_display = RichTextLabel.new()
	calculations_display.custom_minimum_size.y = 400
	calculations_display.fit_content = true
	calculations_display.bbcode_enabled = true
	container.add_child(calculations_display)
	
	return scroll

func _create_stat_section(title: String, container: Control) -> Label:
	var label = Label.new()
	label.add_theme_font_size_override("font_size", 14)
	stats_labels[title.to_lower().replace(" ", "_")] = label
	container.add_child(label)
	return label

func update_display():
	if not player_ref:
		_connect_to_player()
		if not player_ref:
			return
	
	_update_core_stats()
	_update_active_boons()
	_update_modifiers()

func _update_core_stats():
	if not player_ref:
		return
	
	# Health
	if stats_labels.has("health"):
		var health_text = "Health: %d/%d" % [
			player_ref.current_health,
			player_ref.max_health
		]
		if player_ref.get("bonus_health"):
			var base_health = player_ref.get("base_health") if player_ref.get("base_health") else player_ref.max_health
			health_text += " (%d + %d bonus)" % [
				base_health,
				player_ref.bonus_health
			]
		stats_labels["health"].text = health_text
	
	# Move Speed
	if stats_labels.has("move_speed"):
		var total_speed = player_ref.move_speed
		var base_speed = player_ref.get("base_move_speed") if player_ref.get("base_move_speed") else 210
		var bonus_speed = player_ref.get("bonus_move_speed") if player_ref.get("bonus_move_speed") else 0
		stats_labels["move_speed"].text = "Move Speed: %d (%d + %d bonus)" % [
			total_speed, base_speed, bonus_speed
		]
	
	# Pickup Range
	if stats_labels.has("pickup_range"):
		var total_range = player_ref.get("pickup_range") if player_ref.get("pickup_range") else 100
		var base_range = player_ref.get("base_pickup_range") if player_ref.get("base_pickup_range") else 100
		var bonus_range = player_ref.get("bonus_pickup_range") if player_ref.get("bonus_pickup_range") else 0
		stats_labels["pickup_range"].text = "Pickup Range: %d (%d + %d bonus)" % [
			total_range, base_range, bonus_range
		]
	
	# Level & XP
	if stats_labels.has("level_&_experience"):
		var level = player_ref.get("level") if player_ref.get("level") else 1
		var current_xp = player_ref.get("experience") if player_ref.get("experience") else 0
		var xp_needed = player_ref.get("experience_to_next_level") if player_ref.get("experience_to_next_level") else 100
		stats_labels["level_&_experience"].text = "Level: %d | XP: %d/%d" % [
			level, current_xp, xp_needed
		]
	
	# Combat Stats
	_update_combat_stats()

func _update_combat_stats():
	if not player_ref:
		return
	
	if stats_labels.has("crit_chance"):
		var crit_chance = player_ref.get("bonus_crit_chance") if player_ref.get("bonus_crit_chance") else 0
		stats_labels["crit_chance"].text = "• Crit Chance: %.1f%% (0%% + %.1f%% bonus)" % [
			crit_chance, crit_chance
		]
	
	if stats_labels.has("crit_multiplier"):
		var crit_mult = player_ref.get("bonus_crit_multiplier") if player_ref.get("bonus_crit_multiplier") else 0
		var total_mult = 2.0 + crit_mult
		stats_labels["crit_multiplier"].text = "• Crit Multiplier: %.1fx (2.0x + %.1fx bonus)" % [
			total_mult, crit_mult
		]
	
	if stats_labels.has("damage_bonus"):
		var damage_bonus = player_ref.get("bonus_damage") if player_ref.get("bonus_damage") else 0
		stats_labels["damage_bonus"].text = "• Damage Bonus: +%d flat" % damage_bonus
	
	if stats_labels.has("damage_multiplier"):
		var damage_mult = player_ref.get("bonus_damage_multiplier") if player_ref.get("bonus_damage_multiplier") else 1.0
		stats_labels["damage_multiplier"].text = "• Damage Multiplier: %.1fx" % damage_mult
	
	if stats_labels.has("aoe_multiplier"):
		var aoe = player_ref.get("area_of_effect") if player_ref.get("area_of_effect") else 1.0
		stats_labels["aoe_multiplier"].text = "• AoE Multiplier: %.1fx" % aoe
	
	if stats_labels.has("attack_speed"):
		var attack_speed = player_ref.get("bonus_attack_speed") if player_ref.get("bonus_attack_speed") else 1.0
		stats_labels["attack_speed"].text = "• Attack Speed: %.1fx" % attack_speed

func _update_active_boons():
	# Clear existing boon displays
	for child in active_boons_list.get_children():
		if child.has_meta("is_boon_display"):
			child.queue_free()
	
	# Get player's active boons
	if not player_ref or not player_ref.has_method("get_active_boons"):
		return
	
	var active_boons = player_ref.get_active_boons()
	for boon_data in active_boons:
		var boon_display = _create_boon_display(boon_data)
		active_boons_list.add_child(boon_display)

func _create_boon_display(boon_data: Dictionary) -> Control:
	var container = PanelContainer.new()
	container.set_meta("is_boon_display", true)
	
	var content = VBoxContainer.new()
	container.add_child(content)
	
	# Boon name and rarity
	var header = HBoxContainer.new()
	
	var name_label = Label.new()
	var rarity = boon_data.get("rarity") if boon_data.has("rarity") else "COMMON"
	var boon_name = boon_data.get("name") if boon_data.has("name") else "Unknown Boon"
	name_label.text = "[%s] %s" % [rarity, boon_name]
	name_label.modulate = _get_rarity_color(rarity)
	
	header.add_child(name_label)
	content.add_child(header)
	
	# Effect description
	var desc_label = Label.new()
	desc_label.text = boon_data.get("description") if boon_data.has("description") else "No description"
	desc_label.add_theme_font_size_override("font_size", 12)
	content.add_child(desc_label)
	
	# Controls
	var controls = HBoxContainer.new()
	
	var remove_btn = Button.new()
	remove_btn.text = "Remove"
	var boon_id = boon_data.get("id") if boon_data.has("id") else ""
	remove_btn.pressed.connect(_remove_boon.bind(boon_id))
	controls.add_child(remove_btn)
	
	if boon_data.has("can_stack") and boon_data.get("can_stack"):
		var add_stack_btn = Button.new()
		add_stack_btn.text = "Add Stack"
		add_stack_btn.pressed.connect(_add_boon_stack.bind(boon_id))
		controls.add_child(add_stack_btn)
	
	content.add_child(controls)
	return container

func _update_modifiers():
	if not calculations_display or not player_ref:
		return
	
	var text = ""
	
	# Move Speed breakdown
	var total_speed = player_ref.move_speed
	var base_speed = player_ref.get("base_move_speed") if player_ref.get("base_move_speed") else 210
	var bonus_speed = player_ref.get("bonus_move_speed") if player_ref.get("bonus_move_speed") else 0
	
	text += "[b]Move Speed (%d total):[/b]\n" % total_speed
	text += "• Base: %d\n" % base_speed
	text += "• Boon bonuses: +%d\n" % bonus_speed
	text += "• Equipment: +0\n"
	text += "• Temporary effects: +0\n\n"
	
	# Damage calculation (if we have weapon data)
	var base_weapon_damage = 25  # Default estimate
	var total_flat_bonus = player_ref.get("bonus_damage") if player_ref.get("bonus_damage") else 0
	var total_multiplier = player_ref.get("bonus_damage_multiplier") if player_ref.get("bonus_damage_multiplier") else 1.0
	var final_damage = (base_weapon_damage + total_flat_bonus) * total_multiplier
	
	text += "[b]Damage Calculation:[/b]\n"
	text += "• Base weapon: %d\n" % base_weapon_damage
	text += "• Flat bonuses: +%d\n" % total_flat_bonus
	text += "• Multipliers: %.1fx\n" % total_multiplier
	text += "• Final: (%d + %d) × %.1f = %d damage\n\n" % [
		base_weapon_damage, total_flat_bonus, total_multiplier, final_damage
	]
	
	# Critical hit calculations
	var crit_chance = player_ref.get("bonus_crit_chance") if player_ref.get("bonus_crit_chance") else 0
	var bonus_crit_mult = player_ref.get("bonus_crit_multiplier") if player_ref.get("bonus_crit_multiplier") else 0
	var crit_multiplier = 2.0 + bonus_crit_mult
	var expected_dps = final_damage * (1.0 + (crit_chance / 100.0) * (crit_multiplier - 1.0))
	
	text += "[b]Critical Hits:[/b]\n"
	text += "• Chance: %.1f%% (0%% base + %.1f%% boons)\n" % [crit_chance, crit_chance]
	text += "• Multiplier: %.1fx (2.0x base + %.1fx boons)\n" % [
		crit_multiplier, bonus_crit_mult
	]
	text += "• Expected DPS: %.1f\n\n" % expected_dps
	
	# AoE calculations
	var aoe = player_ref.get("area_of_effect") if player_ref.get("area_of_effect") else 1.0
	text += "[b]Area of Effect:[/b]\n"
	text += "• Base: 1.0x (100%%)\n"
	text += "• Boon multipliers: %.1fx (%.0f%%)\n" % [aoe, aoe * 100]
	text += "• Equipment: 1.0x\n"
	text += "• Final: %.1fx area\n" % aoe
	
	calculations_display.text = text

# Control callbacks
func _set_player_health():
	var value = health_input.text.to_float()
	if value > 0 and player_ref:
		player_ref.current_health = min(value, player_ref.max_health)
		health_input.clear()
		update_display()

func _set_player_speed():
	var value = speed_input.text.to_float()
	if value > 0 and player_ref:
		var base = player_ref.get("base_move_speed") if player_ref.get("base_move_speed") else 210
		player_ref.bonus_move_speed = value - base
		speed_input.clear()
		update_display()

func _set_player_pickup_range():
	var value = pickup_input.text.to_float()
	if value > 0 and player_ref:
		var base = player_ref.get("base_pickup_range") if player_ref.get("base_pickup_range") else 100
		player_ref.bonus_pickup_range = value - base
		pickup_input.clear()
		update_display()

func _set_player_level():
	var value = level_input.text.to_int()
	if value > 0 and player_ref and player_ref.has_method("set_level"):
		player_ref.set_level(value)
		level_input.clear()
		update_display()

func _grant_player_xp():
	var value = xp_input.text.to_int()
	if value > 0 and player_ref and player_ref.has_method("add_experience"):
		player_ref.add_experience(value)
		xp_input.clear()
		update_display()

func _populate_boon_dropdown():
	add_boon_dropdown.clear()
	add_boon_dropdown.add_item("Select Boon...")
	
	# Would need to load available boons from resource system
	# For now, add some examples
	add_boon_dropdown.add_item("Health Boost")
	add_boon_dropdown.add_item("Speed Boost")
	add_boon_dropdown.add_item("Damage Boost")
	add_boon_dropdown.add_item("Crit Chance")
	add_boon_dropdown.add_item("AoE Increase")

func _add_selected_boon():
	if add_boon_dropdown.selected <= 0:
		return
	
	# Would need to implement actual boon addition
	print("Adding boon: " + add_boon_dropdown.get_item_text(add_boon_dropdown.selected))
	update_display()

func _remove_boon(boon_id: String):
	if player_ref and player_ref.has_method("remove_debug_boon"):
		player_ref.remove_debug_boon(boon_id)
		update_display()

func _add_boon_stack(boon_id: String):
	if player_ref and player_ref.has_method("add_boon_stack"):
		player_ref.add_boon_stack(boon_id)
		update_display()

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_upper():
		"COMMON": return Color.WHITE
		"MAGIC": return Color.CYAN
		"RARE": return Color.YELLOW
		"UNIQUE": return Color.MAGENTA
		_: return Color.WHITE

# Event callbacks
func _on_player_level_up():
	update_display()

func _on_player_xp_gained(_amount: int):
	update_display()
