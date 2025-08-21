extends BaseMXPModifier
class_name AttackSpeedModifier

## !attackspeed command - Percentage attack speed increase
## Simple: +1% attack speed per MXP spent

const ATTACK_SPEED_PERCENT_PER_MXP: float = 0.01  # +1% per MXP

func _init():
	command_name = "attackspeed"
	display_name = "Attack Speed Boost"
	description = "+1% attack speed per MXP (!attackspeed, !attackspeed5, !attackspeedmax)"
	cost_per_use = 1
	emoji = "⚔️"

func get_effect_description(stacks: int) -> String:
	var total_percent = stacks * ATTACK_SPEED_PERCENT_PER_MXP * 100
	var before_percent = (stacks - 1) * ATTACK_SPEED_PERCENT_PER_MXP * 100
	return "Attack Speed: %d%% → %d%% (+1%%)" % [100 + before_percent, 100 + total_percent]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("attack_speed_percent"):
		chatter_data.upgrades["attack_speed_percent"] = 0.0
	
	var before_percent = chatter_data.upgrades["attack_speed_percent"]
	
	# Apply percentage attack speed bonus (1% per MXP)
	chatter_data.upgrades["attack_speed_percent"] += amount * ATTACK_SPEED_PERCENT_PER_MXP
	
	return {
		"attack_speed_percent": chatter_data.upgrades["attack_speed_percent"],
		"before_value": (1.0 + before_percent) * 100,
		"after_value": (1.0 + chatter_data.upgrades["attack_speed_percent"]) * 100
	}