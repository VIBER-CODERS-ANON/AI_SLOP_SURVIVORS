extends MovementController
class_name AIMovementController

## Smart AI movement controller with pathfinding and obstacle avoidance
## Uses NavigationAgent2D for individual pathfinding or flow fields for group movement

@export_group("AI Settings")
@export var use_nav_steering: bool = true
@export var use_flow_field: bool = false  # Disabled for now - causing performance issues
@export var flow_field_threshold: int = 50  # Higher threshold when enabled
@export var path_recalc_distance: float = 24.0  # Recalculate path if target moves this far
@export var arrival_distance: float = 30.0  # Distance to consider "arrived" at target
@export var avoidance_enabled: bool = false
@export var avoidance_priority: int = 1
@export var neighbor_distance: float = 50.0  # For local avoidance
@export var max_neighbors: int = 5  # Reduced for performance
@export var time_horizon: float = 1.0  # Look-ahead time for collision prediction
@export var max_speed_multiplier: float = 1.5  # Can temporarily boost speed for avoidance
@export var path_update_interval: float = 0.3  # seconds

# Navigation components
var navigation_agent: NavigationAgent2D
var target_position: Vector2 = Vector2.INF
var last_target_position: Vector2 = Vector2.INF
var has_valid_path: bool = false

# Steering behaviors
var separation_force: Vector2 = Vector2.ZERO
var avoidance_force: Vector2 = Vector2.ZERO
var desired_velocity: Vector2 = Vector2.ZERO

# Flow field optimization
var using_flow_field: bool = false
var similar_target_count: int = 0

# Debug
var stuck_timer: float = 0.0
var last_position: Vector2
var stuck_threshold: float = 2.0  # Seconds before considering stuck

# Pathfinding cadence
var _pf_timer: float = 0.0

func _ready():
	super._ready()
	
	# Create and configure NavigationAgent2D
	navigation_agent = NavigationAgent2D.new()
	navigation_agent.name = "NavigationAgent2D"
	entity.add_child(navigation_agent)
	
	# Configure agent properties
	navigation_agent.avoidance_enabled = false
	navigation_agent.path_desired_distance = 8.0
	navigation_agent.target_desired_distance = 8.0
	navigation_agent.path_max_distance = 2000.0
	navigation_agent.avoidance_priority = avoidance_priority
	navigation_agent.neighbor_distance = neighbor_distance
	navigation_agent.max_neighbors = max_neighbors
	navigation_agent.time_horizon = time_horizon
	navigation_agent.max_speed = entity.move_speed * max_speed_multiplier
	navigation_agent.debug_enabled = OS.is_debug_build()
	
	# Skip navigation manager for now
	# if NavigationManager.instance:
	# 	NavigationManager.instance.register_agent(navigation_agent)
	
	# Connect signals
	navigation_agent.navigation_finished.connect(_on_navigation_finished)
	navigation_agent.target_reached.connect(_on_target_reached)
	navigation_agent.velocity_computed.connect(_on_velocity_computed)
	
	last_position = entity.global_position

func _exit_tree():
	# Skip navigation manager for now
	pass
	# if NavigationManager.instance and navigation_agent:
	# 	NavigationManager.instance.unregister_agent(navigation_agent)

func set_target_position(pos: Vector2) -> void:
	target_position = pos  # do NOT set agent.target_position here
	has_valid_path = true
	
	# Skip flow field check for now
	# _check_flow_field_usage()
	using_flow_field = false

func _get_movement_input() -> Vector2:
	return compute_goal_steering(get_physics_process_delta_time())

# Provide pathfinding steering for the base entity to sum
func compute_goal_steering(delta: float) -> Vector2:
	if not use_nav_steering or target_position == Vector2.INF:
		return Vector2.ZERO
	
	if navigation_agent.is_navigation_finished():
		return Vector2.ZERO
	
	var next_pos := navigation_agent.get_next_path_position()
	var dir := next_pos - entity.global_position
	return dir.normalized() if dir.length_squared() > 1e-4 else Vector2.ZERO

func _physics_process(delta: float) -> void:
	# Check if AI/movement is disabled
	if DebugSettings.instance:
		if not DebugSettings.instance.mob_ai_enabled:
			return
		if not DebugSettings.instance.mob_movement_enabled:
			return
		if not DebugSettings.instance.pathfinding_enabled:
			return
	
	super._physics_process(delta)
	_pf_timer -= delta
	if _pf_timer <= 0.0 and has_valid_path:
		if target_position.distance_to(navigation_agent.target_position) > path_recalc_distance:
			navigation_agent.target_position = target_position
		_pf_timer = path_update_interval

