extends BaseMXPModifier
class_name TicketModifier

func _init():
	command_name = "ticket"
	display_name = "Ticket Boost"
	description = "Increase your spawn chance by adding more tickets to the pool"
	cost_per_use = 3  # Costs 3 MXP per upgrade
	max_stacks = 10  # Max 10 stacks (up to +100% tickets)
	emoji = "🎫"

func get_effect_description(stacks: int) -> String:
	var before_percent = max(0, (stacks - 1)) * 10
	var after_percent = stacks * 10
	return "Tickets: %d%% → %d%% (+10%%)" % [100 + before_percent, 100 + after_percent]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Calculate new ticket multiplier
	var current_multiplier = chatter_data.upgrades.get("ticket_multiplier", 1.0)
	var bonus_per_stack = 0.1  # +10% per stack
	var before_multiplier = current_multiplier
	var new_multiplier = current_multiplier + (bonus_per_stack * amount)
	
	chatter_data.upgrades["ticket_multiplier"] = new_multiplier
	
	# Rebuild ticket pool if chatter is in session
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance._rebuild_ticket_pool()
	
	return {
		"new_multiplier": new_multiplier,
		"bonus_percent": int((new_multiplier - 1.0) * 100),
		"before_percent": int((before_multiplier - 1.0) * 100),
		"after_percent": int((new_multiplier - 1.0) * 100)
	}