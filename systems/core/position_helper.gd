extends Node
class_name PositionHelper

## Helper module for position calculations and safe spawn locations

static var world_setup_manager: WorldSetupManager

static func set_world_setup_manager(manager: WorldSetupManager):
	world_setup_manager = manager

static func is_position_safe(pos: Vector2) -> bool:
	if not world_setup_manager:
		return true  # Fallback if no manager available
	
	var obstacle_data = world_setup_manager.get_obstacle_data()
	
	# Check pits
	for pit in obstacle_data.pits:
		if pos.distance_to(pit.position) < pit.radius + 50:
			return false
	
	# Check pillars
	for pillar in obstacle_data.pillars:
		if pos.distance_to(pillar.position) < pillar.radius + 50:
			return false
	
	return true

static func get_safe_spawn_position(from_pos: Vector2, min_dist: float, max_dist: float) -> Vector2:
	# Try to find a safe position avoiding pits and pillars
	for attempt in range(30):
		var angle = randf() * TAU
		var distance = randf_range(min_dist, max_dist)
		var test_pos = from_pos + Vector2(cos(angle), sin(angle)) * distance
		
		# Check if position is safe from obstacles
		if is_position_safe(test_pos):
			return test_pos
	
	# Fallback to a basic position if all attempts fail
	return from_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))

static func get_random_safe_arena_position(max_radius: float) -> Vector2:
	# Try to find a safe random position in the arena
	for attempt in range(50):
		var x = randf_range(-max_radius, max_radius)
		var y = randf_range(-max_radius, max_radius)
		var test_pos = Vector2(x, y)
		
		# Check if position is safe from obstacles
		if is_position_safe(test_pos):
			return test_pos
	
	# Fallback to a position away from center if all attempts fail
	return Vector2(randf_range(200, 400) * (1.0 if randf() > 0.5 else -1.0), 
				  randf_range(200, 400) * (1.0 if randf() > 0.5 else -1.0))

static func get_circular_positions_around_point(center: Vector2, count: int, radius: float) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	for i in range(count):
		var angle = (TAU / count) * i
		var offset = Vector2(cos(angle), sin(angle)) * radius
		positions.append(center + offset)
	
	return positions

static func get_random_position_in_circle(center: Vector2, radius: float) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(0, radius)
	return center + Vector2(cos(angle), sin(angle)) * distance

static func get_random_position_in_ring(center: Vector2, inner_radius: float, outer_radius: float) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(inner_radius, outer_radius)
	return center + Vector2(cos(angle), sin(angle)) * distance