extends MarginContainer
class_name ActionFeed

## Displays recent game events in a scrolling feed

@export var max_messages: int = 25  # Hard limit on messages shown
@export var message_lifetime: float = 10.0
@export var fade_time: float = 2.0

var message_container: VBoxContainer

func _ready():
	# Continue processing during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set up container properties
	add_theme_constant_override("separation", 2)
	custom_minimum_size = Vector2(400, 250)
	size = Vector2(400, 250)  # Force exact size
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_END
	
	# Add semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)  # Increased opacity for better visibility
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.show_behind_parent = true
	add_child(bg)
	move_child(bg, 0)
	
	# Add padding
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_bottom", 10)
	
	# Enable clipping to prevent overflow
	clip_contents = true
	
	# Create message container
	message_container = VBoxContainer.new()
	message_container.add_theme_constant_override("separation", 2)
	message_container.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(message_container)
	
	# Connect to global event bus if it exists
	if GameController.instance:
		_connect_to_events()
	
	print("📰 Action feed ready!")

func _connect_to_events():
	# We'll emit these events from various game systems
	# Connect to singleton signals when they're added
	pass

func add_message(text: String, color: Color = Color.WHITE, _icon: String = ""):
	# Create new message
	var message = Label.new()
	message.text = text
	message.add_theme_color_override("font_color", color)
	message.add_theme_font_size_override("font_size", 12)
	message.add_theme_constant_override("outline_size", 2)
	message.add_theme_color_override("font_outline_color", Color.BLACK)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Add to container
	message_container.add_child(message)
	message_container.move_child(message, 0)  # Add at top
	
	# Remove old messages if over limit
	var excess_count = message_container.get_child_count() - max_messages
	if excess_count > 0:
		# Collect nodes to remove
		var to_remove = []
		for i in range(excess_count):
			var child_index = message_container.get_child_count() - 1 - i
			to_remove.append(message_container.get_child(child_index))
		
		# Remove them
		for node in to_remove:
			message_container.remove_child(node)
			node.queue_free()
	
	# Start fade timer
	_start_message_timer(message)

func _start_message_timer(message: Label):
	# Wait for lifetime
	await get_tree().create_timer(message_lifetime - fade_time).timeout
	
	# Fade out
	if is_instance_valid(message):
		var tween = create_tween()
		
		# Kill tween when message is freed
		message.tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(message, "modulate:a", 0.0, fade_time)
		tween.tween_callback(message.queue_free)

# Convenience methods for common events
func player_killed_enemy(enemy_name: String):
	add_message("⚔️ Player killed " + enemy_name, Color(1, 0.8, 0))

func player_died(killer_name: String):
	add_message("💀 Player was killed by " + killer_name, Color(1, 0.2, 0.2))

func chatter_farted(chatter_name: String):
	add_message("💨 " + chatter_name + " farted!", Color(0.2, 1, 0.2))

func chatter_exploded(chatter_name: String):
	add_message("💥 " + chatter_name + " exploded!", Color(1, 0.5, 0))

func player_leveled_up(new_level: int):
	add_message("⬆️ Level " + str(new_level) + "!", Color(1, 1, 0))

func ability_unlocked(ability_name: String):
	add_message("🔓 Unlocked " + ability_name, Color(0.5, 0.5, 1))
