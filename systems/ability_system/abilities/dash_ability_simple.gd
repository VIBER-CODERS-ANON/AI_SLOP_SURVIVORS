class_name DashAbilitySimple
extends BaseAbility

var base_dash_distance: float = 150.0
var dash_duration: float = 0.2
var is_dashing: bool = false
var dash_velocity: Vector2 = Vector2.ZERO
var dash_time_remaining: float = 0.0
var entity_node = null

func _init() -> void:
	ability_id = "dash"
	ability_name = "Dash"
	ability_description = "Quickly dash in your current movement direction"
	ability_tags = ["Movement", "Utility"]
	ability_type = 0  # ACTIVE
	base_cooldown = 5.0
	resource_costs = {}
	targeting_type = 4  # DIRECTION
	base_range = 0.0

func can_execute(holder, target_data) -> bool:
	if is_dashing:
		return false
	return super.can_execute(holder, target_data)

func _execute_ability(holder, target_data) -> void:
	entity_node = holder.get_entity_node()
	if not entity_node:
		return
	
	# Get dash direction
	var dash_direction = target_data.target_direction if target_data else Vector2.ZERO
	if dash_direction.length() < 0.1:
		dash_direction = holder.get_facing_direction()
	
	# Start dash
	is_dashing = true
	dash_time_remaining = dash_duration
	dash_velocity = dash_direction.normalized() * (base_dash_distance / dash_duration)
	
	# Start cooldown
	_start_cooldown(holder)
	
	# Notify
	holder.on_ability_executed(self)
	executed.emit(target_data)

func update(delta: float, holder) -> void:
	super.update(delta, holder)
	
	if is_dashing and entity_node:
		dash_time_remaining -= delta
		
		# Apply dash velocity
		entity_node.velocity = dash_velocity
		entity_node.move_and_slide()
		
		# End dash if time is up
		if dash_time_remaining <= 0:
			is_dashing = false
			dash_velocity = Vector2.ZERO
			dash_time_remaining = 0
