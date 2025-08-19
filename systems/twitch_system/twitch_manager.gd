extends Node
class_name TwitchManager

## Manages Twitch integration for chat commands and viewer interactions
## Uses anonymous IRC connection via WebSocket - no API keys needed!

signal chat_message_received(username: String, message: String, color: Color)
signal connection_status_changed(connected: bool)
signal channel_changed(channel_name: String)

@export_group("Connection Settings")
@export var auto_connect: bool = true
@export var default_channel: String = "quin69"

# Connection state
var websocket: WebSocketPeer
var twitch_connected: bool = false
var current_channel: String = ""

# Reference to game controller for integration
var game_controller = null

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep running during pause
	
	# Auto-connect if enabled
	if auto_connect:
		call_deferred("_load_saved_channel_and_connect")

func _load_saved_channel_and_connect():
	# Load channel from settings if available
	if SettingsManager.instance:
		current_channel = SettingsManager.instance.get_twitch_channel()
		print("📺 TwitchManager: Loaded saved channel: %s" % current_channel)
	else:
		current_channel = default_channel
	
	print("🎮 TwitchManager: Connecting anonymously to %s's chat..." % current_channel)
	connect_to_channel(current_channel)

## Connect to a Twitch channel
func connect_to_channel(channel: String) -> void:
	if channel.is_empty():
		push_error("TwitchManager: Cannot connect to empty channel name")
		return
	
	# Disconnect from current channel if connected
	if twitch_connected:
		disconnect_from_channel()
		await get_tree().create_timer(1.0).timeout
	
	current_channel = channel.to_lower()
	
	# Create WebSocket connection
	websocket = WebSocketPeer.new()
	websocket.connect_to_url("wss://irc-ws.chat.twitch.tv:443")
	print("🔗 TwitchManager: Connecting to Twitch IRC...")

## Disconnect from current channel
func disconnect_from_channel() -> void:
	if websocket and twitch_connected:
		print("📤 TwitchManager: Disconnecting from channel '%s'" % current_channel)
		websocket.close()
		twitch_connected = false
		connection_status_changed.emit(false)
	websocket = null

## Change to a different channel
func change_channel(new_channel: String) -> void:
	if new_channel.to_lower() == current_channel:
		print("ℹ️ TwitchManager: Already connected to channel '%s'" % new_channel)
		return
	
	var old_channel = current_channel
	print("🔄 TwitchManager: Switching from %s to %s..." % [old_channel, new_channel])
	
	# Disconnect and reconnect
	connect_to_channel(new_channel)
	channel_changed.emit(new_channel)

## Process WebSocket connection
func _process(_delta: float) -> void:
	if websocket:
		websocket.poll()
		var state = websocket.get_ready_state()
		
		match state:
			WebSocketPeer.STATE_OPEN:
				if not twitch_connected:
					print("✅ TwitchManager: Connected to Twitch IRC!")
					# Anonymous login - no credentials needed for reading
					websocket.send_text("CAP REQ :twitch.tv/tags")  # Request tags for colors
					websocket.send_text("PASS SCHMOOPIIE")
					websocket.send_text("NICK justinfan12345")  # Anonymous user
					websocket.send_text("JOIN #" + current_channel)
					twitch_connected = true
					connection_status_changed.emit(true)
					print("📺 TwitchManager: Joined %s's chat as anonymous viewer!" % current_channel)
					
					# Notify action feed if available
					if game_controller and game_controller.has_method("get_action_feed"):
						var feed = game_controller.get_action_feed()
						if feed:
							feed.add_message("Connected to %s's chat!" % current_channel, Color.GREEN)
				else:
					# Process incoming messages
					while websocket.get_available_packet_count() > 0:
						var packet = websocket.get_packet()
						_process_irc_message(packet.get_string_from_utf8())
			
			WebSocketPeer.STATE_CLOSED:
				if twitch_connected:
					print("❌ TwitchManager: Disconnected from Twitch IRC")
					twitch_connected = false
					connection_status_changed.emit(false)
				else:
					print("❌ TwitchManager: Failed to connect to Twitch IRC")

