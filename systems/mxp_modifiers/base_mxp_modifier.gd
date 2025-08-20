extends Resource
class_name BaseMXPModifier

## Base class for all MXP modifiers
## Implements the Strategy pattern for different modifier behaviors

# Modifier metadata
@export var command_name: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var cost_per_use: int = 1
@export var max_stacks: int = -1  # -1 = unlimited
@export var emoji: String = "💎"

# Virtual methods that subclasses must implement
func get_effect_description(_stacks: int) -> String:
	push_error("get_effect_description() must be implemented in subclass")
	return ""

func apply_effect(_chatter_data: Dictionary, _amount: int) -> Dictionary:
	push_error("apply_effect() must be implemented in subclass")
	return {}

func can_apply(chatter_data: Dictionary, amount: int) -> bool:
	# Check if we've reached max stacks
	if max_stacks > 0:
		var current_stacks = get_current_stacks(chatter_data)
		if current_stacks + amount > max_stacks:
			return false
	return true

func get_current_stacks(chatter_data: Dictionary) -> int:
	return chatter_data.upgrades.get(command_name + "_stacks", 0)

func get_total_cost(amount: int) -> int:
	return cost_per_use * amount

## Calculate the actual amount that can be applied based on MXP and limits
func calculate_applicable_amount(username: String, requested_amount: int, chatter_data: Dictionary) -> int:
	if requested_amount <= 0:
		return 0
	
	# Check MXP availability
	var available_mxp = 0
	if MXPManager.instance:
		available_mxp = MXPManager.instance.get_available_mxp(username)
	
	# Calculate max affordable
	var max_affordable = available_mxp / float(cost_per_use)
	var actual_amount = min(requested_amount, max_affordable)
	
	# Check stack limits
	if max_stacks > 0:
		var current_stacks = get_current_stacks(chatter_data)
		var remaining_stacks = max_stacks - current_stacks
		actual_amount = min(actual_amount, remaining_stacks)
	
	return int(actual_amount)

## Execute the modifier effect
func execute(username: String, amount: int = 1) -> Dictionary:
	var result = {
		"success": false,
		"amount_applied": 0,
		"message": "",
		"effect_data": {}
	}
	
	# Get chatter data
	if not ChatterEntityManager.instance:
		result.message = "ChatterEntityManager not initialized"
		return result
	
	var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
	
	# Calculate actual amount
	var actual_amount = calculate_applicable_amount(username, amount, chatter_data)
	
	if actual_amount <= 0:
		if max_stacks > 0 and get_current_stacks(chatter_data) >= max_stacks:
			result.message = "%s is already at max stacks (%d)" % [command_name, max_stacks]
		else:
			result.message = "Not enough MXP"
		return result
	
	# Check if can apply
	if not can_apply(chatter_data, actual_amount):
		result.message = "Cannot apply %s x%d" % [command_name, actual_amount]
		return result
	
	# Spend MXP
	var total_cost = get_total_cost(actual_amount)
	if not MXPManager.instance.spend_mxp(username, total_cost, command_name):
		result.message = "Failed to spend MXP"
		return result
	
	# Apply the effect
	result.effect_data = apply_effect(chatter_data, actual_amount)
	
	# Update stacks
	if not chatter_data.upgrades.has(command_name + "_stacks"):
		chatter_data.upgrades[command_name + "_stacks"] = 0
	chatter_data.upgrades[command_name + "_stacks"] += actual_amount
	chatter_data.total_upgrades += actual_amount
	
	# Emit upgrade signal
	ChatterEntityManager.instance.entity_upgraded.emit(username, command_name, result.effect_data)
	
	# Success!
	result.success = true
	result.amount_applied = actual_amount
	result.message = get_success_message(username, actual_amount, chatter_data)
	
	# Send chat notification only if something was actually applied
	if actual_amount > 0:
		notify_chat(username, result.message)
	
	return result

func get_success_message(username: String, amount: int, chatter_data: Dictionary) -> String:
	var effect_desc = get_effect_description(get_current_stacks(chatter_data))
	return "%s %s gained %dx %s! %s" % [emoji, username, amount, display_name, effect_desc]

func notify_chat(_username: String, message: String):
	if GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.add_message(
				message,
				Color(0.8, 0.8, 1.0)
			)
