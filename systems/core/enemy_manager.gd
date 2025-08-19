extends Node
class_name EnemyManager

## DATA-ORIENTED ENEMY SYSTEM
## Handles thousands of enemies using packed arrays instead of individual Nodes
## Uses MultiMeshInstance2D for rendering, spatial grid for collision, flow-field for pathfinding

signal enemy_died(enemy_id: int, killer_name: String, death_cause: String)

static var instance: EnemyManager

# Maximum enemy capacity (preallocated)
const MAX_ENEMIES: int = 1000

# Entity data storage (Structure of Arrays)
var positions: PackedVector2Array
var velocities: PackedVector2Array
var healths: PackedFloat32Array
var max_healths: PackedFloat32Array
var scales: PackedFloat32Array
var rotations: PackedFloat32Array
var move_speeds: PackedFloat32Array
var attack_damages: PackedFloat32Array
var attack_cooldowns: PackedFloat32Array
var last_attack_times: PackedFloat32Array

# Behavior tuning (exported for easy tweaking)
@export_group("Behavior Tuning")
@export var avoid_arena_margin: float = 45.0
@export var pit_avoid_buffer: float = 35.0
@export var pillar_avoid_buffer: float = 35.0
@export var flow_block_buffer: float = 18.0
@export var avoidance_weight: float = 1.5

# Lightweight behavior variability (per-enemy)
var behavior_strafe_dir: PackedFloat32Array     # -1 or +1 (preferred perpendicular side)
var behavior_wander_phase: PackedFloat32Array   # evolving phase for sin-based wander
var behavior_wander_speed: PackedFloat32Array   # radians/sec for wander phase advance
var speed_jitter: PackedFloat32Array            # per-enemy speed multiplier (~0.9-1.2)
var burst_timer: PackedFloat32Array             # seconds remaining of speed burst
var burst_cooldown: PackedFloat32Array          # seconds until next burst

# Entity metadata
var alive_flags: PackedByteArray  # 0 = dead, 1 = alive
var entity_types: PackedByteArray  # 0 = rat, 1 = succubus, 2 = woodland_joe, 3 = thor_enemy, 4 = mika_boss, 5 = forsen_boss
var chatter_usernames: Array[String]  # Username for each entity
var chatter_colors: PackedColorArray  # Color for each entity
var rarity_types: PackedByteArray  # NPCRarity.Type per entity (COMMON/MAGIC/RARE/UNIQUE)

# Entity pooling
var free_ids: Array[int]  # Available entity IDs
var active_count: int = 0  # Number of alive entities

# Rendering system
var multi_mesh_instance: MultiMeshInstance2D
var multi_mesh_minion_succubus: MultiMeshInstance2D
var multi_mesh_minion_woodland: MultiMeshInstance2D
var multi_mesh_boss_thor: MultiMeshInstance2D
var multi_mesh_boss_mika: MultiMeshInstance2D
var multi_mesh_boss_forsen: MultiMeshInstance2D
var multi_mesh_boss_zzran: MultiMeshInstance2D
var rat_mesh: QuadMesh
var succubus_mesh: QuadMesh
var woodland_joe_mesh: QuadMesh

# Spatial grid for collision optimization
const GRID_SIZE: float = 100.0
var spatial_grid: Dictionary = {}  # Vector2i -> Array[int] (entity IDs)

# Flow-field pathfinding
var flow_field: Dictionary = {}  # Vector2i -> Vector2 (movement direction)
var flow_field_dirty: bool = true
var player_position: Vector2 = Vector2.ZERO
const FLOW_FIELD_MAX_RADIUS_CELLS: int = 20
var last_player_grid: Vector2i = Vector2i(0, 0)
var has_last_player_grid: bool = false

# Processing optimization
var update_slice_size: int = 50  # Process N entities per frame - smaller for smoother movement
var current_slice_offset: int = 0

# Live subset update cadence (reduce heavy selection every frame)
const LIVE_SUBSET_UPDATE_INTERVAL: float = 0.12
var live_subset_timer: float = 0.0

# Live subset for collision (nearest enemies get physics bodies)
const MAX_LIVE_ENEMIES: int = 50
var live_enemy_ids: Array[int] = []
var live_enemy_bodies: Array[CharacterBody2D] = []  # Pooled collision bodies

# Performance settings
var enable_flow_field: bool = true
var enable_spatial_grid: bool = true
var enable_collision_optimization: bool = true

# Dense instance mapping for MultiMesh efficiency
var instance_to_enemy_map: Dictionary = {}  # instance_index -> enemy_id
var enemy_to_instance_map: Dictionary = {}  # enemy_id -> instance_index
var next_instance_index: int = 0

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	print("🧠 EnemyManager starting initialization...")
	
	# Initialize arrays with maximum capacity (deferred to avoid blocking)
	call_deferred("_initialize_arrays")
	print("⚠️ Array initialization deferred")
	
	# Setup MultiMesh rendering
	_setup_multimesh_rendering()
	print("✅ MultiMesh rendering setup")
	
	# Setup collision body pool
	call_deferred("_setup_collision_body_pool")
	print("✅ Collision body pool queued for setup")
	
	print("🧠 EnemyManager initialized - capacity: %d enemies" % MAX_ENEMIES)

