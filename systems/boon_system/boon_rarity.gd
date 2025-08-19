extends Resource
class_name BoonRarity

## Enum for boon rarity types
enum Type {
	COMMON,
	MAGIC,
	RARE,
	EPIC,
	UNIQUE
}

## Configuration for boon rarity
@export var type: Type = Type.COMMON
@export var display_name: String = "Common"
@export var color: Color = Color.WHITE
@export var power_multiplier: float = 1.0
@export var ticket_weight: int = 100
@export var has_particles: bool = false
@export var has_shine_effect: bool = false
@export var border_width: int = 2
@export var glow_intensity: float = 0.0

## Static method to get default rarity configurations
static func get_default_rarities() -> Dictionary:
	var rarities = {}
	
	# Common - Basic white/grey
	var common = BoonRarity.new()
	common.type = Type.COMMON
	common.display_name = "Common"
	common.color = Color(0.8, 0.8, 0.8, 1.0)  # Light grey
	common.power_multiplier = 1.0
	common.ticket_weight = 100
	common.border_width = 2
	rarities[Type.COMMON] = common
	
	# Magic - Subtle blue
	var magic = BoonRarity.new()
	magic.type = Type.MAGIC
	magic.display_name = "Magic"
	magic.color = Color(0.4, 0.6, 1.0, 1.0)  # Soft blue
	magic.power_multiplier = 2.0
	magic.ticket_weight = 25
	magic.border_width = 3
	magic.glow_intensity = 0.1
	rarities[Type.MAGIC] = magic
	
	# Rare - Subtle yellow
	var rare = BoonRarity.new()
	rare.type = Type.RARE
	rare.display_name = "Rare"
	rare.color = Color(1.0, 0.9, 0.3, 1.0)  # Soft yellow
	rare.power_multiplier = 3.0
	rare.ticket_weight = 10
	rare.border_width = 4
	rare.glow_intensity = 0.2
	rare.has_shine_effect = true
	rarities[Type.RARE] = rare
	
	# Epic - Vibrant purple with particles
	var epic = BoonRarity.new()
	epic.type = Type.EPIC
	epic.display_name = "Epic"
	epic.color = Color(0.7, 0.3, 1.0, 1.0)  # Vibrant purple
	epic.power_multiplier = 4.0
	epic.ticket_weight = 5
	epic.border_width = 5
	epic.glow_intensity = 0.4
	epic.has_shine_effect = true
	epic.has_particles = true
	rarities[Type.EPIC] = epic
	
	# Unique - Mysterious orange
	var unique = BoonRarity.new()
	unique.type = Type.UNIQUE
	unique.display_name = "Unique"
	unique.color = Color(1.0, 0.6, 0.2, 1.0)  # Orange
	unique.power_multiplier = 0.0  # Custom effects, no standard multiplier
	unique.ticket_weight = 10
	unique.border_width = 6
	unique.glow_intensity = 0.15
	rarities[Type.UNIQUE] = unique
	
	return rarities
