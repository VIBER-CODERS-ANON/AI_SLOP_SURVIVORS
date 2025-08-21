extends Node
class_name CommandProcessor

## Handles all chat command processing and execution

signal command_executed(username: String, command: String)

var game_controller: GameController

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func process_chat_command(username: String, message: String):
	var msg_lower = message.to_lower()
	
	# Join command
	if msg_lower == "!join":
		_handle_join_command(username)
	
	# Vote command
	elif msg_lower.begins_with("!vote"):
		_handle_vote_command(username, message)
	
	# Evolution command
	elif msg_lower.begins_with("!evolve"):
		_handle_evolve_command(username, message)
	
	# Ability commands
	elif msg_lower.begins_with("!explode"):
		_execute_entity_command(username, "explode")
	elif msg_lower.begins_with("!fart"):
		_execute_entity_command(username, "fart")
	elif msg_lower.begins_with("!boost"):
		_execute_entity_command(username, "boost")
	
	# MXP commands - handled by MXPModifierManager
	elif MXPModifierManager.instance:
		MXPModifierManager.instance.process_command(username, message)
	
	command_executed.emit(username, message)

func _handle_join_command(username: String):
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.handle_join_command(username)

func _handle_vote_command(username: String, message: String):
	if not BossVoteManager.instance:
		return
	
	var vote_match = RegEx.new()
	vote_match.compile("^!vote(\\d)$")
	var result = vote_match.search(message)
	
	if result:
		var vote_num = int(result.get_string(1))
		BossVoteManager.instance.handle_vote_command(username, vote_num)

func _handle_evolve_command(username: String, message: String):
	if not game_controller:
		return
		
	var evolution_system = game_controller.get_node_or_null("EvolutionSystem")
	if not evolution_system:
		return
	
	var msg_lower = message.to_lower()
	var evolution_name = msg_lower.substr(7).strip_edges()
	
	if evolution_name.is_empty():
		var feed = game_controller.get_action_feed()
		if feed:
			feed.add_message("Available evolutions: !evolvewoodlandjoe (5 MXP), !evolvesuccubus (10 MXP)", Color(0.8, 0.8, 0))
		return
	
	evolution_system.request_evolution(username, evolution_name)

func _execute_entity_command(username: String, command_name: String):
	if not TicketSpawnManager.instance:
		return
	
	# Process through TicketSpawnManager which handles the new system
	TicketSpawnManager.instance.execute_entity_command(username, command_name)

func get_user_color(username: String) -> Color:
	# Simple color generation based on username
	var hash_value = username.hash()
	
	# Generate hue from hash (0-360 degrees)
	var hue = float(hash_value % 360) / 360.0
	
	# Use HSV with good saturation and value for visibility
	return Color.from_hsv(hue, 0.7, 0.9)