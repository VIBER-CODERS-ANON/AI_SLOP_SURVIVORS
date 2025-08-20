extends BaseMXPModifier
class_name AttackSpeedModifier

## !attackspeed command - Flat attack speed increase
## Simple: +0.1 attacks per second per MXP spent

const FLAT_ATTACK_SPEED_BONUS: float = 0.1  # +0.1 attacks/sec per MXP
const BASE_ATTACK_SPEED: float = 1.0  # Default base attack speed

func _init():
	command_name = "attackspeed"
	display_name = "Attack Speed Boost"
	description = "+0.1 attacks per second per MXP (!attackspeed, !attackspeed5, !attackspeedmax)"
	cost_per_use = 1
	emoji = "⚔️"

func get_effect_description(stacks: int) -> String:
	var total_bonus = stacks * FLAT_ATTACK_SPEED_BONUS
	var before_speed = BASE_ATTACK_SPEED + (total_bonus - FLAT_ATTACK_SPEED_BONUS)
	var after_speed = BASE_ATTACK_SPEED + total_bonus
	return "Attack Speed: %.1f → %.1f atk/sec (+%.1f)" % [before_speed, after_speed, FLAT_ATTACK_SPEED_BONUS]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("bonus_attack_speed"):
		chatter_data.upgrades["bonus_attack_speed"] = 0.0
	
	var before_bonus = chatter_data.upgrades["bonus_attack_speed"]
	
	# Apply flat attack speed bonus
	chatter_data.upgrades["bonus_attack_speed"] += amount * FLAT_ATTACK_SPEED_BONUS
	
	return {
		"bonus_attack_speed": chatter_data.upgrades["bonus_attack_speed"],
		"before_value": BASE_ATTACK_SPEED + before_bonus,
		"after_value": BASE_ATTACK_SPEED + chatter_data.upgrades["bonus_attack_speed"]
	}