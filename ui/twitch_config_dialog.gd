extends AcceptDialog
class_name TwitchConfigDialog

## Clean dialog for configuring Twitch channel integration

signal channel_changed(new_channel: String)

var channel_input: LineEdit
var current_channel: String = "quin69"

func _ready():
	# Set up dialog properties
	title = "Twitch Integration Settings"
	popup_window = false
	
	# Create content
	_setup_ui()
	
	# Connect signals
	confirmed.connect(_on_accept)
	canceled.connect(_on_cancel)

func _setup_ui():
	# Create main container
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# Title label
	var title_label = Label.new()
	title_label.text = "Configure Twitch Channel"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)
	
	# Add some spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 10
	vbox.add_child(spacer1)
	
	# Channel input section
	var input_container = HBoxContainer.new()
	vbox.add_child(input_container)
	
	var channel_label = Label.new()
	channel_label.text = "Channel:"
	channel_label.custom_minimum_size.x = 80
	input_container.add_child(channel_label)
	
	channel_input = LineEdit.new()
	channel_input.text = current_channel
	channel_input.custom_minimum_size.x = 200
	channel_input.placeholder_text = "Enter channel name..."
	input_container.add_child(channel_input)
	
	# Add some spacing
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 8
	vbox.add_child(spacer2)
	
	# Info label
	var info_label = Label.new()
	info_label.text = "Enter channel name. Will reconnect automatically."
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(info_label)
	
	# Set dialog size to be more compact
	size = Vector2(350, 150)

func set_current_channel(channel: String):
	current_channel = channel
	if channel_input:
		channel_input.text = channel

func _on_accept():
	var new_channel = channel_input.text.strip_edges()
	if new_channel.is_empty():
		new_channel = "quin69"  # Default fallback
	
	if new_channel != current_channel:
		current_channel = new_channel
		channel_changed.emit(new_channel)
		print("🔧 Twitch channel changed to: %s" % new_channel)

func _on_cancel():
	# Reset input to current channel
	if channel_input:
		channel_input.text = current_channel