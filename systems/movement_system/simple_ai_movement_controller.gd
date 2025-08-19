extends MovementController
class_name SimpleAIMovementController

## Simplified AI movement controller for debugging
## Just moves directly toward target with basic obstacle avoidance

@export var arrival_distance: float = 30.0
@export var raycast_distance: float = 50.0
@export var avoidance_angle: float = 45.0  # Degrees to turn when hitting obstacle
@export var raycast_every_n_frames: int = 2  # run obstacle rays every N physics frames

var target_position: Vector2
var has_target: bool = false
var obstacle_raycast: RayCast2D
var last_avoidance_direction: Vector2 = Vector2.ZERO

func _ready():
	super._ready()
	
	# Create raycast for obstacle detection
	obstacle_raycast = RayCast2D.new()
	obstacle_raycast.name = "ObstacleRaycast"
	obstacle_raycast.target_position = Vector2(raycast_distance, 0)
	obstacle_raycast.collision_mask = 1  # Only detect walls/obstacles
	add_child(obstacle_raycast)

func set_target_position(pos: Vector2) -> void:
	if pos and pos != Vector2.ZERO:
		target_position = pos
		has_target = true

func _get_movement_input() -> Vector2:
	if not has_target or not entity:
		return Vector2.ZERO
	
	# Check if we've arrived
	var distance_to_target = entity.global_position.distance_to(target_position)
	if distance_to_target <= arrival_distance:
		has_target = false
		return Vector2.ZERO
	
	# Calculate direction to target
	var direction = entity.global_position.direction_to(target_position)
	
	# Check if we should run raycasts this frame
	var do_raycast := (raycast_every_n_frames <= 1) or ((Engine.get_physics_frames() + int(entity.get_instance_id())) % raycast_every_n_frames == 0)
	
	if do_raycast:
		# Update raycast direction
		obstacle_raycast.target_position = direction * raycast_distance
		obstacle_raycast.force_raycast_update()
		
		# Simple obstacle avoidance
		if obstacle_raycast.is_colliding():
			# Try turning left
			var left_angle = direction.rotated(deg_to_rad(avoidance_angle))
			obstacle_raycast.target_position = left_angle * raycast_distance
			obstacle_raycast.force_raycast_update()
			
			if not obstacle_raycast.is_colliding():
				last_avoidance_direction = left_angle
			else:
				# Try turning right
				var right_angle = direction.rotated(deg_to_rad(-avoidance_angle))
				obstacle_raycast.target_position = right_angle * raycast_distance
				obstacle_raycast.force_raycast_update()
				
				if not obstacle_raycast.is_colliding():
					last_avoidance_direction = right_angle
				else:
					# Both sides blocked, try harder turn
					last_avoidance_direction = direction.rotated(deg_to_rad(90 if randf() > 0.5 else -90))
		else:
			# No obstacle, clear avoidance
			last_avoidance_direction = Vector2.ZERO
	
	# Use last avoidance direction if we're not raycasting this frame
	if last_avoidance_direction != Vector2.ZERO:
		direction = last_avoidance_direction
	
	return direction

func stop_movement():
	super.stop_movement()
	has_target = false
