extends Control
class_name EntityCounter

## Displays current count of alive entities on screen

var label: Label
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1  # Update 10 times per second

func _ready():
	# Set up positioning - center of screen, near top
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	position = Vector2(-100, 100)  # Centered horizontally, 100px from top
	
	# Create background panel
	var panel = PanelContainer.new()
	add_child(panel)
	
	# Style the panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0, 0, 0, 0.7)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(1, 0.3, 0.3)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	
	# Create container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	
	# Create label
	label = Label.new()
	label.text = "ENTITIES: 0"
	label.add_theme_font_size_override("font_size", 48)  # Much bigger
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 2)
	margin.add_child(label)

func _process(delta):
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_counter()

func _update_counter():
	# Count all alive entities
	var enemy_count = 0
	var player_count = 0
	var total_count = 0
	
	# Count enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("is_alive"):
			if enemy.is_alive:
				enemy_count += 1
		elif is_instance_valid(enemy):
			enemy_count += 1
	
	# Count player
	var players = get_tree().get_nodes_in_group("player")
	for player in players:
		if is_instance_valid(player):
			player_count += 1
	
	# Count all entities (includes both)
	var all_entities = get_tree().get_nodes_in_group("entities")
	for entity in all_entities:
		if is_instance_valid(entity):
			if entity.has_method("is_alive"):
				if entity.is_alive:
					total_count += 1
			else:
				total_count += 1
	
	# Update display with color coding
	if enemy_count > 100:
		label.text = "ENTITIES: %d" % enemy_count
		label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))  # Red for high count
	elif enemy_count > 50:
		label.text = "ENTITIES: %d" % enemy_count
		label.add_theme_color_override("font_color", Color(1, 0.6, 0.2))  # Orange for medium
	else:
		label.text = "ENTITIES: %d" % enemy_count
		label.add_theme_color_override("font_color", Color(0.2, 1, 0.2))  # Green for low
	
	# Add details on hover (tooltip)
	tooltip_text = "Enemies: %d\nPlayer: %d\nTotal: %d" % [enemy_count, player_count, total_count]