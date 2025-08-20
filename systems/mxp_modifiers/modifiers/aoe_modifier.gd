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
	var total_bonus = stacks * FLAT_AOE_BONUS
	var before_aoe = 100 + ((total_bonus - FLAT_AOE_BONUS) * 100)
	var after_aoe = 100 + (total_bonus * 100)
	return "AoE: %.0f%% → %.0f%% (+%.0f%%)" % [before_aoe, after_aoe, FLAT_AOE_BONUS * 100]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("bonus_aoe"):
		chatter_data.upgrades["bonus_aoe"] = 0.0
	
	var before_bonus = chatter_data.upgrades["bonus_aoe"]
	
	# Apply flat AOE bonus
	chatter_data.upgrades["bonus_aoe"] += amount * FLAT_AOE_BONUS
	
	return {
		"bonus_aoe": chatter_data.upgrades["bonus_aoe"],
		"before_value": 100 + (before_bonus * 100),
		"after_value": 100 + (chatter_data.upgrades["bonus_aoe"] * 100)
	}