func _initialize_arrays():
	print("🔧 Starting array initialization with capacity: %d" % MAX_ENEMIES)
	
	# Initialize arrays with initial capacity
	var initial_capacity = 100  # Start with 100 entities
	
	positions = PackedVector2Array()
	positions.resize(initial_capacity)
	velocities = PackedVector2Array()
	velocities.resize(initial_capacity)
	healths = PackedFloat32Array()
	healths.resize(initial_capacity)
	max_healths = PackedFloat32Array()
	max_healths.resize(initial_capacity)
	scales = PackedFloat32Array()
	scales.resize(initial_capacity)
	rotations = PackedFloat32Array()
	rotations.resize(initial_capacity)
	move_speeds = PackedFloat32Array()
	move_speeds.resize(initial_capacity)
	attack_damages = PackedFloat32Array()
	attack_damages.resize(initial_capacity)
	attack_cooldowns = PackedFloat32Array()
	attack_cooldowns.resize(initial_capacity)
	last_attack_times = PackedFloat32Array()
	last_attack_times.resize(initial_capacity)
	# Behavior arrays
	behavior_strafe_dir = PackedFloat32Array()
	behavior_strafe_dir.resize(initial_capacity)
	behavior_wander_phase = PackedFloat32Array()
	behavior_wander_phase.resize(initial_capacity)
	behavior_wander_speed = PackedFloat32Array()
	behavior_wander_speed.resize(initial_capacity)
	speed_jitter = PackedFloat32Array()
	speed_jitter.resize(initial_capacity)
	burst_timer = PackedFloat32Array()
	burst_timer.resize(initial_capacity)
	burst_cooldown = PackedFloat32Array()
	burst_cooldown.resize(initial_capacity)
	
	alive_flags = PackedByteArray()
	alive_flags.resize(initial_capacity)
	entity_types = PackedByteArray()
	entity_types.resize(initial_capacity)
	chatter_usernames = []
	chatter_usernames.resize(initial_capacity)
	chatter_colors = PackedColorArray()
	chatter_colors.resize(initial_capacity)
	rarity_types = PackedByteArray()
	rarity_types.resize(initial_capacity)
	
	# Initialize free ID pool with initial capacity
	free_ids.clear()
	for i in range(initial_capacity):
		free_ids.append(initial_capacity - 1 - i)
		alive_flags[i] = 0
	
	print("✅ Array initialization completed - initial capacity: %d" % initial_capacity)

