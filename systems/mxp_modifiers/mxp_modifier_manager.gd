extends Node
class_name MXPModifierManager

## Manages all MXP modifiers and handles command processing
## Uses a registry pattern to allow easy addition of new modifiers

signal modifier_applied(username: String, modifier_name: String, result: Dictionary)

static var instance: MXPModifierManager

# Registry of all available modifiers
var modifiers: Dictionary = {}

func _ready():
	instance = self
	_register_all_modifiers()
	print("💎 MXP Modifier Manager initialized with %d modifiers!" % modifiers.size())

## Register all available modifiers
func _register_all_modifiers():
	# Register each modifier
	register_modifier(GambleModifier.new())
	register_modifier(HPModifier.new())
	register_modifier(SpeedModifier.new())
	register_modifier(AttackSpeedModifier.new())
	register_modifier(AOEModifier.new())
	register_modifier(RegenModifier.new())
	# RespawnSpeedModifier removed - no respawn system in game
	register_modifier(TicketModifier.new())

## Register a modifier
func register_modifier(modifier: BaseMXPModifier):
	if modifier.command_name.is_empty():
		push_error("Cannot register modifier with empty command_name")
		return
	
	modifiers[modifier.command_name] = modifier
	print("📝 Registered MXP modifier: %s" % modifier.command_name)

## Process a command from chat
func process_command(username: String, message: String) -> bool:
	var msg_lower = message.to_lower().strip_edges()
	
	# Extract command and amount
	var command_data = _parse_command(msg_lower)
	if command_data.is_empty():
		return false
	
	var command = command_data["command"]
	var amount = command_data["amount"]
	
	# Find the modifier
	if not modifiers.has(command):
		return false
	
	var modifier: BaseMXPModifier = modifiers[command]
	
	# Handle "max" command - use all available MXP
	if amount == -1:
		var available_mxp = MXPManager.instance.get_available_mxp(username)
		amount = available_mxp / modifier.cost_per_use  # Calculate max uses possible
		if amount <= 0:
			return false  # No MXP available
	
	# Execute the modifier
	var result = modifier.execute(username, amount)
	
	# Emit signal
	modifier_applied.emit(username, command, result)
	
	return result.success

## Parse command to extract base command and amount
func _parse_command(msg: String) -> Dictionary:
	# Remove the ! prefix
	if not msg.begins_with("!"):
		return {}
	
	msg = msg.substr(1)
	
	# Check each registered modifier
	for command_name in modifiers:
		if msg.begins_with(command_name):
			var remainder = msg.substr(command_name.length())
			
			# Check for "max" suffix - use all available MXP
			if remainder == "max":
				return {
					"command": command_name,
					"amount": -1  # Special value meaning "use max"
				}
			
			# Check for numeric suffix
			elif remainder.is_valid_int():
				return {
					"command": command_name,
					"amount": remainder.to_int()
				}
			
			# No suffix = single use
			elif remainder.is_empty():
				return {
					"command": command_name,
					"amount": 1
				}
	
	return {}

## Get list of all available commands
func get_command_list() -> Array:
	var commands = []
	for command_name in modifiers:
		var modifier: BaseMXPModifier = modifiers[command_name]
		commands.append({
			"command": "!" + command_name,
			"description": modifier.description,
			"cost": modifier.cost_per_use
		})
	return commands

## Get modifier by command name
func get_modifier(command_name: String) -> BaseMXPModifier:
	return modifiers.get(command_name, null)
