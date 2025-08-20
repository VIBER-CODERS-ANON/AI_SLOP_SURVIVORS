extends BaseMXPModifier
class_name HPModifier

## !hp command - Flat HP increase
## Simple: +1 HP per MXP spent

const FLAT_HP_BONUS: int = 1  # +1 HP per MXP

func _init():
	command_name = "hp"
	display_name = "HP Boost"
	description = "+1 HP per MXP (!hp, !hp5, !hpmax)"
	cost_per_use = 1
	emoji = "❤️"

func get_effect_description(stacks: int) -> String:
	return "Now at +%d total HP!" % [stacks * FLAT_HP_BONUS]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("bonus_health"):
		chatter_data.upgrades["bonus_health"] = 0
	
	# Apply flat HP bonus
	chatter_data.upgrades["bonus_health"] += amount * FLAT_HP_BONUS
	
	return {
		"bonus_health": chatter_data.upgrades["bonus_health"]
	}