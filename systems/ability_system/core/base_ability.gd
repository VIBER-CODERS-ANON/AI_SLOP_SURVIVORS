class_name BaseAbility
extends Resource

# Basic properties
var ability_id: String = ""
var ability_name: String = "Unnamed Ability" 
var ability_description: String = "No description"
var ability_tags: Array = []
var ability_type: int = 0

var base_cooldown: float = 1.0
var current_cooldown: float = 0.0
var is_on_cooldown: bool = false

var resource_costs: Dictionary = {}
var targeting_type: int = 0
var base_range: float = 0.0

signal cooldown_started(duration)
signal cooldown_ended()
@warning_ignore("unused_signal")
signal executed(target_data)  # Emitted by ability implementations (fart_ability, dash_ability, etc.)

func can_execute(_holder, _target_data) -> bool:
	return not is_on_cooldown

func execute(holder, target_data) -> bool:
	if not can_execute(holder, target_data):
		return false
	_execute_ability(holder, target_data)
	return true

func _execute_ability(_holder, _target_data) -> void:
	pass

func update(delta: float, _holder) -> void:
	if is_on_cooldown and current_cooldown > 0:
		current_cooldown -= delta
		if current_cooldown <= 0:
			is_on_cooldown = false
			current_cooldown = 0
			cooldown_ended.emit()

func _start_cooldown(_holder) -> void:
	if base_cooldown <= 0:
		return
	is_on_cooldown = true
	current_cooldown = base_cooldown
	cooldown_started.emit(base_cooldown)

func on_added(_holder) -> void:
	pass

func on_removed(_holder) -> void:
	pass

func get_id() -> String:
	return ability_id

func get_ability_tags() -> Array:
	return ability_tags

func get_targeting_type() -> int:
	return targeting_type

func get_range() -> float:
	return base_range

func get_modified_value(base_value: float, _stat_name: String, _holder) -> float:
	return base_value

# Helper functions for getting entity information
func _get_entity(holder):
	if holder == null:
		return null
	
	# Check if holder is already the entity
	if holder.has_method("take_damage"):
		return holder
	
	# Check if holder has an entity property (AbilityHolder pattern)
	if holder.has_method("get") and holder.get("entity") != null:
		return holder.entity
	
	# Check if holder has owner
	if holder.has_method("get_owner") and holder.get_owner() != null:
		return holder.get_owner()
	
	return holder

func _get_entity_name(holder) -> String:
	var entity = _get_entity(holder)
	if entity:
		if entity.has_method("get") and entity.get("chatter_username") != null:
			return entity.chatter_username
		elif entity.has_method("get") and entity.get("name") != null:
			return entity.name
		else:
			return str(entity)
	return "Unknown"