func _setup_multimesh_rendering():
	# Create MultiMeshInstance2D
	multi_mesh_instance = MultiMeshInstance2D.new()
	multi_mesh_instance.name = "EnemyMultiMesh"
	add_child(multi_mesh_instance)
	
	# Create MultiMesh resource
	var multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_2D
	multi_mesh.instance_count = MAX_ENEMIES
	
	# Create quad mesh for rendering
	rat_mesh = QuadMesh.new()
	rat_mesh.size = Vector2(32, 32)  # Base sprite size
	multi_mesh.mesh = rat_mesh
	
	multi_mesh_instance.multimesh = multi_mesh
	
	# Load and assign texture to MultiMeshInstance2D
	var texture_path = "res://entities/enemies/regular/twitch_rat/twitch_rat.png"
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		multi_mesh_instance.texture = texture
	else:
		print("⚠️ Rat texture not found at: ", texture_path)

	# Create per-boss-type MultiMeshes using BespokeAssetSources

	# Create per-minion-type MultiMeshes for unique visuals
	multi_mesh_minion_succubus = MultiMeshInstance2D.new()
	multi_mesh_minion_succubus.name = "MinionMultiMesh_Succubus"
	add_child(multi_mesh_minion_succubus)
	var mm_succ = MultiMesh.new()
	mm_succ.transform_format = MultiMesh.TRANSFORM_2D
	mm_succ.instance_count = MAX_ENEMIES
	# Reuse quad mesh sizes, allow different scale via stats
	var succ_mesh = QuadMesh.new()
	succ_mesh.size = Vector2(32, 32)
	mm_succ.mesh = succ_mesh
	multi_mesh_minion_succubus.multimesh = mm_succ
	# Succubus texture (fallback to rat)
	var succ_tex_path = "res://BespokeAssetSources/Succubus/succubusSpritesheet6framesUPDATE2.png"
	if ResourceLoader.exists(succ_tex_path):
		multi_mesh_minion_succubus.texture = load(succ_tex_path)
	else:
		multi_mesh_minion_succubus.texture = multi_mesh_instance.texture

	multi_mesh_minion_woodland = MultiMeshInstance2D.new()
	multi_mesh_minion_woodland.name = "MinionMultiMesh_WoodlandJoe"
	add_child(multi_mesh_minion_woodland)
	var mm_wood = MultiMesh.new()
	mm_wood.transform_format = MultiMesh.TRANSFORM_2D
	mm_wood.instance_count = MAX_ENEMIES
	var wjoe_mesh = QuadMesh.new()
	wjoe_mesh.size = Vector2(32, 32)
	mm_wood.mesh = wjoe_mesh
	multi_mesh_minion_woodland.multimesh = mm_wood
	var wjoe_tex_path = "res://entities/enemies/woodland_joe.png"
	if ResourceLoader.exists(wjoe_tex_path):
		multi_mesh_minion_woodland.texture = load(wjoe_tex_path)
	else:
		multi_mesh_minion_woodland.texture = multi_mesh_instance.texture
	# Thor
	multi_mesh_boss_thor = MultiMeshInstance2D.new()
	multi_mesh_boss_thor.name = "BossMultiMesh_Thor"
	add_child(multi_mesh_boss_thor)
	var boss_mesh_thor = MultiMesh.new()
	boss_mesh_thor.transform_format = MultiMesh.TRANSFORM_2D
	boss_mesh_thor.instance_count = MAX_ENEMIES
	boss_mesh_thor.mesh = rat_mesh
	multi_mesh_boss_thor.multimesh = boss_mesh_thor
	var thor_tex_path = "res://BespokeAssetSources/asmon1.png"  # fallback visual for Thor
	if not ResourceLoader.exists(thor_tex_path):
		thor_tex_path = "res://entities/enemies/bosses/thor/pirate_skull.png"
	if ResourceLoader.exists(thor_tex_path):
		multi_mesh_boss_thor.texture = load(thor_tex_path)
	else:
		print("⚠️ Thor texture not found at:", thor_tex_path)
	# Mika
	multi_mesh_boss_mika = MultiMeshInstance2D.new()
	multi_mesh_boss_mika.name = "BossMultiMesh_Mika"
	add_child(multi_mesh_boss_mika)
	var boss_mesh_mika = MultiMesh.new()
	boss_mesh_mika.transform_format = MultiMesh.TRANSFORM_2D
	boss_mesh_mika.instance_count = MAX_ENEMIES
	boss_mesh_mika.mesh = rat_mesh
	multi_mesh_boss_mika.multimesh = boss_mesh_mika
	var mika_tex_path = "res://BespokeAssetSources/mika.png"
	if ResourceLoader.exists(mika_tex_path):
		multi_mesh_boss_mika.texture = load(mika_tex_path)
	else:
		print("⚠️ Mika texture not found at:", mika_tex_path)
	# Forsen
	multi_mesh_boss_forsen = MultiMeshInstance2D.new()
	multi_mesh_boss_forsen.name = "BossMultiMesh_Forsen"
	add_child(multi_mesh_boss_forsen)
	var boss_mesh_forsen = MultiMesh.new()
	boss_mesh_forsen.transform_format = MultiMesh.TRANSFORM_2D
	boss_mesh_forsen.instance_count = MAX_ENEMIES
	boss_mesh_forsen.mesh = rat_mesh
	multi_mesh_boss_forsen.multimesh = boss_mesh_forsen
	var forsen_tex_path = "res://BespokeAssetSources/forsen/forsen.png"
	if ResourceLoader.exists(forsen_tex_path):
		multi_mesh_boss_forsen.texture = load(forsen_tex_path)
	else:
		print("⚠️ Forsen texture not found at:", forsen_tex_path)
	# ZZran
	multi_mesh_boss_zzran = MultiMeshInstance2D.new()
	multi_mesh_boss_zzran.name = "BossMultiMesh_ZZran"
	add_child(multi_mesh_boss_zzran)
	var boss_mesh_zzran = MultiMesh.new()
	boss_mesh_zzran.transform_format = MultiMesh.TRANSFORM_2D
	boss_mesh_zzran.instance_count = MAX_ENEMIES
	boss_mesh_zzran.mesh = rat_mesh
	multi_mesh_boss_zzran.multimesh = boss_mesh_zzran
	var zzran_tex_path = "res://BespokeAssetSources/ziz/zizidle.png"
	if ResourceLoader.exists(zzran_tex_path):
		multi_mesh_boss_zzran.texture = load(zzran_tex_path)
	else:
		print("⚠️ ZZran texture not found at:", zzran_tex_path)

func _setup_collision_body_pool():
	print("🔧 Setting up collision body pool...")
	# Pre-create collision bodies for the live subset
	live_enemy_bodies.clear()
	for i in range(MAX_LIVE_ENEMIES):
		var body = CharacterBody2D.new()
		body.name = "LiveEnemyBody_" + str(i)
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 16.0
		collision.shape = shape
		body.add_child(collision)
		
		# Set up collision layers - start disabled until assigned
		body.collision_layer = 0
		body.collision_mask = 0
		# Attach bridge script for damage/knockback API
		body.set_script(preload("res://systems/bridge/enemy_body.gd"))
		
		# Start disabled
		body.set_physics_process(false)
		body.visible = false
		
		add_child(body)
		live_enemy_bodies.append(body)
	
	print("✅ Collision body pool created - %d bodies" % MAX_LIVE_ENEMIES)

func _physics_process(delta: float):
	if get_tree().paused:
		return
	
	# Update player position for flow-field
	if GameController.instance and GameController.instance.player:
		player_position = GameController.instance.player.global_position
		var current_grid = Vector2i(player_position / GRID_SIZE)
		if not has_last_player_grid or current_grid != last_player_grid:
			flow_field_dirty = true
			last_player_grid = current_grid
			has_last_player_grid = true
	
	# Update flow-field if needed
	if enable_flow_field and flow_field_dirty:
		_update_flow_field()
		flow_field_dirty = false
	
	# Process entities in slices to spread CPU cost
	_process_enemy_slice(delta)

	# Integrate positions and behavior timers for all alive enemies every frame
	_integrate_positions_and_behaviors(delta)
	
	# Update spatial grid
	if enable_spatial_grid:
		_update_spatial_grid()
	
	# Update live enemy subset
	if enable_collision_optimization:
		live_subset_timer += delta
		if live_subset_timer >= LIVE_SUBSET_UPDATE_INTERVAL:
			live_subset_timer = 0.0
			_update_live_enemy_subset()
		else:
			_update_live_bodies_positions_only()
	
	# Update rendering
	_update_multimesh_transforms()

