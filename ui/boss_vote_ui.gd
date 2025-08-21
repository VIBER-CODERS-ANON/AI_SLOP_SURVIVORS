extends Control
class_name BossVoteUI

var vote_container: Control
var heading_text_label: Label
var heading_timer_label: Label
var boss_options: Array[Control] = []

var boss_vote_manager: BossVoteManager

func _ready():
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Keep updating during pause
	
	# Create UI structure
	_create_ui()
	
	# Connect to boss vote manager
	_connect_vote_manager()


func _create_ui():
	# Set to full screen
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Fully ignore input so underlying UI (pause menu) can receive it
	focus_mode = Control.FOCUS_NONE
	z_index = 500  # Below pause menu (which is 1000)
	
	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	
	# Main container
	vote_container = VBoxContainer.new()
	vote_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vote_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vote_container.add_theme_constant_override("separation", 20)
	add_child(vote_container)
	
	# Title row with inline countdown (heading in yellow, seconds in white)
	var heading_row = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	heading_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vote_container.add_child(heading_row)

	heading_text_label = Label.new()
	heading_text_label.text = "VOTE FOR THE NEXT BOSS!"
	heading_text_label.add_theme_font_size_override("font_size", 48)
	heading_text_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	heading_text_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	heading_text_label.add_theme_constant_override("shadow_offset_x", 2)
	heading_text_label.add_theme_constant_override("shadow_offset_y", 2)
	heading_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_row.add_child(heading_text_label)

	heading_timer_label = Label.new()
	heading_timer_label.text = ""
	heading_timer_label.add_theme_font_size_override("font_size", 48)
	heading_timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
	heading_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading_row.add_child(heading_timer_label)
	
	# Combined heading includes countdown; no separate timer label
	
	# Boss options container
	var options_container = HBoxContainer.new()
	options_container.add_theme_constant_override("separation", 30)
	options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vote_container.add_child(options_container)
	
	# Create 3 boss option panels
	for i in range(3):
		var option_panel = _create_boss_option_panel(i + 1)
		options_container.add_child(option_panel)
		boss_options.append(option_panel)
	
	# Instructions
	var instructions = Label.new()
	instructions.text = "Type !vote1, !vote2, or !vote3 in chat to vote!"
	instructions.add_theme_font_size_override("font_size", 24)
	instructions.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vote_container.add_child(instructions)

	# Ensure nothing in this UI captures mouse or focus
	_disable_all_input_capture()

func _disable_all_input_capture():
	_set_controls_recursive(self)

func _set_controls_recursive(node: Node):
	if node is Control:
		var ctrl := node as Control
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ctrl.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_set_controls_recursive(child)

func _create_boss_option_panel(number: int) -> Control:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 380)  # Slightly taller for buff info
	
	# Style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.2, 0.9)
	style.border_color = Color(0.3, 0.3, 0.5)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	# Add inner padding
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	# Vote command
	var command_label = Label.new()
	command_label.text = "!vote%d" % number
	command_label.add_theme_font_size_override("font_size", 36)
	command_label.add_theme_color_override("font_color", Color(1, 1, 0))
	command_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	command_label.add_theme_constant_override("shadow_offset_x", 2)
	command_label.add_theme_constant_override("shadow_offset_y", 2)
	command_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(command_label)
	
	# Boss image placeholder
	var image_rect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(200, 120)
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	vbox.add_child(image_rect)
	
	# Boss name
	var name_label = Label.new()
	name_label.text = "???"
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = ""
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc_label)
	
	# Boss Buff Label
	var buff_title_label = Label.new()
	buff_title_label.text = "💪 CHATTER BUFF:"
	buff_title_label.add_theme_font_size_override("font_size", 16)
	buff_title_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
	buff_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(buff_title_label)
	
	# Boss Buff Description
	var buff_label = Label.new()
	buff_label.text = ""
	buff_label.add_theme_font_size_override("font_size", 18)
	buff_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	buff_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	buff_label.custom_minimum_size = Vector2(240, 40)
	buff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(buff_label)
	
	# Vote count
	var vote_label = Label.new()
	vote_label.text = "VOTES: 0"
	vote_label.add_theme_font_size_override("font_size", 28)
	vote_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	vote_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vote_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	vote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(vote_label)
	
	# Store references
	panel.set_meta("vbox", vbox)
	
	return panel

