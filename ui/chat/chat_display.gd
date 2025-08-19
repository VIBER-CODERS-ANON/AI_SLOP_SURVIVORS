extends PanelContainer
class_name ChatDisplay

## Chat display UI that shows Twitch chat messages in the top-right corner

@export var max_messages: int = 7  # Reduced to prevent lag
@export var message_lifetime: float = 20.0  # Reduced lifetime
@export var fade_duration: float = 1.0

var message_container: VBoxContainer
var scroll_container: ScrollContainer
var message_scene = preload("res://ui/chat/chat_message.tscn")

# Message queue
var active_messages: Array = []
var last_message_time: float = 0.0
var message_cooldown: float = 0.1  # Minimum time between messages
var process_timer: float = 0.0  # Only process every 0.25 seconds

func _ready():
	# Continue processing during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Set up UI structure
	custom_minimum_size = Vector2(400, 300)
	
	# Create scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.follow_focus = true
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll_container)
	
	# Create message container
	message_container = VBoxContainer.new()
	message_container.name = "MessageContainer"
	message_container.add_theme_constant_override("separation", 4)
	scroll_container.add_child(message_container)
	
	# Style the panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

## Add a chat message to the display
func add_message(username: String, message: String, color: Color = Color.WHITE):
	# Rate limit messages to prevent spam
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_message_time < message_cooldown:
		return
	last_message_time = current_time
	
	# Limit total active messages more aggressively
	if active_messages.size() >= max_messages:
		# Remove oldest message
		var old_msg = active_messages.pop_front()
		if is_instance_valid(old_msg):
			old_msg.queue_free()
	
	# Create message instance
	var msg_instance = _create_chat_message(username, message, color)
	if not msg_instance:
		return
		
	# Add to container
	message_container.add_child(msg_instance)
	active_messages.append(msg_instance)
	
	# Store timer info on the message itself
	msg_instance.set_meta("spawn_time", current_time)
	msg_instance.set_meta("is_fading", false)
	
	# Auto-scroll to bottom (deferred to prevent performance issues)
	call_deferred("_scroll_to_bottom")

## Process message lifecycle
func _process(delta: float):
	# Only process every 0.25 seconds to improve performance
	process_timer += delta
	if process_timer < 0.25:
		return
	process_timer = 0.0
	
	# Clean up invalid messages
	active_messages = active_messages.filter(func(msg): return is_instance_valid(msg))
	
	# Check each message for expiration
	var current_time = Time.get_ticks_msec() / 1000.0
	var messages_to_remove = []
	
	for msg in active_messages:
		if not is_instance_valid(msg):
			continue
			
		var spawn_time = msg.get_meta("spawn_time", current_time)
		var age = current_time - spawn_time
		var is_fading = msg.get_meta("is_fading", false)
		
		# Start fade if old enough
		if age >= (message_lifetime - fade_duration) and not is_fading:
			msg.set_meta("is_fading", true)
			_start_fade(msg)
		
		# Remove if too old
		if age >= message_lifetime:
			messages_to_remove.append(msg)
	
	# Remove expired messages
	for msg in messages_to_remove:
		active_messages.erase(msg)
		if is_instance_valid(msg):
			msg.queue_free()

## Start fading a message
func _start_fade(msg: RichTextLabel):
	if not is_instance_valid(msg):
		return
		
	var tween = create_tween()
	if tween:
		# Kill tween when message is freed
		msg.tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(msg, "modulate:a", 0.0, fade_duration)

## Clear all messages
func clear_messages():
	for msg in active_messages:
		if is_instance_valid(msg):
			msg.queue_free()
	active_messages.clear()

## Scroll to bottom of chat
func _scroll_to_bottom():
	if is_instance_valid(scroll_container) and scroll_container.get_v_scroll_bar():
		scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

## Create a simple chat message
func _create_chat_message(username: String, message: String, color: Color) -> RichTextLabel:
	var msg = RichTextLabel.new()
	msg.fit_content = true
	msg.scroll_active = false
	msg.bbcode_enabled = true
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.custom_minimum_size = Vector2(380, 0)
	
	# Add a semi-transparent background for readability
	var msg_bg = StyleBoxFlat.new()
	msg_bg.bg_color = Color(0, 0, 0, 0.3)
	msg_bg.corner_radius_top_left = 4
	msg_bg.corner_radius_top_right = 4
	msg_bg.corner_radius_bottom_left = 4
	msg_bg.corner_radius_bottom_right = 4
	msg_bg.content_margin_left = 4
	msg_bg.content_margin_right = 4
	msg_bg.content_margin_top = 2
	msg_bg.content_margin_bottom = 2
	msg.add_theme_stylebox_override("normal", msg_bg)
	
	# Ensure text is visible (white base color)
	msg.add_theme_color_override("default_color", Color.WHITE)
	
	# Create the formatted message
	var formatted_text = "[color=#%s][b]%s[/b][/color]: [color=#FFFFFF]%s[/color]" % [
		color.to_html(false),
		username,
		message
	]
	
	msg.text = formatted_text
	return msg