func spawn_enemy(enemy_type: int, position: Vector2, username: String, color: Color) -> int:
	# Check if we need to grow arrays
	if free_ids.is_empty():
		_grow_arrays()
	
	if free_ids.is_empty():
		print("⚠️ EnemyManager: No free enemy slots available!")
		return -1
	
	# Get next available ID
	var id = free_ids.pop_back()
	
	# Set basic data
	positions[id] = position
	velocities[id] = Vector2.ZERO
	alive_flags[id] = 1
	spatial_grid_dirty = true
	entity_types[id] = enemy_type
	chatter_usernames[id] = username
	chatter_colors[id] = color
	rarity_types[id] = 0  # Default COMMON
	scales[id] = 1.0
	rotations[id] = 0.0
	last_attack_times[id] = 0.0
	# Initialize behavior variability
	speed_jitter[id] = randf_range(0.9, 1.2)
	behavior_strafe_dir[id] = -1.0 if randf() < 0.5 else 1.0
	behavior_wander_phase[id] = randf() * TAU
	behavior_wander_speed[id] = randf_range(1.0, 3.0)
	burst_timer[id] = 0.0
	burst_cooldown[id] = randf_range(0.8, 2.0)
	
	# Apply stats from configuration system
	var enemy_type_str = _get_type_name_string(enemy_type)
	if EnemyConfigManager.instance:
		EnemyConfigManager.instance.apply_config_to_enemy(id, enemy_type_str, self)
	else:
		# Fallback to hardcoded stats
		match enemy_type:
			0: # Rat
				max_healths[id] = 10.0
				healths[id] = 10.0
				move_speeds[id] = 80.0
				attack_damages[id] = 1.0
				attack_cooldowns[id] = 1.0
			1: # Succubus
				max_healths[id] = 25.0
				healths[id] = 25.0
				move_speeds[id] = 100.0
				attack_damages[id] = 3.0
				attack_cooldowns[id] = 1.5
			2: # Woodland Joe
				max_healths[id] = 40.0
				healths[id] = 40.0
				move_speeds[id] = 80.0
				attack_damages[id] = 5.0
				attack_cooldowns[id] = 2.0
			3: # Thor Enemy - matches thor.tres
				max_healths[id] = 150.0
				healths[id] = 150.0
				move_speeds[id] = 60.0
				attack_damages[id] = 12.0
				attack_cooldowns[id] = 2.5
			4: # Mika Boss - matches mika.tres
				max_healths[id] = 120.0
				healths[id] = 120.0
				move_speeds[id] = 80.0
				attack_damages[id] = 10.0
				attack_cooldowns[id] = 1.5
			5: # Forsen Boss - matches forsen.tres
				max_healths[id] = 180.0
				healths[id] = 180.0
				move_speeds[id] = 55.0
				attack_damages[id] = 14.0
				attack_cooldowns[id] = 2.8
			6: # ZZran Boss - matches zzran.tres
				max_healths[id] = 200.0
				healths[id] = 200.0
				move_speeds[id] = 40.0
				attack_damages[id] = 15.0
				attack_cooldowns[id] = 3.0
	
	active_count += 1

	# Assign rarity for V2 minions via NPCRarityManager (no visuals, stat/tint only)
	if NPCRarityManager.get_instance():
		var rarity_mgr = NPCRarityManager.get_instance()
		# Only apply to minion types (0..2)
		if enemy_type <= 2:
			var rarity = rarity_mgr.draw_random_rarity()
			_apply_rarity_modifiers_v2(id, rarity)
	print("👾 Spawned enemy ID %d (%s) for %s at %s" % [id, _get_type_name(enemy_type), username, position])
	
	# Notify bridge system
	if EnemyBridge.instance:
		EnemyBridge.instance.on_enemy_spawned(id, enemy_type_str)
	
	return id

func despawn_enemy(id: int):
	if id < 0 or id >= alive_flags.size() or alive_flags[id] == 0:
		return
	
	# Notify bridge before despawning
	if EnemyBridge.instance:
		EnemyBridge.instance.on_enemy_despawned(id)
	
	alive_flags[id] = 0
	spatial_grid_dirty = true
	free_ids.append(id)
	active_count -= 1
	
	# Remove from spatial grid
	var grid_pos = Vector2i(positions[id] / GRID_SIZE)
	if spatial_grid.has(grid_pos):
		var cell_entities = spatial_grid[grid_pos] as Array[int]
		cell_entities.erase(id)
		if cell_entities.is_empty():
			spatial_grid.erase(grid_pos)
	
	# Remove from live subset if present (hide body immediately)
	var live_index = live_enemy_ids.find(id)
	if live_index >= 0 and live_index < live_enemy_bodies.size():
		var body = live_enemy_bodies[live_index]
		live_enemy_ids.remove_at(live_index)
		body.set_physics_process(false)
		body.visible = false
		# Fully disable collisions when released
		body.collision_layer = 0
		body.collision_mask = 0
		body.set_meta("enemy_id", null)

func damage_enemy(id: int, damage: float, killer_name: String = "", death_cause: String = ""):
	if id < 0 or id >= alive_flags.size() or alive_flags[id] == 0:
		return
	
	healths[id] = max(0, healths[id] - damage)
	
	if healths[id] <= 0:
		enemy_died.emit(id, killer_name, death_cause)
		_drop_xp_orb(id)
		despawn_enemy(id)

