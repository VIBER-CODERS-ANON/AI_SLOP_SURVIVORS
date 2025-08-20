extends BaseMXPModifier
class_name HPModifier

## !hp command - Flat HP increase
## Simple: +1 HP per MXP spent

const FLAT_HP_BONUS: int = 1  # +1 HP per MXP
const BASE_HP: int = 10  # Default base HP for entities

func _init():
	command_name = "hp"
	display_name = "HP Boost"
	description = "+1 HP per MXP (!hp, !hp5, !hpmax)"
	cost_per_use = 1
	emoji = "❤️"

func get_effect_description(stacks: int) -> String:
	var total_bonus = stacks * FLAT_HP_BONUS
	var before_hp = BASE_HP + (total_bonus - FLAT_HP_BONUS)
	var after_hp = BASE_HP + total_bonus
	return "HP: %d → %d (+%d)" % [before_hp, after_hp, FLAT_HP_BONUS]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("bonus_health"):
		chatter_data.upgrades["bonus_health"] = 0
	
	var before_bonus = chatter_data.upgrades["bonus_health"]
	
	# Apply flat HP bonus
	chatter_data.upgrades["bonus_health"] += amount * FLAT_HP_BONUS
	
	return {
		"bonus_health": chatter_data.upgrades["bonus_health"],
		"before_value": BASE_HP + before_bonus,
		"after_value": BASE_HP + chatter_data.upgrades["bonus_health"]
	}