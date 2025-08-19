extends BaseMXPModifier
class_name RespawnSpeedModifier

## !respawnspeed command - Reduces respawn timer by 2 seconds per MXP (max 30 uses)

const RESPAWN_REDUCTION_SECONDS: float = 2.0  # -2 seconds per use
const MAX_USES: int = 30  # Max 30 uses for instant respawn

func _init():
	command_name = "respawnspeed"
	display_name = "Respawn Speed"
	description = "Reduces respawn timer by 2 seconds per MXP (max 30 uses)"
	cost_per_use = 1
	max_stacks = MAX_USES
	emoji = "⏱️"

func get_effect_description(stacks: int) -> String:
	var reduction = stacks * RESPAWN_REDUCTION_SECONDS
	if stacks >= MAX_USES:
		return "Instant respawn!"
	else:
		return "-%.0f seconds respawn time" % reduction

func apply_effect(chatter_data: Dictionary, amount: int) -> Dictionary:
	# Initialize respawn reduction if not present
	if not chatter_data.upgrades.has("respawn_time_reduction"):
		chatter_data.upgrades["respawn_time_reduction"] = 0.0
	
	# Apply respawn time reduction
	chatter_data.upgrades["respawn_time_reduction"] += amount * RESPAWN_REDUCTION_SECONDS
	
	# Cap at 60 seconds (instant respawn) since default is 60 seconds
	chatter_data.upgrades["respawn_time_reduction"] = min(chatter_data.upgrades["respawn_time_reduction"], 60.0)
	
	return {
		"total_reduction": chatter_data.upgrades["respawn_time_reduction"],
		"is_instant": chatter_data.upgrades["respawn_time_reduction"] >= 60.0
	}
