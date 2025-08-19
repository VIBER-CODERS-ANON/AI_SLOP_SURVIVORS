class_name AbilityTargetData
extends Resource

var target_type: int = 0
var primary_target: Node = null
var target_position: Vector2 = Vector2.ZERO
var target_direction: Vector2 = Vector2.ZERO
var affected_targets: Array = []

static func create_self_target(caster: Node) -> AbilityTargetData:
	var data = AbilityTargetData.new()
	data.target_type = 0  # SELF
	data.primary_target = caster
	data.target_position = caster.global_position
	return data

static func create_direction_target(origin: Vector2, direction: Vector2) -> AbilityTargetData:
	var data = AbilityTargetData.new()
	data.target_type = 4  # DIRECTION
	data.target_position = origin
	data.target_direction = direction.normalized()
	return data

func is_valid(_caster: Node, _max_range: float = 0.0) -> bool:
	return true  # Simplified validation