func _process_enemy_slice(delta: float):
	# Process a slice of enemies each frame to spread CPU cost
	var array_size = positions.size()
	var slice_end = min(current_slice_offset + update_slice_size, array_size)
	
	for i in range(current_slice_offset, slice_end):
		if i >= alive_flags.size() or alive_flags[i] == 0:
			continue
		
		_update_enemy_movement(i, delta)
		_update_enemy_attack(i, delta)
	
	# Advance to next slice
	current_slice_offset = slice_end
	if current_slice_offset >= array_size:
		current_slice_offset = 0

func _update_enemy_movement(id: int, delta: float):
	var current_pos = positions[id]
	
	# Get flow-field direction
	var target_direction = Vector2.ZERO
	if enable_flow_field:
		var grid_pos = Vector2i(current_pos / GRID_SIZE)
		if flow_field.has(grid_pos):
			target_direction = flow_field[grid_pos]
		else:
			# Fallback: move toward player
			target_direction = (player_position - current_pos).normalized()
	else:
		target_direction = (player_position - current_pos).normalized()
	
	# Add variability: wander/strafe + speed jitter + periodic bursts
	if target_direction == Vector2.ZERO:
		target_direction = (player_position - current_pos).normalized()
	var strafe_strength: float = sin(behavior_wander_phase[id]) * 0.5  # side sway up to 0.5x
	var perpendicular: Vector2 = Vector2(-target_direction.y, target_direction.x) * behavior_strafe_dir[id]
	# Cheap obstacle avoidance
	var avoid: Vector2 = _compute_avoidance_vector(current_pos) * avoidance_weight
	# Optional boids-lite from FlockingSystem (V2 arrays)
	var flock_force := Vector2.ZERO
	if FlockingSystem.instance:
		flock_force = FlockingSystem.instance.get_v2_force(id)
	var combined_direction: Vector2 = (target_direction + perpendicular * strafe_strength + avoid + flock_force).normalized()
	
	# Effective speed with jitter and bursts
	var effective_speed: float = move_speeds[id] * speed_jitter[id]
	# Apply burst if active, or occasionally trigger one when off cooldown
	if burst_timer[id] > 0.0:
		effective_speed *= 1.85
	elif burst_cooldown[id] <= 0.0:
		burst_timer[id] = randf_range(0.15, 0.4)
		burst_cooldown[id] = randf_range(1.0, 2.0)
	
	# Apply movement with smoothing
	var target_velocity = combined_direction * effective_speed
	
	# Smooth velocity transitions to reduce jankiness
	var current_velocity = velocities[id]
	# Scale smoothing by slice size so infrequently updated entities catch up smoothly
	var total_count = max(1, min(positions.size(), alive_flags.size()))
	var slice_factor: float = max(1.0, float(total_count) / float(max(1, update_slice_size)))
	var lerp_factor = min(delta * 8.0 * slice_factor, 1.0)  # Smooth transitions
	velocities[id] = current_velocity.lerp(target_velocity, lerp_factor)
	
	# Position integration moved to _integrate_positions_and_behaviors for smoother motion
	
	# Update rotation to face movement direction with smoothing
	if velocities[id].length() > 10.0:  # Only rotate when moving with meaningful speed
		var target_rotation = velocities[id].angle()
		rotations[id] = lerp_angle(rotations[id], target_rotation, delta * 6.0)

func _update_enemy_attack(id: int, _delta: float):
	var time_seconds = Time.get_ticks_msec() / 1000.0
	
	# Check if can attack
	if time_seconds - last_attack_times[id] < attack_cooldowns[id]:
		return
	
	# Check if close enough to player to attack
	var distance_to_player = positions[id].distance_to(player_position)
	if distance_to_player > 60.0:  # Attack range
		return
	
	# Perform attack (damage will be handled by player collision detection)
	last_attack_times[id] = time_seconds

func _integrate_positions_and_behaviors(delta: float):
	# Lightweight per-frame integration for smooth motion
	var array_size = min(positions.size(), alive_flags.size())
	var any_moved := false
	for i in range(array_size):
		if alive_flags[i] == 0:
			continue
		positions[i] += velocities[i] * delta
		any_moved = true
		# Advance wander phase every frame for smooth strafe
		behavior_wander_phase[i] += behavior_wander_speed[i] * delta
		# Update burst timers/cooldowns steadily
		if burst_timer[i] > 0.0:
			burst_timer[i] = max(0.0, burst_timer[i] - delta)
		else:
			burst_cooldown[i] = max(0.0, burst_cooldown[i] - delta)
	if any_moved:
		spatial_grid_dirty = true  # Mark grid as needing update

func _update_flow_field():
	# Simple flow-field: BFS from player position
	flow_field.clear()
	
	var grid_player_pos = Vector2i(player_position / GRID_SIZE)
	var queue: Array[Vector2i] = [grid_player_pos]
	var visited: Dictionary = {grid_player_pos: true}
	var directions: Dictionary = {grid_player_pos: Vector2.ZERO}
	
	# BFS to create flow field
	while not queue.is_empty():
		var current = queue.pop_front()
		
		# Check 8 directions
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				
				var neighbor = Vector2i(current.x + dx, current.y + dy)
				# Bound search to a finite radius around the player to avoid infinite expansion
				if abs(neighbor.x - grid_player_pos.x) > FLOW_FIELD_MAX_RADIUS_CELLS or abs(neighbor.y - grid_player_pos.y) > FLOW_FIELD_MAX_RADIUS_CELLS:
					continue
				if visited.has(neighbor):
					continue
				# Skip blocked cells (obstacles / walls)
				var cell_world: Vector2 = Vector2(neighbor) * GRID_SIZE
				if _is_world_pos_blocked(cell_world):
					continue
				
				visited[neighbor] = true
				queue.append(neighbor)
				
				# Direction points toward current cell (toward player)
				var direction = Vector2(dx, dy).normalized()
				directions[neighbor] = -direction  # Negative to point toward player
	
	flow_field = directions