func _connect_vote_manager():
	boss_vote_manager = BossVoteManager.instance
	if not boss_vote_manager:
		push_error("BossVoteUI: Could not find BossVoteManager instance!")
		return
	
	# Connect signals
	boss_vote_manager.vote_started.connect(_on_vote_started)
	boss_vote_manager.vote_updated.connect(_on_vote_updated)
	boss_vote_manager.vote_ended.connect(_on_vote_ended)

func _on_vote_started(vote_options: Array):
	visible = true
	
	# Safety check for boss_options
	if boss_options == null or boss_options.size() == 0:
		push_error("Boss options array is not initialized!")
		return
		
	# Update boss panels
	for i in range(boss_options.size()):
		if i < vote_options.size():
			var boss_id = vote_options[i]
			var boss_data = boss_vote_manager.boss_registry.get(boss_id, {})
			
			# Safety check for panel
			if boss_options[i] == null or not is_instance_valid(boss_options[i]):
				push_error("Boss option panel at index %d is null or invalid" % i)
				continue
				
			var panel = boss_options[i]
			var vbox = panel.get_meta("vbox")
			var image_rect = vbox.get_child(1)  # Image is second child
			var name_label = vbox.get_child(2)  # Name is third child
			var desc_label = vbox.get_child(3)  # Description is fourth child
			var _buff_title_label = vbox.get_child(4)  # Buff title is fifth child (not used)
			var buff_label = vbox.get_child(5)  # Buff description is sixth child
			var vote_label = vbox.get_child(6)  # Vote count is seventh child
			
			name_label.text = boss_data.get("display_name", "Unknown")
			desc_label.text = boss_data.get("description", "")
			
			# Get buff information from BossBuffManager
			if BossBuffManager.instance:
				var buff_data = BossBuffManager.instance.boss_buffs.get(boss_id, {})
				if buff_data:
					buff_label.text = buff_data.get("description", "Unknown buff")
				else:
					buff_label.text = "No buff data"
			else:
				buff_label.text = "Buff system not found"
			
			# Load boss image if available
			var icon_path = boss_data.get("icon_path", "")
			if icon_path != "" and ResourceLoader.exists(icon_path):
				var texture = load(icon_path)
				image_rect.texture = texture
			else:
				# Create placeholder texture for bosses without sprites
				var placeholder = ImageTexture.new()
				var image = Image.create(200, 120, false, Image.FORMAT_RGB8)
				image.fill(Color(0.2, 0.2, 0.3))
				placeholder.set_image(image)
				image_rect.texture = placeholder
			
			panel.visible = true
		else:
			if i < boss_options.size() and boss_options[i] != null and is_instance_valid(boss_options[i]):
				boss_options[i].visible = false
			else:
				push_warning("Boss option panel at index %d is null or invalid" % i)

func _on_vote_updated(votes: Dictionary):
	# Update vote counts
	var vote_options = boss_vote_manager.current_vote_options
	for i in range(vote_options.size()):
		if i < boss_options.size():
			var boss_id = vote_options[i]
			var vote_count = votes.get(boss_id, 0)
			
			var panel = boss_options[i]
			var vbox = panel.get_meta("vbox")
			var vote_label = vbox.get_child(6)  # Vote count is seventh child (after buff labels)
			vote_label.text = "VOTES: %d" % vote_count
			
			# Highlight leading option
			var max_votes = 0
			for v in votes.values():
				max_votes = max(max_votes, v)
			
			if vote_count > 0 and vote_count == max_votes:
				vote_label.add_theme_color_override("font_color", Color(0, 1, 0))
			else:
				vote_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))

func _on_vote_ended(winner_boss_id: String):
	print("🎬 Vote UI received vote_ended signal, winner: ", winner_boss_id)
	
	# Hide immediately
	visible = false
	print("🎬 Vote UI hidden immediately")

func _process(_delta):
	if visible and boss_vote_manager:
		var time_remaining = boss_vote_manager.get_voting_time_remaining()
		heading_timer_label.text = " %ds" % int(ceil(time_remaining))
