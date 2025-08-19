extends Node
class_name TwitchBot

## Simple adapter that provides backwards compatibility with the old Twitch bot interface
## Delegates all functionality to the TwitchManager

signal chat_message_received(username: String, message: String, color: Color)

var twitch_manager: TwitchManager

func _ready():
	# Create and configure the Twitch manager
	twitch_manager = TwitchManager.new()
	twitch_manager.name = "TwitchManager"
	add_child(twitch_manager)
	
	# Forward signals
	twitch_manager.chat_message_received.connect(_on_chat_message_received)
	
	# Get game controller reference
	var game_controller = get_parent()
	if game_controller:
		twitch_manager.set_game_controller(game_controller)

## Change to a different Twitch channel
func change_channel(channel_name: String) -> void:
	if twitch_manager:
		twitch_manager.change_channel(channel_name)

## Forward chat messages
func _on_chat_message_received(username: String, message: String, color: Color) -> void:
	chat_message_received.emit(username, message, color)

## Get current connection status
func is_twitch_connected() -> bool:
	return twitch_manager.is_channel_connected() if twitch_manager else false

## Get current channel
func get_channel() -> String:
	return twitch_manager.get_current_channel() if twitch_manager else ""

## Enable mock chat for testing
func enable_mock_chat(enabled: bool = true) -> void:
	if enabled and twitch_manager:
		twitch_manager.start_mock_chat(20.0)  # 20 messages per minute