func _compute_avoidance_vector(pos: Vector2) -> Vector2:
	var repel: Vector2 = Vector2.ZERO
	# Avoid arena bounds (assumes 3000x3000)
	var arena_half: float = 1500.0
	var margin: float = avoid_arena_margin
	if pos.x > arena_half - margin:
		repel.x -= (pos.x - (arena_half - margin)) / margin
	elif pos.x < -arena_half + margin:
		repel.x += ((-arena_half + margin) - pos.x) / margin
	if pos.y > arena_half - margin:
		repel.y -= (pos.y - (arena_half - margin)) / margin
	elif pos.y < -arena_half + margin:
		repel.y += ((-arena_half + margin) - pos.y) / margin
	# Avoid pits and pillars
	if GameController.instance:
		var pits = GameController.instance.get_meta("dark_pits", [])
		for pit in pits:
			var ppos: Vector2 = pit.get("position", Vector2.ZERO)
			var prad: float = float(pit.get("radius", 0.0)) + pit_avoid_buffer
			var d = pos - ppos
			var len = d.length()
			if len < prad and len > 0.001:
				repel += d / len * ((prad - len) / prad)
		var pillars = GameController.instance.get_meta("pillars", [])
		for pil in pillars:
			var ppos2: Vector2 = pil.get("position", Vector2.ZERO)
			var prad2: float = float(pil.get("radius", 0.0)) + pillar_avoid_buffer
			var d2 = pos - ppos2
			var len2 = d2.length()
			if len2 < prad2 and len2 > 0.001:
				repel += d2 / len2 * ((prad2 - len2) / prad2)
	return repel

func _is_world_pos_blocked(world_pos: Vector2) -> bool:
	# Blocks near pits/pillars or outside arena bounds
	var arena_half: float = 1500.0
	if abs(world_pos.x) > arena_half - 15.0 or abs(world_pos.y) > arena_half - 15.0:
		return true
	if not GameController.instance:
		return false
	var pits = GameController.instance.get_meta("dark_pits", [])
	for pit in pits:
		var ppos: Vector2 = pit.get("position", Vector2.ZERO)
		var prad: float = float(pit.get("radius", 0.0)) + flow_block_buffer
		if world_pos.distance_to(ppos) < prad:
			return true
	var pillars = GameController.instance.get_meta("pillars", [])
	for pil in pillars:
		var ppos2: Vector2 = pil.get("position", Vector2.ZERO)
		var prad2: float = float(pil.get("radius", 0.0)) + flow_block_buffer
		if world_pos.distance_to(ppos2) < prad2:
			return true
	return false

var spatial_grid_dirty: bool = true

func _update_spatial_grid():
	if not spatial_grid_dirty:
		return
	
	# Rebuild spatial grid for collision optimization
	spatial_grid.clear()
	spatial_grid_dirty = false
	
	var array_size = min(positions.size(), alive_flags.size())
	for i in range(array_size):
		if alive_flags[i] == 0:
			continue
		
		var grid_pos = Vector2i(positions[i] / GRID_SIZE)
		if not spatial_grid.has(grid_pos):
			spatial_grid[grid_pos] = []
		
		spatial_grid[grid_pos].append(i)

func _update_live_enemy_subset():
	# Find nearest enemies to player and give them collision bodies using top-K selection
	var best: Array = []  # dicts with key "d2"
	var worst_index: int = -1
	var worst_d2: float = -1.0
	var array_size = min(positions.size(), alive_flags.size())
	var limit = min(MAX_LIVE_ENEMIES, live_enemy_bodies.size())
	for i in range(array_size):
		if alive_flags[i] == 0:
			continue
		var d2: float = positions[i].distance_squared_to(player_position)
		var item = {"id": i, "d2": d2}
		if best.size() < limit:
			best.append(item)
			if item.d2 > worst_d2:
				worst_d2 = item.d2
				worst_index = best.size() - 1
		else:
			if d2 < worst_d2 and worst_index >= 0:
				best[worst_index] = item
				worst_d2 = -1.0
				worst_index = -1
				for j in range(best.size()):
					if best[j].d2 > worst_d2:
						worst_d2 = best[j].d2
						worst_index = j
	# Sort the selected few for stable assignment
	best.sort_custom(func(a, b): return a.d2 < b.d2)
	
	# Clear current live subset
	var clear_count = min(live_enemy_ids.size(), live_enemy_bodies.size())
	for i in range(clear_count):
		var body = live_enemy_bodies[i]
		body.set_physics_process(false)
		body.visible = false
		body.collision_layer = 0
		body.collision_mask = 0
	live_enemy_ids.clear()
	
	# Assign nearest enemies to collision bodies
	if live_enemy_bodies.size() == 0:
		return
	var assign_count = min(best.size(), min(MAX_LIVE_ENEMIES, live_enemy_bodies.size()))
	for i in range(assign_count):
		var enemy_id = best[i]["id"]
		live_enemy_ids.append(enemy_id)
		
		var body = live_enemy_bodies[i]
		body.global_position = positions[enemy_id]
		body.set_meta("enemy_id", enemy_id)
		# Optionally store chatter info for damage attribution
		if enemy_id < chatter_usernames.size():
			body.set_meta("chatter_username", chatter_usernames[enemy_id])
		body.set_physics_process(true)
		body.visible = true
		# Enable collisions now that it's assigned
		body.collision_layer = 2
		body.collision_mask = 1 | 4
		body.set_meta("enemy_id", enemy_id)

