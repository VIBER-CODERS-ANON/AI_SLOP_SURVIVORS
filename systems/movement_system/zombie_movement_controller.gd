extends MovementController
class_name ZombieMovementController

@export var arrival_distance: float = 30.0
@export var num_rays: int = 8
@export var ray_length: float = 100.0
@export var avoidance_force: float = 2.0
@export var obstacle_mask: int = 1  # Collision mask for obstacles (adjust based on layers)
@export var raycast_every_n_frames: int = 2  # run obstacle rays every N physics frames

var target_position: Vector2
var has_target: bool = false
var directions: Array[Vector2] = []

func _ready():
	super._ready()
	# Precompute directions
	for i in num_rays:
		var angle = i * (TAU / num_rays)
		directions.append(Vector2(cos(angle), sin(angle)))

func set_target_position(pos: Vector2) -> void:
	target_position = pos
	has_target = true

func _get_movement_input() -> Vector2:
	# Check if AI/movement is disabled
	if DebugSettings.instance:
		if not DebugSettings.instance.mob_movement_enabled:
			return Vector2.ZERO
		if not DebugSettings.instance.mob_ai_enabled:
			return Vector2.ZERO
	
	if not has_target or not entity:
		return Vector2.ZERO
	
	var current_pos = entity.global_position
	var distance = current_pos.distance_to(target_position)
	if distance <= arrival_distance:
		has_target = false
		return Vector2.ZERO
	
	var to_target = (target_position - current_pos).normalized()
	
	# Compute interest (how much direction points to target)
	var interest: Array[float] = []
	for dir in directions:
		interest.append(maxf(0.0, dir.dot(to_target)))
	
	# Compute danger from obstacles with cadence
	var danger: Array[float] = []
	var do_raycast := (raycast_every_n_frames <= 1) or ((Engine.get_physics_frames() + int(entity.get_instance_id())) % raycast_every_n_frames == 0)
	
	if do_raycast:
		var space_state = entity.get_world_2d().direct_space_state
		for i in directions.size():
			var dir = directions[i]
			var query = PhysicsRayQueryParameters2D.create(current_pos, current_pos + dir * ray_length)
			query.collision_mask = obstacle_mask
			var result = space_state.intersect_ray(query)
			if result:
				var hit_dist = (result.position - current_pos).length()
				danger.append(1.0 - (hit_dist / ray_length))
			else:
				danger.append(0.0)
	else:
		# Skip raycasts this frame
		for i in directions.size():
			danger.append(0.0)
	
	# Compute final steering
	var steering = Vector2.ZERO
	for i in directions.size():
		var score = interest[i] - danger[i] * avoidance_force
		steering += directions[i] * score
	
	if steering.length_squared() > 0:
		steering = steering.normalized()
	
	return steering
