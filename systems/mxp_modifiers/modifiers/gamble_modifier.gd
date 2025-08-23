extends BaseMXPModifier
class_name GambleModifier

## !gamble command - 7.77% chance to gain 10 MXP per MXP gambled
## Each MXP spent is a separate roll

const GAMBLE_CHANCE: float = 0.0777  # 7.77%
const GAMBLE_PAYOUT: int = 10  # 10 MXP per win

func _init():
	command_name = "gamble"
	display_name = "Gamble"
	description = "7.77% chance to gain 10 MXP per MXP gambled"
	cost_per_use = 1
	emoji = "🎰"

func get_effect_description(stacks: int) -> String:
	return "Total gambles: %d" % stacks

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	var wins = 0
	var total_winnings = 0
	
	# Roll for each MXP gambled
	for i in range(amount):
		if randf() < GAMBLE_CHANCE:
			wins += 1
			total_winnings += GAMBLE_PAYOUT
	
	# Award winnings if any
	if total_winnings > 0 and MXPManager.instance:
		# We need to "un-spend" the winnings by reducing spent amount
		var username = ""
		# Find username from chatter_data (this is a bit hacky, might need to refactor)
		for user in ChatterEntityManager.instance.chatter_data:
			if ChatterEntityManager.instance.chatter_data[user] == chatter_data:
				username = user
				break
		
		if username != "":
			# Reduce spent MXP to effectively give them MXP
			if MXPManager.instance.chatter_spent_mxp.has(username):
				MXPManager.instance.chatter_spent_mxp[username] -= total_winnings
				MXPManager.instance.chatter_spent_mxp[username] = max(0, MXPManager.instance.chatter_spent_mxp[username])
	
	return {
		"amount_gambled": amount,
		"wins": wins,
		"total_winnings": total_winnings,
		"net_result": total_winnings - amount
	}

func get_success_message(username: String, amount: int, chatter_data: Dictionary) -> String:
	var effect_data = chatter_data.get("last_gamble_result", {})
	var wins = effect_data.get("wins", 0)
	var _total_winnings = effect_data.get("total_winnings", 0)
	var net_result = effect_data.get("net_result", 0)
	
	# Get current MXP balance
	var current_mxp = 0
	if MXPManager.instance:
		current_mxp = MXPManager.instance.get_available_mxp(username)
	
	if wins > 0:
		var before_mxp = current_mxp - net_result
		return "%s %s gambled %d MXP and won %d times! MXP: %d → %d (Net: %+d)" % [
			emoji, username, amount, wins, before_mxp, current_mxp, net_result
		]
	else:
		var before_mxp = current_mxp + amount
		return "%s %s gambled %d MXP and lost! MXP: %d → %d (-%d)" % [
			emoji, username, amount, before_mxp, current_mxp, amount
		]

func execute(username: String, amount: int = 1) -> Dictionary:
	# Call parent execute
	var result = super.execute(username, amount)
	
	# Store the gamble result for the success message
	if result.success and result.effect_data.size() > 0:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		chatter_data["last_gamble_result"] = result.effect_data
		
		# Update the message with the actual result
		result.message = get_success_message(username, result.amount_applied, chatter_data)
		notify_chat(username, result.message)
	
	return result
