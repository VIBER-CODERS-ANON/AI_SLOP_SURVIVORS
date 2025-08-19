extends BaseCreature
class_name BaseEvolvedCreature

## Base class for all evolved Twitch chatter creatures
## Provides common functionality for evolved forms like Succubus, Bunny, etc.
## Ensures consistent behavior and appearance across all evolutions

@export_group("Evolution Config")
@export var evolution_mxp_cost: int = 10
@export var evolution_name: String = "Unknown"

func _ready():
	# Call parent ready first
	super._ready()
	
	# All evolved creatures should have these tags
	if taggable:
		taggable.add_tag("Evolved")
	
	# Add to evolved creatures group
	add_to_group("evolved_creatures")
	
	# Evolved creatures are typically stronger, so they drop more XP
	# This is handled by BaseEnemy's _drop_xp_orbs() which checks MXP spent

## Get display name for UI - override to customize
func get_display_name() -> String:
	if chatter_username != "":
		return chatter_username
	return evolution_name

## Virtual function for evolution-specific setup
func _setup_evolution():
	pass  # Override in specific evolution classes
