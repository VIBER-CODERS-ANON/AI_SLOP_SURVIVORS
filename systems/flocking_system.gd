extends Node
class_name FlockingSystem

## ZOMBIE HORDE FLOCKING SYSTEM
## Creates overwhelming swarms that flow like a living wall of death
## Enemies spread naturally but aggressively pursue the player

static var instance: FlockingSystem

# Flocking parameters - TUNED FOR MAXIMUM HORDE AGGRESSION
@export_group("Flocking Forces")
@export var separation_radius: float = 40.0  # Personal space bubble
@export var separation_force: float = 150.0  # How hard to push apart
@export var alignment_radius: float = 80.0   # Look at neighbors within this range
@export var alignment_force: float = 30.0    # How much to match neighbor direction
@export var cohesion_radius: float = 120.0   # Stay with the pack range
@export var cohesion_force: float = 20.0     # How much to stay together

@export_group("Performance")
@export var neighbor_radius: float = 96.0  # how far to consider neighbors
@export var max_neighbors_check: int = 4  # try 4..6
@export var update_interval: float = 0.15  # recompute + slice ~6-8 Hz (not 1.0)
@export var force_slices: int = 3  # compute 1/N of entities per update
@export var spatial_grid_size: float = 100.0  # Grid size for spatial partitioning

# Spatial optimization
var spatial_grid: Dictionary = {}  # Grid position -> Array of entities
var flock_cache: Dictionary = {}   # Entity -> cached flocking vector
var _elapsed: float = 0.0
var _force_slice: int = 0

# Entity tracking
var flock_entities: Array = []  # All entities in the flock

func _ready():
	instance = self
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	# Check if flocking is disabled
	if DebugSettings.instance and not DebugSettings.instance.flocking_enabled:
		# Clear all forces if disabled
		for entity in flock_entities:
			flock_cache[entity] = Vector2.ZERO
		return
	
	_elapsed += delta
	if _elapsed < update_interval:
		return
	_elapsed = 0.0
	
	_update_spatial_grid()  # keep your existing grid maintenance here
	
	_calculate_flocking_for_slice(_force_slice)
	_force_slice = (_force_slice + 1) % max(1, force_slices)

func register_entity(entity: Node2D):
	if not entity in flock_entities:
		flock_entities.append(entity)
		flock_cache[entity] = Vector2.ZERO

func unregister_entity(entity: Node2D):
	flock_entities.erase(entity)
	flock_cache.erase(entity)

func get_flocking_force(entity: Node2D) -> Vector2:
	# Return cached force (updated every interval)
	return flock_cache.get(entity, Vector2.ZERO)

# Public, grid-backed neighbor lookup without using sorts
func get_neighbors(entity: Node2D, cap: int = max_neighbors_check) -> Array:
	var old_cap := max_neighbors_check
	max_neighbors_check = min(cap, max_neighbors_check)
	var arr := _get_nearby_entities(entity)
	max_neighbors_check = old_cap
	return arr

# Optional alias for clarity
func get_force(entity: Node2D) -> Vector2:
	return get_flocking_force(entity)

func _update_spatial_grid():
	spatial_grid.clear()
	
	for entity in flock_entities:
		if not is_instance_valid(entity):
			continue
			
		var grid_pos = _get_grid_position(entity.global_position)
		if not spatial_grid.has(grid_pos):
			spatial_grid[grid_pos] = []
		spatial_grid[grid_pos].append(entity)

func _get_grid_position(pos: Vector2) -> Vector2i:
	return Vector2i(
		int(pos.x / spatial_grid_size),
		int(pos.y / spatial_grid_size)
	)

func _get_nearby_entities(entity: Node2D) -> Array:
	var out: Array = []
	var r2 := neighbor_radius * neighbor_radius
	var gp := _get_grid_position(entity.global_position)
	
	# Scan 3x3 cells around the entity; stop as soon as we hit the cap.
	for ox in range(-1, 2):
		if out.size() >= max_neighbors_check: break
		for oy in range(-1, 2):
			if out.size() >= max_neighbors_check: break
			var key := Vector2i(gp.x + ox, gp.y + oy)
			var bucket: Array = spatial_grid.get(key, [])
			if bucket.is_empty(): continue
			for other in bucket:
				if other == entity or not is_instance_valid(other): continue
				var d2 := entity.global_position.distance_squared_to(other.global_position)
				if d2 == 0.0 or d2 > r2: continue
				out.append(other)
				if out.size() >= max_neighbors_check: break
	return out