func _calculate_steering_forces():
	separation_force = Vector2.ZERO
	avoidance_force = Vector2.ZERO
	
	if not avoidance_enabled:
		return
	
	# Get nearby entities for separation
	var neighbors = _get_nearby_entities(neighbor_distance)
	
	# Separation force (keep distance from others)
	for neighbor in neighbors:
		var to_neighbor = neighbor.global_position - entity.global_position
		var distance = to_neighbor.length()
		
		if distance > 0 and distance < neighbor_distance:
			var repulsion = -to_neighbor.normalized() * (1.0 - distance / neighbor_distance)
			separation_force += repulsion * 100.0  # Separation strength
	
	# Predictive avoidance for imminent collisions
	for neighbor in neighbors:
		if _will_collide_with(neighbor):
			var avoid_dir = _get_avoidance_direction(neighbor)
			avoidance_force += avoid_dir * 200.0  # Avoidance strength

func _get_nearby_entities(radius: float) -> Array:
	# Prefer FlockingSystem's grid to avoid O(n) group scans
	if FlockingSystem.instance:
		return FlockingSystem.instance.get_neighbors(entity, max_neighbors)
	# Fallback (rarely used)
	var neighbors := []
	var all_entities = entity.get_tree().get_nodes_in_group("entities")
	for other in all_entities:
		if other == entity:
			continue
		var distance = entity.global_position.distance_to(other.global_position)
		if distance <= radius:
			neighbors.append(other)
		if neighbors.size() >= max_neighbors:
			break
	return neighbors

func _will_collide_with(other: Node2D) -> bool:
	if not other.has_method("get_velocity"):
		return false
	
	var relative_pos = other.global_position - entity.global_position
	var relative_vel = other.velocity - entity.velocity
	
	# Check if they're moving towards each other
	if relative_pos.dot(relative_vel) >= 0:
		return false
	
	# Simple time to collision calculation
	var collision_time = -relative_pos.dot(relative_vel) / relative_vel.length_squared()
	
	if collision_time < 0 or collision_time > time_horizon:
		return false
	
	# Check distance at closest approach
	var future_distance = (relative_pos + relative_vel * collision_time).length()
	return future_distance < (neighbor_distance * 0.5)

func _get_avoidance_direction(other: Node2D) -> Vector2:
	var to_other = other.global_position - entity.global_position
	
	# Perpendicular avoidance direction
	var avoidance_dir = Vector2(-to_other.y, to_other.x).normalized()
	
	# Choose direction based on relative position
	if entity.global_position.x > other.global_position.x:
		avoidance_dir *= -1
	
	return avoidance_dir

func _check_if_stuck():
	var movement_delta = entity.global_position.distance_to(last_position)
	
	if movement_delta < 5.0:  # Barely moved
		stuck_timer += get_physics_process_delta_time()
		
		if stuck_timer > stuck_threshold:
			_handle_stuck()
			stuck_timer = 0.0
	else:
		stuck_timer = 0.0
		last_position = entity.global_position

func _handle_stuck():
	# Try a random direction
	var random_angle = randf() * TAU
	var push_direction = Vector2.from_angle(random_angle)
	entity.movement_velocity = push_direction * entity.move_speed * 2.0
	
	# Force recalculate path
	if not using_flow_field and navigation_agent:
		navigation_agent.target_position = target_position

func _check_flow_field_usage():
	# Count entities with similar targets
	similar_target_count = 0
	var all_ai = get_tree().get_nodes_in_group("ai_controlled")
	
	for ai in all_ai:
		if ai == entity:
			continue
			
		var controller = ai.get_node_or_null("AIMovementController")
		if controller and controller.target_position.distance_to(target_position) < 100.0:
			similar_target_count += 1
	
	# Switch to flow field if many entities have similar target
	using_flow_field = use_flow_field and similar_target_count >= flow_field_threshold

func _on_navigation_finished():
	has_valid_path = false

func _on_target_reached():
	has_valid_path = false
	# Emit signal or callback for reaching target
	if entity.has_method("_on_target_reached"):
		entity._on_target_reached()

func _on_velocity_computed(safe_velocity: Vector2):
	# NavigationAgent2D computed a safe velocity considering avoidance
	entity.movement_velocity = safe_velocity

func update_navigation_path():
	if not using_flow_field and navigation_agent:
		navigation_agent.target_position = target_position
		has_valid_path = true
