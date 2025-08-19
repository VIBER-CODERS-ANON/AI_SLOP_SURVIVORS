extends BaseMXPModifier
class_name AttackSpeedModifier

## !attackspeed command - Increases attack speed by 2.5% per MXP (increased/additive)

const ATTACK_SPEED_INCREASE_PERCENT: float = 0.025  # 2.5% per use

func _init():
	command_name = "attackspeed"
	display_name = "Attack Speed"
	description = "Increases attack speed by 2.5% per MXP"
	cost_per_use = 1
	emoji = "⚔️"

func get_effect_description(stacks: int) -> String:
	var total_increase = stacks * ATTACK_SPEED_INCREASE_PERCENT * 100
	return "+%.0f%% attack speed" % total_increase

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize attack speed increased if not present
	if not chatter_data.upgrades.has("attack_speed_increased_percent"):
		chatter_data.upgrades["attack_speed_increased_percent"] = 0.0
	
	# Apply increased attack speed % (additive)
	chatter_data.upgrades["attack_speed_increased_percent"] += amount * ATTACK_SPEED_INCREASE_PERCENT
	
	# Also create attack_speed_multiplier for easy use
	if not chatter_data.upgrades.has("attack_speed_multiplier"):
		chatter_data.upgrades["attack_speed_multiplier"] = 1.0
	chatter_data.upgrades["attack_speed_multiplier"] = 1.0 + chatter_data.upgrades["attack_speed_increased_percent"]
	
	return {
		"attack_speed_increase_percent": chatter_data.upgrades["attack_speed_increased_percent"] * 100,
		"total_attack_speed_percent": chatter_data.upgrades["attack_speed_multiplier"] * 100
	}