# Only update 1/N of entities this tick; store into flock_cache
func _calculate_flocking_for_slice(slice_idx: int) -> void:
	# Clean up invalid entities first
	var to_remove = []
	for e in flock_entities:
		if not is_instance_valid(e):
			to_remove.append(e)
	for e in to_remove:
		flock_entities.erase(e)
		flock_cache.erase(e)
	
	var n := flock_entities.size()
	if n == 0: return
	var step: int = max(1, force_slices)
	for i in range(slice_idx, n, step):
		if i >= flock_entities.size():
			break
		var e: Node2D = flock_entities[i]
		if not is_instance_valid(e):
			continue
		var neighbors := _get_nearby_entities(e)
		if neighbors.is_empty():
			flock_cache[e] = Vector2.ZERO
			continue
		var sep := _calculate_separation(e, neighbors)
		var ali := _calculate_alignment(e, neighbors)
		var coh := _calculate_cohesion(e, neighbors)
		flock_cache[e] = sep + ali + coh

func _calculate_separation(entity: Node2D, neighbors: Array) -> Vector2:
	## SEPARATION: Push away from neighbors that are too close
	## This prevents stacking and creates natural spreading
	
	var separation_vector = Vector2.ZERO
	var too_close_count = 0
	
	for neighbor in neighbors:
		if not is_instance_valid(neighbor):
			continue
		var distance = entity.global_position.distance_to(neighbor.global_position)
		
		if distance < separation_radius and distance > 0:
			# Calculate push away force
			var push_direction = (entity.global_position - neighbor.global_position).normalized()
			
			# Stronger push the closer they are (inverse square law for dramatic effect)
			var push_strength = 1.0 - (distance / separation_radius)
			push_strength = push_strength * push_strength  # Square for more dramatic close-range repulsion
			
			separation_vector += push_direction * push_strength
			too_close_count += 1
	
	if too_close_count > 0:
		separation_vector = separation_vector.normalized() * separation_force
	
	return separation_vector

func _calculate_alignment(entity: Node2D, neighbors: Array) -> Vector2:
	## ALIGNMENT: Match the average velocity of nearby allies
	## This creates coordinated movement without perfect synchronization
	
	var average_velocity = Vector2.ZERO
	var align_count = 0
	
	for neighbor in neighbors:
		if not is_instance_valid(neighbor):
			continue
		var distance = entity.global_position.distance_to(neighbor.global_position)
		
		if distance < alignment_radius and distance > 0:
			# Get neighbor's velocity if they have it
			if "velocity" in neighbor:
				average_velocity += neighbor.velocity
				align_count += 1
			elif "movement_velocity" in neighbor:
				average_velocity += neighbor.movement_velocity
				align_count += 1
	
	if align_count > 0:
		average_velocity = (average_velocity / align_count).normalized() * alignment_force
		return average_velocity
	
	return Vector2.ZERO

func _calculate_cohesion(entity: Node2D, neighbors: Array) -> Vector2:
	## COHESION: Move toward the average position of the group
	## This keeps the horde together as a mass
	
	var center_of_mass = Vector2.ZERO
	var cohesion_count = 0
	
	for neighbor in neighbors:
		if not is_instance_valid(neighbor):
			continue
		var distance = entity.global_position.distance_to(neighbor.global_position)
		
		if distance < cohesion_radius and distance > 0:
			center_of_mass += neighbor.global_position
			cohesion_count += 1
	
	if cohesion_count > 0:
		center_of_mass = center_of_mass / cohesion_count
		var to_center = (center_of_mass - entity.global_position).normalized() * cohesion_force
		return to_center
	
	return Vector2.ZERO

func get_debug_info() -> String:
	return "Flocking Entities: %d | Grid Cells: %d" % [flock_entities.size(), spatial_grid.size()]

# Special horde behaviors
func apply_horde_surge(center: Vector2, radius: float, force: float):
	## Creates a temporary surge toward a point (like when player is spotted)
	for entity in flock_entities:
		if not is_instance_valid(entity):
			continue
		
		var distance = entity.global_position.distance_to(center)
		if distance < radius:
			var surge_direction = (center - entity.global_position).normalized()
			var surge_force = surge_direction * force * (1.0 - distance / radius)
			flock_cache[entity] = flock_cache.get(entity, Vector2.ZERO) + surge_force

func create_swarm_vortex(center: Vector2, radius: float, angular_force: float):
	## Makes enemies spiral around a point - good for boss summons
	for entity in flock_entities:
		if not is_instance_valid(entity):
			continue
		
		var to_center = center - entity.global_position
		var distance = to_center.length()
		
		if distance < radius and distance > 10:
			# Create tangential force for spiral
			var tangent = Vector2(-to_center.y, to_center.x).normalized()
			var vortex_force = tangent * angular_force * (1.0 - distance / radius)
			flock_cache[entity] = flock_cache.get(entity, Vector2.ZERO) + vortex_force
