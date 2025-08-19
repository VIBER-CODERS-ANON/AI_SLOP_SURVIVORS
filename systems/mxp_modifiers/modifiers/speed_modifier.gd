extends BaseMXPModifier
class_name SpeedModifier

## !speed command - Increases movement speed by 2.5% per MXP (increased/additive)

const SPEED_INCREASE_PERCENT: float = 0.025  # 2.5% per use

func _init():
	command_name = "speed"
	display_name = "Speed"
	description = "Increases movement speed by 2.5% per MXP"
	cost_per_use = 1
	emoji = "💨"

func get_effect_description(stacks: int) -> String:
	var total_increase = stacks * SPEED_INCREASE_PERCENT * 100
	return "+%.0f%% movement speed" % total_increase

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize speed increased if not present
	if not chatter_data.upgrades.has("speed_increased_percent"):
		chatter_data.upgrades["speed_increased_percent"] = 0.0
	
	# Apply increased speed % (additive)
	chatter_data.upgrades["speed_increased_percent"] += amount * SPEED_INCREASE_PERCENT
	
	# Also update legacy speed_multiplier for compatibility
	if not chatter_data.upgrades.has("speed_multiplier"):
		chatter_data.upgrades["speed_multiplier"] = 1.0
	chatter_data.upgrades["speed_multiplier"] = 1.0 + chatter_data.upgrades["speed_increased_percent"]
	
	return {
		"speed_increase_percent": chatter_data.upgrades["speed_increased_percent"] * 100,
		"total_speed_percent": chatter_data.upgrades["speed_multiplier"] * 100
	}
