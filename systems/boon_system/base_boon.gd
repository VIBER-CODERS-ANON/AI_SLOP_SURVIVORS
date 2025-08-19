extends Resource
class_name BaseBoon

## Base class for all boons in the game
## Provides common functionality and structure for player permanent upgrades

@export var id: String = ""
@export var display_name: String = "Unknown Boon"
@export var description: String = "No description"
@export var icon_color: Color = Color.WHITE
@export var base_type: String = ""  # For scaling (e.g., "max_health", "damage")
@export var is_repeatable: bool = false  # For unique boons that can be selected multiple times

# Runtime properties
var rarity: BoonRarity
var current_stacks: int = 0

## Get the full display name including rarity
func get_full_name() -> String:
	if rarity:
		return "[" + rarity.display_name + "] " + display_name
	return display_name

## Get the color for UI display
func get_display_color() -> Color:
	if rarity:
		return rarity.color
	return icon_color

## Get description with current values
func get_formatted_description() -> String:
	return description

## Apply this boon to an entity
func apply_to_entity(entity: BaseEntity) -> void:
	current_stacks += 1
	_on_apply(entity)

## Virtual method for subclasses to implement
func _on_apply(_entity: BaseEntity) -> void:
	push_error("BaseBoon._on_apply() must be overridden!")

## Called when boon is removed (if applicable)
func remove_from_entity(entity: BaseEntity) -> void:
	_on_remove(entity)

## Virtual method for removal logic
func _on_remove(_entity: BaseEntity) -> void:
	pass

## Get the effective power based on rarity
func get_effective_power(base_value: float) -> float:
	if rarity and rarity.power_multiplier > 0:
		return base_value * rarity.power_multiplier
	return base_value