## Process IRC messages
func _process_irc_message(data: String):
	var messages = data.strip_edges(false).split("\r\n")
	
	for message in messages:
		if message.is_empty():
			continue
			
		# Handle PING/PONG to stay connected
		if message.begins_with("PING"):
			websocket.send_text("PONG :tmi.twitch.tv")
			continue
		
		# Parse chat messages
		if "PRIVMSG" in message:
			_parse_chat_message(message)

## Parse chat messages
func _parse_chat_message(message: String):
	# Parse tags if present (format: @tag1=value1;tag2=value2 :user!user@user.tmi.twitch.tv PRIVMSG #channel :message)
	var tags = {}
	var actual_message = message
	
	if message.begins_with("@"):
		var tag_end = message.find(" ")
		if tag_end != -1:
			var tag_string = message.substr(1, tag_end - 1)
			actual_message = message.substr(tag_end + 1)
			
			# Parse tags
			var tag_pairs = tag_string.split(";")
			for pair in tag_pairs:
				var kv = pair.split("=")
				if kv.size() == 2:
					tags[kv[0]] = kv[1]
	
	# Extract username and message from IRC format
	var parts = actual_message.split(" ")
	if parts.size() < 4:
		return
	
	# Extract username
	var user_part = parts[0]
	if user_part.begins_with(":"):
		user_part = user_part.substr(1)
	var username = user_part.split("!")[0]
	
	# Use display-name if available (properly capitalized)
	if tags.has("display-name") and tags["display-name"] != "":
		username = tags["display-name"]
	
	# Extract the actual message
	var message_start = actual_message.find(" :", actual_message.find("PRIVMSG"))
	if message_start == -1:
		return
	
	var chat_text = actual_message.substr(message_start + 2)
	
	# Extract color (default to white if not specified)
	var color = Color.WHITE
	if tags.has("color") and tags["color"] != "":
		var hex_color = tags["color"]
		if hex_color.begins_with("#"):
			color = Color.from_string(hex_color, Color.WHITE)
	
	# Process the chat message
	process_chat_message(username, chat_text, color)

## Process a chat message
func process_chat_message(username: String, message: String, color: Color = Color.WHITE) -> void:
	# Simply forward all messages to game_controller
	# Let game_controller handle all command processing for consistency
	chat_message_received.emit(username, message, color)

## Set the game controller reference
func set_game_controller(controller) -> void:
	game_controller = controller

## Get connection status
func is_channel_connected() -> bool:
	return twitch_connected

## Get current channel name
func get_current_channel() -> String:
	return current_channel

# === MOCK TESTING FUNCTIONS ===
# These simulate chat messages for testing

## Simulate a chat message (for testing)
func simulate_chat_message(username: String, message: String, color: Color = Color.WHITE) -> void:
	if not twitch_connected:
		push_warning("TwitchManager: Cannot simulate message - not connected")
		return
	
	process_chat_message(username, message, color)

## Start mock chat simulation (for testing)
func start_mock_chat(messages_per_minute: float = 10.0) -> void:
	print("🎭 TwitchManager: Starting mock chat simulation")
	
	var mock_timer = Timer.new()
	mock_timer.wait_time = 60.0 / messages_per_minute
	mock_timer.timeout.connect(_send_mock_message)
	add_child(mock_timer)
	mock_timer.start()

## Send a random mock message
func _send_mock_message() -> void:
	var mock_users = [
		{"name": "xXGamerXx", "color": Color.RED},
		{"name": "TwitchViewer123", "color": Color.BLUE},
		{"name": "ChatSpammer", "color": Color.GREEN},
		{"name": "NoobMaster69", "color": Color.PURPLE},
		{"name": "StreamSniper", "color": Color.ORANGE}
	]
	
	var mock_messages = [
		"hello streamer!",
		"KEKW",
		"!evolve succubus",
		"!vote 1",
		"!explode",
		"!fart",
		"!boost",
		"poggers",
		"LUL",
		"!mxp health 2",
		"!mxp damage 3"
	]
	
	var user = mock_users.pick_random()
	var message = mock_messages.pick_random()
	
	simulate_chat_message(user.name, message, user.color)
