extends BaseMXPModifier
class_name RegenModifier

## !regen command - Gives +1 regeneration per MXP (flat, stacking)

const REGEN_PER_USE: float = 1.0  # +1 regen per use

func _init():
	command_name = "regen"
	display_name = "Regeneration"
	description = "Gives +1 regeneration per MXP"
	cost_per_use = 1
	emoji = "💚"

func get_effect_description(stacks: int) -> String:
	return "+%.0f HP/sec regeneration" % (stacks * REGEN_PER_USE)

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize regen bonus if not present
	if not chatter_data.upgrades.has("regen_flat_bonus"):
		chatter_data.upgrades["regen_flat_bonus"] = 0.0
	
	# Apply flat regen bonus
	chatter_data.upgrades["regen_flat_bonus"] += amount * REGEN_PER_USE
	
	return {
		"total_regen": chatter_data.upgrades["regen_flat_bonus"]
	}
