extends Node
class_name TagSystem

## TagSystem: Universal tagging system for all game entities, abilities, and buffs
## This system allows for dynamic interactions based on tags
## Example: A buff that increases damage against "Boss" tagged entities
## will automatically apply to any entity with the "Boss" tag
##
## Special tag rules:
## - "Unique": For bosses and unique enemies (can combine with Lesser/Greater)
## - "Lesser": Default for random mobs like twitch chatters (cannot coexist with Greater)
## - "Greater": For specified greater enemies (cannot coexist with Lesser)
## Note: An entity can be "Lesser Unique" or "Greater Unique" but not both Lesser AND Greater

# Tag categories for organization
enum TagCategory {
	ENTITY_TYPE,    # Boss, Minion, Elite, Player
	DAMAGE_TYPE,    # Physical, Magical, Fire, Ice, Lightning
	ABILITY_TYPE,   # Melee, Ranged, Projectile, AoE
	MOVEMENT_TYPE,  # Flying, Ground, Phasing
	SPECIAL,        # Undead, Demon, Holy, Corrupted
	BUFF_TYPE,      # Offensive, Defensive, Utility
	STATUS          # Stunned, Slowed, Burning, Frozen
}

# Common tags used throughout the game
const COMMON_TAGS = {
	# Entity Types
	"Player": TagCategory.ENTITY_TYPE,
	"Enemy": TagCategory.ENTITY_TYPE,
	"Boss": TagCategory.ENTITY_TYPE,
	"Minion": TagCategory.ENTITY_TYPE,
	"Elite": TagCategory.ENTITY_TYPE,
	"Unique": TagCategory.ENTITY_TYPE,  # For unique bosses/enemies
	"Lesser": TagCategory.ENTITY_TYPE,  # For basic mobs (cannot coexist with Greater)
	"Greater": TagCategory.ENTITY_TYPE, # For greater enemies (cannot coexist with Lesser)
	
	# Damage Types
	"Physical": TagCategory.DAMAGE_TYPE,
	"Magical": TagCategory.DAMAGE_TYPE,
	"Fire": TagCategory.DAMAGE_TYPE,
	"Ice": TagCategory.DAMAGE_TYPE,
	"Lightning": TagCategory.DAMAGE_TYPE,
	"Holy": TagCategory.DAMAGE_TYPE,
	"Dark": TagCategory.DAMAGE_TYPE,
	
	# Ability Types
	"Melee": TagCategory.ABILITY_TYPE,
	"Ranged": TagCategory.ABILITY_TYPE,
	"Projectile": TagCategory.ABILITY_TYPE,
	"AoE": TagCategory.ABILITY_TYPE,
	"Summon": TagCategory.ABILITY_TYPE,
	
	# Movement Types
	"Flying": TagCategory.MOVEMENT_TYPE,
	"Ground": TagCategory.MOVEMENT_TYPE,
	"Phasing": TagCategory.MOVEMENT_TYPE,
	
	# Special Types
	"Undead": TagCategory.SPECIAL,
	"Demon": TagCategory.SPECIAL,
	"Corrupted": TagCategory.SPECIAL,
	"Mechanical": TagCategory.SPECIAL,
	
	# Buff Types
	"Offensive": TagCategory.BUFF_TYPE,
	"Defensive": TagCategory.BUFF_TYPE,
	"Utility": TagCategory.BUFF_TYPE,
	"Debuff": TagCategory.BUFF_TYPE,
	
	# Status Effects
	"Stunned": TagCategory.STATUS,
	"Slowed": TagCategory.STATUS,
	"Burning": TagCategory.STATUS,
	"Frozen": TagCategory.STATUS,
	"Poisoned": TagCategory.STATUS
}

## Check if an object has a specific tag
static func has_tag(object: Node, tag: String) -> bool:
	if not object.has_method("get_tags"):
		return false
	var tags: Array = object.get_tags()
	return tag in tags

## Check if an object has all specified tags
static func has_all_tags(object: Node, required_tags: Array) -> bool:
	if not object.has_method("get_tags"):
		return false
	var tags: Array = object.get_tags()
	for tag in required_tags:
		if not tag in tags:
			return false
	return true

## Check if an object has any of the specified tags
static func has_any_tag(object: Node, check_tags: Array) -> bool:
	if not object.has_method("get_tags"):
		return false
	var tags: Array = object.get_tags()
	for tag in check_tags:
		if tag in tags:
			return true
	return false

## Get all objects in a group that have a specific tag
static func get_tagged_in_group(group_name: String, tag: String) -> Array:
	var tagged_objects = []
	var group_nodes = Engine.get_main_loop().get_nodes_in_group(group_name)
	for node in group_nodes:
		if has_tag(node, tag):
			tagged_objects.append(node)
	return tagged_objects

## Get all objects in a group that have all specified tags
static func get_all_tagged_in_group(group_name: String, required_tags: Array) -> Array:
	var tagged_objects = []
	var group_nodes = Engine.get_main_loop().get_nodes_in_group(group_name)
	for node in group_nodes:
		if has_all_tags(node, required_tags):
			tagged_objects.append(node)
	return tagged_objects

## Calculate modifier based on tags (for damage calculations, etc.)
static func calculate_tag_modifier(source_tags: Array, target_tags: Array, modifiers: Dictionary) -> float:
	var total_modifier = 1.0
	
	# Check each modifier rule
	# Format: { "source_tag:target_tag": modifier_value }
	# Example: { "Fire:Ice": 1.5, "Holy:Undead": 2.0 }
	for modifier_key in modifiers:
		var parts = modifier_key.split(":")
		if parts.size() == 2:
			var source_tag = parts[0]
			var target_tag = parts[1]
			
			if source_tag in source_tags and target_tag in target_tags:
				total_modifier *= modifiers[modifier_key]
	
	return total_modifier

## Get tag category
static func get_tag_category(tag: String) -> TagCategory:
	if tag in COMMON_TAGS:
		return COMMON_TAGS[tag]
	return TagCategory.SPECIAL  # Default category for custom tags

## Validate if a tag exists in the common tags
static func is_valid_tag(tag: String) -> bool:
	return tag in COMMON_TAGS

## Get all tags in a specific category
static func get_tags_by_category(category: TagCategory) -> Array:
	var category_tags = []
	for tag in COMMON_TAGS:
		if COMMON_TAGS[tag] == category:
			category_tags.append(tag)
	return category_tags



