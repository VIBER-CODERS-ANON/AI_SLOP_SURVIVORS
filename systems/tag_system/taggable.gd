extends Node
class_name Taggable

## Base component for any object that can have tags
## This should be added as a child node or inherited by entities, abilities, and buffs

signal tag_added(tag: String)
signal tag_removed(tag: String)
signal tags_changed()

@export var tags: Array[String] = []
@export var permanent_tags: Array[String] = []  # Tags that cannot be removed

func _ready():
	# Ensure all permanent tags are in the tags array
	for tag in permanent_tags:
		if not tag in tags:
			tags.append(tag)

## Get all current tags
func get_tags() -> Array:
	return tags.duplicate()

## Add a tag
func add_tag(tag: String) -> void:
	if not tag in tags:
		tags.append(tag)
		tag_added.emit(tag)
		tags_changed.emit()

## Remove a tag (unless it's permanent)
func remove_tag(tag: String) -> void:
	if tag in permanent_tags:
		push_warning("Cannot remove permanent tag: " + tag)
		return
	
	if tag in tags:
		tags.erase(tag)
		tag_removed.emit(tag)
		tags_changed.emit()

## Check if has a specific tag
func has_tag(tag: String) -> bool:
	return tag in tags

## Check if has all specified tags
func has_all_tags(required_tags: Array) -> bool:
	for tag in required_tags:
		if not tag in tags:
			return false
	return true

## Check if has any of the specified tags
func has_any_tag(check_tags: Array) -> bool:
	for tag in check_tags:
		if tag in tags:
			return true
	return false

## Set tags (replaces all non-permanent tags)
func set_tags(new_tags: Array) -> void:
	tags.clear()
	
	# Re-add permanent tags
	for tag in permanent_tags:
		tags.append(tag)
	
	# Add new tags
	for tag in new_tags:
		if not tag in tags:
			tags.append(tag)
	
	tags_changed.emit()

## Clear all non-permanent tags
func clear_tags() -> void:
	tags.clear()
	
	# Re-add permanent tags
	for tag in permanent_tags:
		tags.append(tag)
	
	tags_changed.emit()

## Get tags by category
func get_tags_by_category(category: TagSystem.TagCategory) -> Array:
	var category_tags = []
	for tag in tags:
		if TagSystem.get_tag_category(tag) == category:
			category_tags.append(tag)
	return category_tags



