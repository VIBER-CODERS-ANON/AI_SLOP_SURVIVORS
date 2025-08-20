extends BaseMXPModifier
class_name AOEModifier

## !aoe command - Flat area of effect increase  
## Simple: +0.05 AOE multiplier per MXP spent (5% as flat addition)

const FLAT_AOE_BONUS: float = 0.05  # +0.05 AOE multiplier per MXP

func _init():
	command_name = "aoe"
	display_name = "Area of Effect Boost"
	description = "+5% area of effect per MXP (!aoe, !aoe5, !aoemax)"
	cost_per_use = 1
	emoji = "💥"

func get_effect_description(stacks: int) -> String:
	var total_bonus = stacks * FLAT_AOE_BONUS * 100
	return "Now at +%.0f%% total AOE!" % [total_bonus]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("bonus_aoe"):
		chatter_data.upgrades["bonus_aoe"] = 0.0
	
	# Apply flat AOE bonus
	chatter_data.upgrades["bonus_aoe"] += amount * FLAT_AOE_BONUS
	
	return {
		"bonus_aoe": chatter_data.upgrades["bonus_aoe"]
	}