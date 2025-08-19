extends BaseMXPModifier
class_name AttackSpeedModifier

## !attackspeed command - Flat attack speed increase
## Simple: +0.1 attacks per second per MXP spent

const FLAT_ATTACK_SPEED_BONUS: float = 0.1  # +0.1 attacks/sec per MXP

func _init():
	command_name = "attackspeed"
	display_name = "Attack Speed Boost"
	description = "+0.1 attacks per second per MXP (!attackspeed, !attackspeed5, !attackspeedmax)"
	cost_per_use = 1
	emoji = "⚔️"

func get_effect_description(stacks: int) -> String:
	return "Now at +%.1f total attacks/sec!" % [stacks * FLAT_ATTACK_SPEED_BONUS]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("bonus_attack_speed"):
		chatter_data.upgrades["bonus_attack_speed"] = 0.0
	
	# Apply flat attack speed bonus
	chatter_data.upgrades["bonus_attack_speed"] += amount * FLAT_ATTACK_SPEED_BONUS
	
	return {
		"bonus_attack_speed": chatter_data.upgrades["bonus_attack_speed"]
	}