func _update_live_bodies_positions_only():
	# Cheap update: only move existing live bodies; no re-selection
	var count = min(live_enemy_ids.size(), live_enemy_bodies.size())
	for i in range(count):
		var enemy_id: int = live_enemy_ids[i]
		if enemy_id >= 0 and enemy_id < positions.size() and enemy_id < alive_flags.size() and alive_flags[enemy_id] == 1:
			live_enemy_bodies[i].global_position = positions[enemy_id]
		else:
			# Hide invalid entries quickly; full rebuild will happen on next interval
			live_enemy_bodies[i].set_physics_process(false)
			live_enemy_bodies[i].visible = false

func _update_multimesh_transforms():
	if multi_mesh_instance == null or multi_mesh_boss_thor == null or multi_mesh_boss_mika == null or multi_mesh_boss_forsen == null or multi_mesh_boss_zzran == null:
		return
	var minion_mesh = multi_mesh_instance.multimesh
	var minion_succ_mesh = multi_mesh_minion_succubus.multimesh if multi_mesh_minion_succubus else null
	var minion_wood_mesh = multi_mesh_minion_woodland.multimesh if multi_mesh_minion_woodland else null
	var boss_mesh_thor = multi_mesh_boss_thor.multimesh
	var boss_mesh_mika = multi_mesh_boss_mika.multimesh
	var boss_mesh_forsen = multi_mesh_boss_forsen.multimesh
	var boss_mesh_zzran = multi_mesh_boss_zzran.multimesh
	if not minion_mesh or not boss_mesh_thor or not boss_mesh_mika or not boss_mesh_forsen or not boss_mesh_zzran:
		return
	
	# Dense packing per category: minions (0-2), thor(3), mika(4), forsen(5), zzran(6)
	var minion_count = 0
	var minion_succ_count = 0
	var minion_wood_count = 0
	var thor_count = 0
	var mika_count = 0
	var forsen_count = 0
	var zzran_count = 0
	var array_size = min(positions.size(), alive_flags.size())
	
	# Get viewport bounds in world space for simple culling
	var do_cull := false
	var cull_rect := Rect2()
	if GameController.instance and GameController.instance.player and GameController.instance.player.has_node("Camera2D"):
		var cam: Camera2D = GameController.instance.player.get_node("Camera2D")
		var vp_size = cam.get_viewport_rect().size
		var zoom = cam.zoom
		var center = cam.get_screen_center_position()
		var size_world = Vector2(vp_size.x / zoom.x, vp_size.y / zoom.y) * 1.3  # 30% margin
		cull_rect = Rect2(center - size_world * 0.5, size_world)
		do_cull = true

	for enemy_id in range(array_size):
		if alive_flags[enemy_id] == 0:
			continue
		if do_cull and not cull_rect.has_point(positions[enemy_id]):
			continue
		
		var transform = Transform2D()
		transform = transform.rotated(rotations[enemy_id])
		transform = transform.scaled(Vector2.ONE * scales[enemy_id])
		transform.origin = positions[enemy_id]
		
		match int(entity_types[enemy_id]):
			3:
				if thor_count < boss_mesh_thor.instance_count:
					boss_mesh_thor.set_instance_transform_2d(thor_count, transform)
				thor_count += 1
			4:
				if mika_count < boss_mesh_mika.instance_count:
					boss_mesh_mika.set_instance_transform_2d(mika_count, transform)
				mika_count += 1
			5:
				if forsen_count < boss_mesh_forsen.instance_count:
					boss_mesh_forsen.set_instance_transform_2d(forsen_count, transform)
				forsen_count += 1
			6:
				if zzran_count < boss_mesh_zzran.instance_count:
					boss_mesh_zzran.set_instance_transform_2d(zzran_count, transform)
				zzran_count += 1
			1:
				if minion_succ_mesh and minion_succ_count < minion_succ_mesh.instance_count:
					minion_succ_mesh.set_instance_transform_2d(minion_succ_count, transform)
				minion_succ_count += 1
			2:
				if minion_wood_mesh and minion_wood_count < minion_wood_mesh.instance_count:
					minion_wood_mesh.set_instance_transform_2d(minion_wood_count, transform)
				minion_wood_count += 1
			_:
				if minion_count < minion_mesh.instance_count:
					minion_mesh.set_instance_transform_2d(minion_count, transform)
				minion_count += 1
	
	# Update visible counts per mesh
	minion_mesh.visible_instance_count = minion_count
	if minion_succ_mesh:
		minion_succ_mesh.visible_instance_count = minion_succ_count
	if minion_wood_mesh:
		minion_wood_mesh.visible_instance_count = minion_wood_count
	boss_mesh_thor.visible_instance_count = thor_count
	boss_mesh_mika.visible_instance_count = mika_count
	boss_mesh_forsen.visible_instance_count = forsen_count
	boss_mesh_zzran.visible_instance_count = zzran_count

