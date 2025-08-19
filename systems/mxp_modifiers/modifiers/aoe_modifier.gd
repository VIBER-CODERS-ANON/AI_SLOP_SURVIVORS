extends BaseMXPModifier
class_name AOEModifier

## !aoe command - Increases area of effect by 5% per MXP (increased/additive)

const AOE_INCREASE_PERCENT: float = 0.05  # 5% per use

func _init():
	command_name = "aoe"
	display_name = "Area of Effect"
	description = "Increases area of effect by 5% per MXP"
	cost_per_use = 1
	emoji = "💥"

func get_effect_description(stacks: int) -> String:
	var total_increase = stacks * AOE_INCREASE_PERCENT * 100
	return "+%.0f%% area of effect" % total_increase

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize aoe increased if not present
	if not chatter_data.upgrades.has("aoe_increased_percent"):
		chatter_data.upgrades["aoe_increased_percent"] = 0.0
	
	# Apply increased aoe % (additive)
	chatter_data.upgrades["aoe_increased_percent"] += amount * AOE_INCREASE_PERCENT
	
	# Also update legacy aoe_multiplier for compatibility
	if not chatter_data.upgrades.has("aoe_multiplier"):
		chatter_data.upgrades["aoe_multiplier"] = 1.0
	chatter_data.upgrades["aoe_multiplier"] = 1.0 + chatter_data.upgrades["aoe_increased_percent"]
	
	return {
		"aoe_increase_percent": chatter_data.upgrades["aoe_increased_percent"] * 100,
		"total_aoe_percent": chatter_data.upgrades["aoe_multiplier"] * 100
	}
