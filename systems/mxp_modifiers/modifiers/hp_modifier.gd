extends BaseMXPModifier
class_name HPModifier

## !hp command - Increases max HP and size
## Following the same pattern as speed_modifier and attack_speed_modifier

const FLAT_HP_BONUS: int = 1  # +1 flat HP per MXP
const HP_INCREASE_PERCENT: float = 0.02  # 2% increased HP per MXP
const SIZE_INCREASE_PERCENT: float = 0.02  # 2% increased size per MXP

func _init():
	command_name = "hp"
	display_name = "HP Boost"
	description = "+1 HP and 2% increased max HP and size per MXP"
	cost_per_use = 1
	emoji = "❤️"

func get_effect_description(stacks: int) -> String:
	var flat_hp = stacks * FLAT_HP_BONUS
	var hp_increase = stacks * HP_INCREASE_PERCENT * 100
	var size_increase = stacks * SIZE_INCREASE_PERCENT * 100
	return "+%d HP, +%.0f%% max HP, +%.0f%% size" % [flat_hp, hp_increase, size_increase]

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize values if not present
	if not chatter_data.upgrades.has("hp_flat_bonus"):
		chatter_data.upgrades["hp_flat_bonus"] = 0
	if not chatter_data.upgrades.has("hp_increased_percent"):
		chatter_data.upgrades["hp_increased_percent"] = 0.0
	if not chatter_data.upgrades.has("hp_size_increased_percent"):
		chatter_data.upgrades["hp_size_increased_percent"] = 0.0
	
	# Apply flat HP bonus
	chatter_data.upgrades["hp_flat_bonus"] += amount * FLAT_HP_BONUS
	
	# Apply increased HP % (additive, like speed and attack speed)
	chatter_data.upgrades["hp_increased_percent"] += amount * HP_INCREASE_PERCENT
	
	# Apply increased size % (additive, separate from HP)
	chatter_data.upgrades["hp_size_increased_percent"] += amount * SIZE_INCREASE_PERCENT
	
	# Calculate the size multiplier for ChatterEntityManager
	# Using "more" multiplier for compatibility but calculated from increased
	chatter_data.upgrades["hp_size_more_multiplier"] = 1.0 + chatter_data.upgrades["hp_size_increased_percent"]
	
	return {
		"flat_hp_bonus": chatter_data.upgrades["hp_flat_bonus"],
		"hp_increased_percent": chatter_data.upgrades["hp_increased_percent"] * 100,
		"size_increased_percent": chatter_data.upgrades["hp_size_increased_percent"] * 100
	}