func evolve_enemy(enemy_id: int, new_type_id: int):
	if enemy_id < 0 or enemy_id >= alive_flags.size():
		return
	if alive_flags[enemy_id] == 0:
		return
	entity_types[enemy_id] = new_type_id
	# Reapply stats
	var enemy_type_str = _get_type_name_string(new_type_id)
	if EnemyConfigManager.instance:
		EnemyConfigManager.instance.apply_config_to_enemy(enemy_id, enemy_type_str, self)
	# Notify bridge to rebuild abilities/effects/lighting
	if EnemyBridge.instance:
		EnemyBridge.instance.evolve_enemy(enemy_id, enemy_type_str)

func _drop_xp_orb(enemy_id: int):
	# Check if resource exists before trying to load
	var xp_orb_path = "res://entities/pickups/xp_orb.tscn"
	if not ResourceLoader.exists(xp_orb_path):
		print("⚠️ XP orb scene not found at: ", xp_orb_path)
		return
	
	# Spawn XP orb at enemy position
	var xp_orb_scene = load(xp_orb_path)
	if not xp_orb_scene:
		print("⚠️ Failed to load XP orb scene")
		return
		
	var xp_orb = xp_orb_scene.instantiate()
	xp_orb.global_position = positions[enemy_id]
	
	if GameController.instance:
		GameController.instance.add_child(xp_orb)

func _grow_arrays():
	var current_size = positions.size()
	if current_size >= MAX_ENEMIES:
		return  # Already at max capacity
	
	# Grow by 50% or to MAX_ENEMIES, whichever is smaller
	var new_size = min(int(current_size * 1.5), MAX_ENEMIES)
	
	print("📈 Growing enemy arrays from %d to %d" % [current_size, new_size])
	
	# Resize all arrays
	positions.resize(new_size)
	velocities.resize(new_size)
	healths.resize(new_size)
	max_healths.resize(new_size)
	scales.resize(new_size)
	rotations.resize(new_size)
	move_speeds.resize(new_size)
	attack_damages.resize(new_size)
	attack_cooldowns.resize(new_size)
	last_attack_times.resize(new_size)
	behavior_strafe_dir.resize(new_size)
	behavior_wander_phase.resize(new_size)
	behavior_wander_speed.resize(new_size)
	speed_jitter.resize(new_size)
	burst_timer.resize(new_size)
	burst_cooldown.resize(new_size)
	alive_flags.resize(new_size)
	entity_types.resize(new_size)
	chatter_usernames.resize(new_size)
	chatter_colors.resize(new_size)
	rarity_types.resize(new_size)
	
	# Add new IDs to free pool
	for i in range(current_size, new_size):
		free_ids.append(i)
		alive_flags[i] = 0

func _get_type_name(type: int) -> String:
	match type:
		0: return "Rat"
		1: return "Succubus" 
		2: return "Woodland Joe"
		3: return "Thor Enemy"
		4: return "Mika Boss"
		5: return "Forsen Boss"
		6: return "ZZran Boss"
		_: return "Unknown"

func _apply_rarity_modifiers_v2(enemy_id: int, rarity: NPCRarity):
	if enemy_id < 0 or enemy_id >= alive_flags.size() or alive_flags[enemy_id] == 0:
		return
	# Store rarity type
	rarity_types[enemy_id] = int(rarity.type)
	# Visual scale
	if rarity.scale_modifier != 1.0:
		scales[enemy_id] *= rarity.scale_modifier
	# Health/damage modifiers
	if rarity.health_multiplier != 1.0:
		max_healths[enemy_id] *= rarity.health_multiplier
		healths[enemy_id] = max_healths[enemy_id]
	if rarity.damage_multiplier != 1.0:
		attack_damages[enemy_id] *= rarity.damage_multiplier
	# Light tint by rarity color for visibility (does not affect bosses)
	if int(entity_types[enemy_id]) <= 2 and rarity.type != NPCRarity.Type.COMMON:
		chatter_colors[enemy_id] = chatter_colors[enemy_id].lerp(rarity.color, 0.3)

func _get_type_name_string(type: int) -> String:
	match type:
		0: return "twitch_rat"
		1: return "succubus"
		2: return "woodland_joe"
		3: return "thor_enemy"
		4: return "mika_boss"
		5: return "forsen_boss"
		6: return "zzran_boss"
		_: return "unknown"

func get_enemy_type_from_string(type_string: String) -> int:
	match type_string.to_lower():
		"twitch_rat": return 0
		"succubus": return 1
		"woodland_joe": return 2
		"thor_enemy": return 3
		"mika_boss": return 4
		"forsen_boss": return 5
		"zzran_boss": return 6
		_: return 0  # Default to rat

func get_enemy_position(id: int) -> Vector2:
	if id < 0 or id >= positions.size() or id >= alive_flags.size() or alive_flags[id] == 0:
		return Vector2.ZERO
	return positions[id]

func get_enemies_in_radius(center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	var radius_squared = radius * radius
	
	var array_size = min(positions.size(), alive_flags.size())
	for i in range(array_size):
		if alive_flags[i] == 0:
			continue
		
		if positions[i].distance_squared_to(center) <= radius_squared:
			result.append(i)
	
	return result

func get_active_enemy_count() -> int:
	return active_count

func get_stats() -> Dictionary:
	return {
		"active_enemies": active_count,
		"max_capacity": MAX_ENEMIES,
		"live_subset_size": live_enemy_ids.size(),
		"spatial_grid_cells": spatial_grid.size(),
		"flow_field_cells": flow_field.size()
	}
