extends VBoxContainer
class_name CommandsDisplay

## Display panel showing all available commands

var command_list: Dictionary = {
	"!explode": "Explode your rat (deals area damage)",
	"!fart": "Release a poison cloud (2 DPS)",
	# "!boost": "300% speed for 1 second (20s cooldown)", # DISABLED
	# "!evolvewoodlandjoe": "Evolve into Woodland Joe (3 MXP)", # TEMPORARILY DISABLED
	"!vote1/2/3": "Vote for boss (during vote)"
}

var title_label: Label
var commands_container: VBoxContainer

func _ready():
	# Set container properties
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 1)
	
	# Add semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)
	
	# Add padding
	set("theme_override_constants/margin_left", 10)
	set("theme_override_constants/margin_right", 10) 
	set("theme_override_constants/margin_top", 5)
	set("theme_override_constants/margin_bottom", 5)
	
	# Create title
	title_label = Label.new()
	title_label.text = "Commands:"
	title_label.add_theme_font_size_override("font_size", 16)  # Reduced to fit screen
	title_label.modulate = Color(1, 0.8, 0.2)  # Gold color
	add_child(title_label)
	
	# Create commands container
	commands_container = VBoxContainer.new()
	commands_container.add_theme_constant_override("separation", 0)
	add_child(commands_container)
	
	# Display initial commands
	_update_command_display()
	
	# Add MXP modifier commands
	_add_mxp_commands()

func add_command(command: String, description: String):
	command_list[command] = description
	_update_command_display()

func remove_command(command: String):
	command_list.erase(command)
	_update_command_display()

func _update_command_display():
	# Clear existing labels
	for child in commands_container.get_children():
		child.queue_free()
	
	# Create label for each command
	for cmd in command_list:
		var cmd_label = Label.new()
		cmd_label.text = cmd + " - " + command_list[cmd]
		cmd_label.add_theme_font_size_override("font_size", 14)  # Adjusted to fit screen
		cmd_label.modulate = Color(0.9, 0.9, 0.9, 0.9)
		cmd_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Wrap text if needed
		commands_container.add_child(cmd_label)

func _add_mxp_commands():
	# Wait for MXPModifierManager to be initialized
	await get_tree().process_frame
	
	if MXPModifierManager.instance:
		var mxp_commands = MXPModifierManager.instance.get_command_list()
		
		# Add section header
		command_list["---MXP COMMANDS---"] = "Use [n] for amount (e.g. !hp5)"
		
		# Add each MXP command
		for cmd_data in mxp_commands:
			var cmd = cmd_data.command
			var desc = cmd_data.description
			var cost = cmd_data.cost
			command_list[cmd] = "%s (%d MXP)" % [desc, cost]
		
		_update_command_display()
