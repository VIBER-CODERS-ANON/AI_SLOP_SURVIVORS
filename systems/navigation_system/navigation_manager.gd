extends Node
class_name NavigationManager

## Singleton navigation manager that handles pathfinding for all entities
## Uses a combination of NavigationAgent2D and flow fields for optimal performance

static var instance: NavigationManager

signal navigation_ready()

# Navigation settings
const FLOW_FIELD_CELL_SIZE: float = 64.0  # Larger cells for better performance
const PATH_UPDATE_INTERVAL: float = 0.5  # Less frequent updates
const MAX_AGENTS_PER_FRAME: int = 5  # Fewer updates per frame

# Navigation data
var navigation_map_rid: RID
var flow_fields: Dictionary = {}  # target_position -> FlowField
var active_agents: Array[NavigationAgent2D] = []
var agent_update_queue: Array = []
var update_timer: float = 0.0
var current_update_index: int = 0

# Performance metrics
var path_calculations_this_frame: int = 0
var total_active_agents: int = 0

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wait for navigation to be ready
	await get_tree().physics_frame
	
	# Get the default navigation map
	navigation_map_rid = NavigationServer2D.get_maps()[0]
	
	print("🗺️ NavigationManager initialized!")
	navigation_ready.emit()

func _physics_process(_delta):
	update_timer += _delta
	path_calculations_this_frame = 0
	
	# Staggered path updates
	if update_timer >= PATH_UPDATE_INTERVAL:
		update_timer = 0.0
		_process_agent_updates()

## Register a navigation agent for management
func register_agent(agent: NavigationAgent2D) -> void:
	if agent not in active_agents:
		active_agents.append(agent)
		agent_update_queue.append(agent)
		total_active_agents += 1

## Unregister a navigation agent
func unregister_agent(agent: NavigationAgent2D) -> void:
	active_agents.erase(agent)
	agent_update_queue.erase(agent)
	total_active_agents -= 1

## Get or create a flow field for a target position
func get_flow_field(target_position: Vector2) -> FlowField:
	# Quantize position to reduce flow field count
	var quantized_pos = (target_position / FLOW_FIELD_CELL_SIZE).floor() * FLOW_FIELD_CELL_SIZE
	
	if not flow_fields.has(quantized_pos):
		var flow_field = FlowField.new()
		flow_field.target_position = quantized_pos
		flow_field.cell_size = FLOW_FIELD_CELL_SIZE
		flow_field.generate_field(navigation_map_rid)
		flow_fields[quantized_pos] = flow_field
	
	return flow_fields[quantized_pos]

## Get flow direction at a position (for entities using flow fields)
func get_flow_direction(position: Vector2, target_position: Vector2) -> Vector2:
	var flow_field = get_flow_field(target_position)
	return flow_field.get_direction_at(position)

## Process staggered agent updates
func _process_agent_updates():
	var agents_to_update = min(MAX_AGENTS_PER_FRAME, agent_update_queue.size())
	
	for i in range(agents_to_update):
		if agent_update_queue.is_empty():
			break
			
		var agent = agent_update_queue.pop_front()
		if is_instance_valid(agent) and agent in active_agents:
			agent_update_queue.append(agent)  # Re-add to end of queue
			
			# Trigger path recalculation if needed
			if agent.has_method("update_navigation_path"):
				agent.update_navigation_path()
				path_calculations_this_frame += 1

## Update and clean up flow fields
func _update_flow_fields():
	# Clean up unused flow fields
	var to_remove = []
	for pos in flow_fields:
		var field = flow_fields[pos]
		field.usage_timer += get_physics_process_delta_time()
		
		# Remove flow fields not used for 5 seconds
		if field.usage_timer > 5.0:
			to_remove.append(pos)
	
	for pos in to_remove:
		flow_fields.erase(pos)

## Get navigation path using NavigationServer2D
func get_navigation_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	return NavigationServer2D.map_get_path(navigation_map_rid, from, to, true)

## Check if a position is navigable
func is_position_navigable(position: Vector2) -> bool:
	var closest_point = NavigationServer2D.map_get_closest_point(navigation_map_rid, position)
	return position.distance_to(closest_point) < FLOW_FIELD_CELL_SIZE

## Debug visualization
func get_debug_info() -> String:
	return "Active Agents: %d | Flow Fields: %d | Path Calcs/Frame: %d" % [
		total_active_agents,
		flow_fields.size(),
		path_calculations_this_frame
	]

## Flow Field inner class for efficient group pathfinding
class FlowField:
	var target_position: Vector2
	var cell_size: float
	var grid_size: Vector2i
	var grid_origin: Vector2
	var directions: Dictionary = {}  # Vector2i -> Vector2 (direction)
	var costs: Dictionary = {}  # Vector2i -> float (cost to target)
	var usage_timer: float = 0.0
	
	func generate_field(nav_map_rid: RID, max_distance: float = 2000.0):
		# Calculate grid bounds
		var min_bound = target_position - Vector2.ONE * max_distance
		var max_bound = target_position + Vector2.ONE * max_distance
		
		grid_origin = min_bound
		grid_size = Vector2i(
			int((max_bound.x - min_bound.x) / cell_size),
			int((max_bound.y - min_bound.y) / cell_size)
		)
		
		# Initialize with target cell
		var target_cell = world_to_grid(target_position)
		costs[target_cell] = 0.0
		
		# Dijkstra's algorithm to calculate costs
		var open_list = [target_cell]
		var processed = {}
		
		while not open_list.is_empty():
			var current = open_list.pop_front()
			
			if processed.has(current):
				continue
			processed[current] = true
			
			var current_cost = costs.get(current, INF)
			var current_pos = grid_to_world(current)
			
			# Check neighbors
			for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
						   Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var neighbor = current + offset
				var neighbor_pos = grid_to_world(neighbor)
				
				# Check if position is navigable
				if not NavigationServer2D.map_get_closest_point(nav_map_rid, neighbor_pos).is_equal_approx(neighbor_pos):
					continue
				
				var move_cost = offset.length() * cell_size
				var new_cost = current_cost + move_cost
				
				if new_cost < costs.get(neighbor, INF):
					costs[neighbor] = new_cost
					open_list.append(neighbor)
		
		# Calculate flow directions
		for cell in costs:
			var min_cost = INF
			var best_dir = Vector2.ZERO
			
			for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0),
						   Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]:
				var neighbor = cell + offset
				var neighbor_cost = costs.get(neighbor, INF)
				
				if neighbor_cost < min_cost:
					min_cost = neighbor_cost
					best_dir = Vector2(offset).normalized()
			
			directions[cell] = best_dir
		
		usage_timer = 0.0
	
	func world_to_grid(world_pos: Vector2) -> Vector2i:
		return Vector2i((world_pos - grid_origin) / cell_size)
	
	func grid_to_world(grid_pos: Vector2i) -> Vector2:
		return Vector2(grid_pos) * cell_size + grid_origin + Vector2.ONE * cell_size * 0.5
	
	func get_direction_at(world_pos: Vector2) -> Vector2:
		var grid_pos = world_to_grid(world_pos)
		usage_timer = 0.0  # Reset usage timer
		return directions.get(grid_pos, Vector2.ZERO)
