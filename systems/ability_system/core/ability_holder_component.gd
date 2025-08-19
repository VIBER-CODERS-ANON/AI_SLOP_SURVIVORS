extends Node
class_name AbilityHolderComponent

var entity: Node
var entity_resources: Dictionary = {}

func _ready() -> void:
	entity = get_parent()
	if not entity:
		push_error("AbilityHolderComponent must be a child of an entity")
		return
	
	# Initialize default resources
	if entity.has_method("get"):
		entity_resources["health"] = entity.get("current_health") if entity.get("current_health") else 100
		entity_resources["max_health"] = entity.get("max_health") if entity.get("max_health") else 100

func create_ability_holder():
	return self

func get_entity_node() -> Node:
	return entity

func get_global_position() -> Vector2:
	if entity.has_method("get_global_position"):
		return entity.get_global_position()
	elif "global_position" in entity:
		return entity.global_position
	return Vector2.ZERO

func get_facing_direction() -> Vector2:
	var movement_controller = entity.get_node_or_null("PlayerMovementController")
	if not movement_controller:
		movement_controller = entity.get_node_or_null("MovementController")
	if movement_controller and movement_controller.has_method("get_direction"):
		var dir = movement_controller.get_direction()
		if dir.length() > 0.1:
			return dir
	
	var sprite = entity.get_node_or_null("SpriteContainer/Sprite")
	if not sprite:
		sprite = entity.get_node_or_null("Sprite")
	
	if sprite and "flip_h" in sprite:
		return Vector2.LEFT if sprite.flip_h else Vector2.RIGHT
	
	return Vector2.RIGHT

func get_stat(stat_name: String) -> float:
	match stat_name:
		"cast_speed":
			return 1.0
		"cooldown_reduction":
			return 0.0
		_:
			return 1.0

func can_move() -> bool:
	if entity.has_method("can_move"):
		return entity.can_move()
	return true

func is_silenced() -> bool:
	if entity.has_method("is_silenced"):
		return entity.is_silenced()
	return false

func on_ability_executed(ability) -> void:
	if entity.has_method("on_ability_executed"):
		entity.on_ability_executed(ability)

func on_ability_hit(ability, target: Node) -> void:
	if entity.has_method("on_ability_hit"):
		entity.on_ability_hit(ability, target)

func play_animation(animation_name: String) -> void:
	if entity.has_method("play_animation"):
		entity.play_animation(animation_name)
		return
	
	# Try to find sprite and play animation
	var sprite = entity.get_node_or_null("SpriteContainer/Sprite")
	if not sprite:
		sprite = entity.get_node_or_null("Sprite")
	
	if sprite and sprite.has_method("play"):
		sprite.play(animation_name)
