extends BaseMXPModifier
class_name AggroModifier

## !aggro command - Increases aggro radius by 5% per MXP spent (multiplicative)

const AGGRO_INCREASE_PERCENT: float = 0.05  # 5% per use

func _init():
	command_name = "aggro"
	display_name = "Aggro Radius"
	description = "Increases aggro radius by 5% per MXP (multiplicative)"
	cost_per_use = 1
	emoji = "👁️"

func get_effect_description(stacks: int) -> String:
	var total_multiplier = pow(1.0 + AGGRO_INCREASE_PERCENT, stacks)
	return "Aggro radius at %.0f%%" % (total_multiplier * 100)

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize aggro multiplier if not present
	if not chatter_data.upgrades.has("aggro_multiplier"):
		chatter_data.upgrades["aggro_multiplier"] = 1.0
	
	# Apply multiplicative stacking
	for i in range(amount):
		chatter_data.upgrades["aggro_multiplier"] *= (1.0 + AGGRO_INCREASE_PERCENT)
	
	return {
		"new_multiplier": chatter_data.upgrades["aggro_multiplier"],
		"percent": chatter_data.upgrades["aggro_multiplier"] * 100
	}
