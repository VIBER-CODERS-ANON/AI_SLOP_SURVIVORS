extends MarginContainer
class_name ModularCommandsDisplay

## Modular command display that dynamically references game systems
## Automatically updates when commands or costs change

signal command_hovered(command: String, description: String)

@export_group("Layout")
@export var max_width: float = 400.0
@export var category_spacing: int = 15
@export var item_spacing: int = 5

var title_label: Label
var content_container: VBoxContainer
var categories: Dictionary = {}  # category_name -> VBoxContainer

func _ready():
	# Set up container
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("margin_left", 15)
	add_theme_constant_override("margin_right", 15)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_bottom", 10)
	
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)
	
	# Main content container
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", category_spacing)
	add_child(content_container)
	
	# Title
	title_label = _create_title("Commands")
	content_container.add_child(title_label)
	
	# Create categories
	_create_category("MXP Buffs")
	_create_category("Evolutions")
	_create_category("Basic Commands")
	
	# Set up refresh timer
	var refresh_timer = Timer.new()
	refresh_timer.wait_time = 1.0  # Refresh every second
	refresh_timer.timeout.connect(_refresh_commands)
	add_child(refresh_timer)
	refresh_timer.start()
	
	# Initial population
	_refresh_commands()

func _create_title(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))  # Gold
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label

func _create_category(category_name: String) -> HFlowContainer:
	# Category header
	var header = Label.new()
	header.text = category_name + ":"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	header.add_theme_constant_override("outline_size", 1)
	header.add_theme_color_override("font_outline_color", Color.BLACK)
	content_container.add_child(header)
	
	# Category content container with flow layout
	var flow_container = HFlowContainer.new()
	flow_container.name = category_name + "Container"
	flow_container.add_theme_constant_override("h_separation", 8)
	flow_container.add_theme_constant_override("v_separation", 4)
	content_container.add_child(flow_container)
	
	categories[category_name] = flow_container
	return flow_container

func _refresh_commands():
	# Clear existing commands
	for category in categories.values():
		for child in category.get_children():
			child.queue_free()
	
	# Populate MXP Buffs
	_populate_mxp_buffs()
	
	# Populate Evolutions
	_populate_evolutions()
	
	# Populate Basic Commands
	_populate_basic_commands()

func _populate_mxp_buffs():
	var container = categories.get("MXP Buffs")
	if not container:
		return
	
	# Get commands from MXPModifierManager
	if MXPModifierManager.instance:
		var mxp_commands = MXPModifierManager.instance.get_command_list()
		
		for cmd_data in mxp_commands:
			var cmd_label = _create_command_label(
				cmd_data.command, 
				"",  # No cost display for MXP buffs per user request
				cmd_data.description
			)
			container.add_child(cmd_label)

func _populate_evolutions():
	var container = categories.get("Evolutions")
	if not container:
		return
	
	# Get evolutions from EvolutionSystem
	var evolution_system = get_node_or_null("/root/Game/EvolutionSystem")
	if not evolution_system:
		# Try alternative path - look for it in GameController
		var game_controller = get_node_or_null("/root/Game")
		if game_controller:
			evolution_system = game_controller.get_node_or_null("EvolutionSystem")
	
	if evolution_system and evolution_system.has_method("get_evolution_list"):
		var evolutions = evolution_system.get_evolution_list()
		
		for evo_data in evolutions:
			var cmd_label = _create_command_label(
				"!evolve" + evo_data.command,
				"%d MXP" % evo_data.cost,
				evo_data.description
			)
			container.add_child(cmd_label)
	else:
		# If no get_evolution_list method, create labels directly from registry
		if evolution_system and "evolution_registry" in evolution_system:
			for evo_name in evolution_system.evolution_registry:
				var config = evolution_system.evolution_registry[evo_name]
				var cmd_label = _create_command_label(
					"!evolve" + evo_name,
					"%d MXP" % config.mxp_cost,
					config.description if "description" in config else ""
				)
				container.add_child(cmd_label)

func _populate_basic_commands():
	var container = categories.get("Basic Commands")
	if not container:
		return
	
	# Static basic commands
	var basic_commands = [
		{"cmd": "!explode", "desc": "Explode your rat"},
		{"cmd": "!fart", "desc": "Poison cloud"},
		{"cmd": "!boost", "desc": "Speed boost"},
		{"cmd": "!vote1/2/3", "desc": "Boss vote"}
	]
	
	for cmd_data in basic_commands:
		var cmd_label = _create_command_label(cmd_data.cmd, "", cmd_data.desc)
		container.add_child(cmd_label)

func _create_command_label(command: String, cost: String, description: String) -> Label:
	var label = Label.new()
	
	# Format text
	var text = command
	if not cost.is_empty():
		text += " (%s)" % cost
	
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 0.9))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Store metadata for hover
	label.set_meta("command", command)
	label.set_meta("description", description)
	
	# Add hover effect
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.gui_input.connect(_on_command_hover.bind(label))
	
	return label

func _on_command_hover(event: InputEvent, label: Label):
	if event is InputEventMouseMotion:
		var cmd = label.get_meta("command", "")
		var desc = label.get_meta("description", "")
		if not cmd.is_empty():
			command_hovered.emit(cmd, desc)

## Force refresh commands (call this when systems change)
func force_refresh():
	_refresh_commands()

## Add custom command to a category
func add_custom_command(category: String, command: String, cost: String = "", description: String = ""):
	var container = categories.get(category)
	if container:
		var cmd_label = _create_command_label(command, cost, description)
		container.add_child(cmd_label)
