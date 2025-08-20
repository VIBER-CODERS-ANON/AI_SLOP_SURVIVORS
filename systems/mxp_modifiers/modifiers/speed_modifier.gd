extends BaseMXPModifier
class_name SpeedModifier

## !speed command - Flat movement speed increase
## Simple: +5 movement speed per MXP spent

const FLAT_SPEED_BONUS: float = 5.0  # +5 speed per MXP

func _init():
	command_name = "speed"
	display_name = "Speed Boost"
	description = "+5 movement speed per MXP (!speed, !speed5, !speedmax)"
	cost_per_use = 1
	emoji = "💨"

func get_effect_description(stacks: int) -> String:
	return "Now at +%d total speed!" % [int(stacks * FLAT_SPEED_BONUS)]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize if not present
	if not chatter_data.upgrades.has("bonus_move_speed"):
		chatter_data.upgrades["bonus_move_speed"] = 0.0
	
	# Apply flat speed bonus
	chatter_data.upgrades["bonus_move_speed"] += amount * FLAT_SPEED_BONUS
	
	return {
		"bonus_move_speed": chatter_data.upgrades["bonus_move_speed"]
	}