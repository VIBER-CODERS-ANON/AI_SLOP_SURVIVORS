extends Node
class_name EnemyManager

## DATA-ORIENTED ENEMY SYSTEM
## Handles thousands of enemies using packed arrays instead of individual Nodes
## Uses MultiMeshInstance2D for rendering, spatial grid for collision, flow-field for pathfinding

signal enemy_died(enemy_id: int, killer_name: String, death_cause: String)

static var instance: EnemyManager

# Maximum enemy capacity (preallocated)
const MAX_ENEMIES: int = 1000

# Enemy movement and attack constants

# AI Types
const AI_TYPE_BASIC_CHASE = 0
const AI_TYPE_RANGED = 1
const AI_TYPE_SPECIAL = 2

# Succubus animation constants
const SUCCUBUS_FRAMES_H: int = 6
const SUCCUBUS_FRAMES_V: int = 1
const SUCCUBUS_ANIM_FPS: float = 8.0
var succubus_mat: ShaderMaterial = null
var _succubus_anim_time: float = 0.0

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
var aoe_scales: PackedFloat32Array  # AOE multiplier for abilities
var regen_rates: PackedFloat32Array  # HP regeneration per second

# Command cooldown tracking
var last_boost_times: PackedFloat32Array  # Last time boost was used per entity
var temporary_speed_boosts: PackedFloat32Array  # Flat speed bonus amount
var boost_end_times: PackedFloat32Array  # When boost expires

# Command constants
const BOOST_COOLDOWN: float = 60.0  # 1 minute cooldown
const BOOST_FLAT_BONUS: float = 500.0  # +500 flat speed
const BOOST_DURATION: float = 1.0  # 1 second duration

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
var _halted: PackedByteArray                    # 0 = moving, 1 = halted near player

# Entity metadata
var alive_flags: PackedByteArray  # 0 = dead, 1 = alive
var entity_types: PackedByteArray  # 0 = rat, 1 = succubus, 2 = woodland_joe (bosses use node-based system)
var ai_types: PackedByteArray  # AI behavior types: 0 = basic_chase, 1 = ranged, 2 = special
var chatter_usernames: Array[String]  # Username for each entity
var chatter_colors: PackedColorArray  # Color for each entity
var rarity_types: PackedByteArray  # NPCRarity.Type per entity (COMMON/MAGIC/RARE/UNIQUE)

# Ability system
var ability_casting_flags: PackedByteArray  # 0 = not casting, 1 = casting (stops movement)
var ability_cooldowns: PackedFloat32Array  # Cooldown timers for abilities

# Damage feedback (white flash)
var flash_timers: PackedFloat32Array  # Timer for white flash effect
const FLASH_DURATION: float = 0.15  # Duration of white flash in seconds

# Entity pooling
var free_ids: Array[int]  # Available entity IDs
var active_count: int = 0  # Number of alive entities

# Rendering system
var multi_mesh_instance: MultiMeshInstance2D
var multi_mesh_minion_succubus: MultiMeshInstance2D
var multi_mesh_minion_woodland: MultiMeshInstance2D
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

# Attack range constant (matching PlayerCollisionDetector)
const ATTACK_DETECTION_RADIUS: float = 20.0

# Performance settings
var enable_flow_field: bool = true
var enable_spatial_grid: bool = true
var enable_collision_optimization: bool = true

# Dense instance mapping for MultiMesh efficiency
var instance_to_enemy_map: Dictionary = {}  # instance_index -> enemy_id
var enemy_to_instance_map: Dictionary = {}  # enemy_id -> instance_index
var next_instance_index: int = 0

# Succubus animation tracking
# (moved to top of file with other animation constants)

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
	aoe_scales = PackedFloat32Array()
	aoe_scales.resize(initial_capacity)
	regen_rates = PackedFloat32Array()
	regen_rates.resize(initial_capacity)
	# Command cooldown arrays
	last_boost_times = PackedFloat32Array()
	last_boost_times.resize(initial_capacity)
	temporary_speed_boosts = PackedFloat32Array()
	temporary_speed_boosts.resize(initial_capacity)
	boost_end_times = PackedFloat32Array()
	boost_end_times.resize(initial_capacity)
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
	_halted = PackedByteArray()
	_halted.resize(initial_capacity)
	
	alive_flags = PackedByteArray()
	alive_flags.resize(initial_capacity)
	entity_types = PackedByteArray()
	entity_types.resize(initial_capacity)
	ai_types = PackedByteArray()
	ai_types.resize(initial_capacity)
	chatter_usernames = []
	chatter_usernames.resize(initial_capacity)
	chatter_colors = PackedColorArray()
	chatter_colors.resize(initial_capacity)
	rarity_types = PackedByteArray()
	rarity_types.resize(initial_capacity)
	flash_timers = PackedFloat32Array()
	flash_timers.resize(initial_capacity)
	
	# Initialize ability arrays
	ability_casting_flags = PackedByteArray()
	ability_casting_flags.resize(initial_capacity)
	ability_cooldowns = PackedFloat32Array()
	ability_cooldowns.resize(initial_capacity)
	
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
	multi_mesh.use_colors = true  # Enable per-instance colors for flash effect
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

	# Create per-minion-type MultiMeshes for unique visuals
	multi_mesh_minion_succubus = MultiMeshInstance2D.new()
	multi_mesh_minion_succubus.name = "MinionMultiMesh_Succubus"
	add_child(multi_mesh_minion_succubus)
	var mm_succ = MultiMesh.new()
	mm_succ.transform_format = MultiMesh.TRANSFORM_2D
	mm_succ.use_colors = true
	# use_custom_data not supported properly in 2D - removed
	mm_succ.instance_count = MAX_ENEMIES
	# Succubus sprite is triple size for better visibility
	var succ_mesh = QuadMesh.new()
	succ_mesh.size = Vector2(96, 96)  # Triple size: 32 * 3 = 96
	mm_succ.mesh = succ_mesh
	multi_mesh_minion_succubus.multimesh = mm_succ
	
	# Use spritesheet texture and shader
	var succ_tex_path := "res://BespokeAssetSources/Succubus/succubusSpritesheet6framesUPDATE2.png"
	if ResourceLoader.exists(succ_tex_path):
		multi_mesh_minion_succubus.texture = load(succ_tex_path)
	else:
		# Fallback to temp fix or rat texture
		var fallback_path := "res://BespokeAssetSources/succubus-tempfix.png"
		if ResourceLoader.exists(fallback_path):
			multi_mesh_minion_succubus.texture = load(fallback_path)
		else:
			multi_mesh_minion_succubus.texture = multi_mesh_instance.texture
	
	# Apply the shader for spritesheet animation
	var mat_path := "res://BespokeAssetSources/Succubus/succubus_atlas.tres"
	if ResourceLoader.exists(mat_path):
		multi_mesh_minion_succubus.material = load(mat_path)
	else:
		# Fallback: create material dynamically if .tres doesn't exist
		var shader_path := "res://BespokeAssetSources/Succubus/succubus_atlas.gdshader"
		if ResourceLoader.exists(shader_path):
			var shader_mat := ShaderMaterial.new()
			shader_mat.shader = load(shader_path)
			shader_mat.set_shader_parameter("frames_h", SUCCUBUS_FRAMES_H)
			shader_mat.set_shader_parameter("frames_v", SUCCUBUS_FRAMES_V)
			if multi_mesh_minion_succubus.texture:
				shader_mat.set_shader_parameter("tex", multi_mesh_minion_succubus.texture)
			multi_mesh_minion_succubus.material = shader_mat
	
	# Keep a reference and push params (even if loaded from .tres)
	succubus_mat = multi_mesh_minion_succubus.material as ShaderMaterial
	if succubus_mat:
		succubus_mat.set_shader_parameter("frames_h", SUCCUBUS_FRAMES_H)
		succubus_mat.set_shader_parameter("frames_v", SUCCUBUS_FRAMES_V)
		if multi_mesh_minion_succubus.texture:
			succubus_mat.set_shader_parameter("tex", multi_mesh_minion_succubus.texture)

	multi_mesh_minion_woodland = MultiMeshInstance2D.new()
	multi_mesh_minion_woodland.name = "MinionMultiMesh_WoodlandJoe"
	add_child(multi_mesh_minion_woodland)
	var mm_wood = MultiMesh.new()
	mm_wood.transform_format = MultiMesh.TRANSFORM_2D
	mm_wood.use_colors = true
	mm_wood.instance_count = MAX_ENEMIES
	var wjoe_mesh = QuadMesh.new()
	wjoe_mesh.size = Vector2(32, 32)
	mm_wood.mesh = wjoe_mesh
	multi_mesh_minion_woodland.multimesh = mm_wood
	var wjoe_tex_path = "res://BespokeAssetSources/woodenJoe.png"
	if ResourceLoader.exists(wjoe_tex_path):
		multi_mesh_minion_woodland.texture = load(wjoe_tex_path)
	else:
		multi_mesh_minion_woodland.texture = multi_mesh_instance.texture
	# Note: Bosses use node-based spawning system, not multimesh

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

# Succubus animation helper functions
func _tick_succubus_anim(delta: float) -> void:
	_succubus_anim_time += delta

func _get_succubus_frame() -> Vector2i:
	var total := SUCCUBUS_FRAMES_H * SUCCUBUS_FRAMES_V
	if total <= 0: 
		return Vector2i(0, 0)
	var idx := int(floor(_succubus_anim_time * SUCCUBUS_ANIM_FPS)) % total
	return Vector2i(idx % SUCCUBUS_FRAMES_H, idx / SUCCUBUS_FRAMES_H)

func _physics_process(delta: float):
	if get_tree().paused:
		return
	
	# Update ability cooldowns ONLY for succubus (entity_type 1)
	for i in range(ability_cooldowns.size()):
		if i < entity_types.size() and entity_types[i] == 1 and ability_cooldowns[i] > 0:
			ability_cooldowns[i] = max(0, ability_cooldowns[i] - delta)
	
	# Tick succubus animation
	_succubus_anim_time += delta
	if succubus_mat:
		var total: int = SUCCUBUS_FRAMES_H * SUCCUBUS_FRAMES_V
		if total <= 0:
			total = 1
		var frame_idx: int = int(floor(_succubus_anim_time * SUCCUBUS_ANIM_FPS)) % total
		succubus_mat.set_shader_parameter("frame", frame_idx)
	
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
	
	# Check for expired boosts
	var current_time = Time.get_ticks_msec() / 1000.0
	for i in range(alive_flags.size()):
		if alive_flags[i] == 0:
			continue
		
		# Remove expired boost
		if boost_end_times[i] > 0 and boost_end_times[i] <= current_time:
			temporary_speed_boosts[i] = 0.0
			boost_end_times[i] = 0.0
	
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
	# Initialize behavior variability
	speed_jitter[id] = randf_range(0.9, 1.2)
	behavior_strafe_dir[id] = -1.0 if randf() < 0.5 else 1.0
	behavior_wander_phase[id] = randf() * TAU
	behavior_wander_speed[id] = randf_range(1.0, 3.0)
	burst_timer[id] = 0.0
	burst_cooldown[id] = randf_range(0.8, 2.0)
	flash_timers[id] = 0.0
	aoe_scales[id] = 1.0  # Default AOE scale
	regen_rates[id] = 0.0  # Default no regen
	last_boost_times[id] = -BOOST_COOLDOWN  # Start with boost available
	temporary_speed_boosts[id] = 0.0
	boost_end_times[id] = 0.0
	
	# Apply stats from configuration system
	var enemy_type_str = _get_type_name_string(enemy_type)
	if EnemyConfigManager.instance:
		EnemyConfigManager.instance.apply_config_to_enemy(id, enemy_type_str, self)
	else:
		# Fallback to hardcoded stats - only minion types
		match enemy_type:
			0: # Rat
				max_healths[id] = 10.0
				healths[id] = 10.0
				move_speeds[id] = 80.0
				attack_damages[id] = 1.0
				attack_cooldowns[id] = 0.5  # 2 attacks per second
			1: # Succubus
				max_healths[id] = 25.0
				healths[id] = 25.0
				move_speeds[id] = 100.0
				attack_damages[id] = 3.0
				attack_cooldowns[id] = 2.5  # Ranged attacker - slower attack speed
			2: # Woodland Joe
				max_healths[id] = 40.0
				healths[id] = 40.0
				move_speeds[id] = 80.0
				attack_damages[id] = 5.0
				attack_cooldowns[id] = 0.5  # 2 attacks per second
			_: # Boss types should not be spawned through EnemyManager
				push_error("Boss type %d should be spawned through BossFactory, not EnemyManager" % enemy_type)
				return -1
	
	active_count += 1
	
	# Apply MXP upgrades if this is a chatter entity
	if username != "" and ChatterEntityManager.instance:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		
		# Apply HP bonus
		if chatter_data.upgrades.has("bonus_health"):
			var hp_bonus = chatter_data.upgrades["bonus_health"]
			max_healths[id] += hp_bonus
			healths[id] += hp_bonus
		
		# Apply speed bonus
		if chatter_data.upgrades.has("bonus_move_speed"):
			var speed_bonus = chatter_data.upgrades["bonus_move_speed"]
			move_speeds[id] += speed_bonus
		
		# Apply attack speed percentage bonus
		if chatter_data.upgrades.has("attack_speed_percent"):
			var percent_bonus = chatter_data.upgrades["attack_speed_percent"]
			var base_attacks_per_sec = 1.0 / attack_cooldowns[id] if attack_cooldowns[id] > 0 else 1.0
			var new_attacks_per_sec = base_attacks_per_sec * (1.0 + percent_bonus)
			attack_cooldowns[id] = 1.0 / new_attacks_per_sec
		
		# Apply AOE bonus (stored for later use in abilities)
		if chatter_data.upgrades.has("bonus_aoe"):
			# AOE is handled by abilities system, just store it
			aoe_scales[id] = 1.0 + chatter_data.upgrades["bonus_aoe"]
		
		# Apply regen bonus
		if chatter_data.upgrades.has("regen_flat_bonus"):
			var regen = chatter_data.upgrades["regen_flat_bonus"]
			regen_rates[id] = regen

	# Assign rarity for V2 minions via NPCRarityManager (no visuals, stat/tint only)
	if NPCRarityManager.get_instance():
		var rarity_mgr = NPCRarityManager.get_instance()
		# Only apply to minion types (0..2)
		if enemy_type <= 2:
			var rarity = rarity_mgr.draw_random_rarity()
			_apply_rarity_modifiers_v2(id, rarity)
	print("👾 Spawned enemy ID %d (%s) for %s at %s" % [id, _get_type_name(enemy_type), username, position])
	
	# Notify bridge system (pass null resource for legacy spawns)
	if EnemyBridge.instance:
		EnemyBridge.instance.on_enemy_spawned(id, enemy_type_str, null)
	
	return id

# New resource-based spawn method
func spawn_from_resource(resource: EnemyResource, position: Vector2, username: String = "") -> int:
	if not resource:
		print("⚠️ EnemyManager: Invalid enemy resource")
		return -1
	
	# Map resource enemy_id to internal type
	var enemy_type = _get_type_from_resource_id(resource.enemy_id)
	if enemy_type < 0:
		print("⚠️ EnemyManager: Unknown enemy type from resource: ", resource.enemy_id)
		return -1
	
	# Use color from chatter or default white
	var color = Color.WHITE
	if username != "" and ChatterEntityManager.instance:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		if chatter_data and chatter_data.has("color"):
			color = chatter_data.color
	
	# Spawn using existing system
	var id = spawn_enemy(enemy_type, position, username, color)
	
	if id >= 0:
		# Override stats with resource values
		max_healths[id] = resource.base_health
		healths[id] = resource.base_health
		move_speeds[id] = resource.base_speed
		attack_damages[id] = resource.base_damage
		scales[id] = resource.base_scale
		attack_cooldowns[id] = resource.attack_cooldown
		
		# Set AI type based on resource
		match resource.ai_type:
			"basic_chase":
				ai_types[id] = AI_TYPE_BASIC_CHASE
			"ranged":
				ai_types[id] = AI_TYPE_RANGED
			"special":
				ai_types[id] = AI_TYPE_SPECIAL
			_:
				ai_types[id] = AI_TYPE_BASIC_CHASE
		
		# Notify bridge system with the resource for ability setup
		if EnemyBridge.instance:
			var enemy_type_str = _get_type_name_string(enemy_type)
			EnemyBridge.instance.on_enemy_spawned(id, enemy_type_str, resource)
	
	return id

func _get_type_from_resource_id(resource_id: String) -> int:
	# Map resource IDs to internal enemy types
	match resource_id:
		"rat": return 0
		"succubus": return 1
		"woodland_joe": return 2
		"ugandan_warrior": return 3
		"horse_enemy": return 4
		_: return -1

# Helper method for getting enemy at position (for debug selection)
func get_enemy_at_position(world_pos: Vector2, radius: float = 30.0) -> int:
	for id in range(positions.size()):
		if alive_flags[id] == 0:
			continue
		
		if positions[id].distance_to(world_pos) <= radius:
			return id
	
	return -1

# Get enemies in radius (for area selections)
func get_enemies_in_radius(world_pos: Vector2, radius: float) -> Array[int]:
	var enemies = []
	for id in range(positions.size()):
		if alive_flags[id] == 0:
			continue
		
		if positions[id].distance_to(world_pos) <= radius:
			enemies.append(id)
	
	return enemies

# Get enemy data for debug inspection
func get_enemy_data(id: int) -> Dictionary:
	if id < 0 or id >= alive_flags.size() or alive_flags[id] == 0:
		return {}
	
	return {
		"id": id,
		"enemy_type": _get_type_name_string(entity_types[id]),
		"position": positions[id],
		"health": healths[id],
		"max_health": max_healths[id],
		"speed": move_speeds[id],
		"damage": attack_damages[id],
		"owner_username": chatter_usernames[id],
		"color": chatter_colors[id],
		"state": "casting" if ability_casting_flags[id] else "moving",
		"abilities": _get_enemy_abilities(entity_types[id])
	}

func _get_enemy_abilities(enemy_type: int) -> Array:
	match enemy_type:
		1: # Succubus
			return ["explode", "speed_boost"]
		2: # Woodland Joe
			return ["shoot", "rapid_fire"]
		_:
			return []

# Debug methods for ability system
func trigger_enemy_ability(enemy_id: int, ability_name: String) -> bool:
	if enemy_id < 0 or enemy_id >= alive_flags.size() or alive_flags[enemy_id] == 0:
		return false
	
	# Forward to EnemyBridge which manages abilities
	if EnemyBridge.instance:
		EnemyBridge.instance.execute_ability(enemy_id, ability_name)
		return true
	
	return false

# Debug methods for enemy manipulation
func heal_enemy(enemy_id: int, amount: float):
	if enemy_id < 0 or enemy_id >= alive_flags.size() or alive_flags[enemy_id] == 0:
		return
	
	healths[enemy_id] = min(healths[enemy_id] + amount, max_healths[enemy_id])


func kill_enemy(enemy_id: int):
	if enemy_id < 0 or enemy_id >= alive_flags.size() or alive_flags[enemy_id] == 0:
		return
	
	despawn_enemy(enemy_id)

# Clear all enemies (for debug mode)
func clear_all_enemies():
	for id in range(alive_flags.size()):
		if alive_flags[id] == 1:
			despawn_enemy(id)
	print("[EnemyManager] Cleared all enemies")

# Set AI enabled state (for debug pause)
func set_ai_enabled(_enabled: bool):
	# Store in a flag that _physics_process checks
	# TODO: Implement AI pause flag
	pass

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

func damage_enemy(id: int, damage: float, killer_name: String = "debug", death_cause: String = "debug_damage"):
	if id < 0 or id >= alive_flags.size() or alive_flags[id] == 0:
		return
	
	healths[id] = max(0, healths[id] - damage)
	
	# Trigger white flash for damage feedback
	_flash_enemy_white(id)
	
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
		_update_enemy_regeneration(i, delta)
	
	# Advance to next slice
	current_slice_offset = slice_end
	if current_slice_offset >= array_size:
		current_slice_offset = 0

func _update_enemy_movement(id: int, delta: float):
	var current_pos = positions[id]
	
	# Check if using ranged AI (for succubus and other ranged enemies)
	var is_ranged = false
	if id < ai_types.size():
		is_ranged = (ai_types[id] == AI_TYPE_RANGED)
	
	# Check if enemy is within attack range - stop if so (except ranged enemies)
	var distance_to_edge = PlayerCollisionDetector.get_distance_to_player_capsule_edge(player_position, current_pos)
	if not is_ranged and distance_to_edge <= ATTACK_DETECTION_RADIUS:
		velocities[id] = Vector2.ZERO
		return  # Skip all other movement logic
	
	# Get flow-field direction
	var target_direction = Vector2.ZERO
	
	# Ranged AI movement - maintain optimal range
	if is_ranged:
		var distance = current_pos.distance_to(player_position)
		var optimal_min = 170.0
		var optimal_max = 195.0
		
		if distance < optimal_min:  # Too close
			# Back away
			target_direction = (current_pos - player_position).normalized()
		elif distance > optimal_max:  # Too far for abilities
			# Move closer
			target_direction = (player_position - current_pos).normalized()
		else:
			# In optimal range, strafe around player
			var tangent = (player_position - current_pos).rotated(PI/2.0).normalized()
			target_direction = tangent * behavior_strafe_dir[id]
	elif enable_flow_field:
		var grid_pos = Vector2i(current_pos / GRID_SIZE)
		if flow_field.has(grid_pos):
			target_direction = flow_field[grid_pos]
		else:
			# Fallback: move toward player
			target_direction = (player_position - current_pos).normalized()
	else:
		target_direction = (player_position - current_pos).normalized()
	
	# Direct pursuit - no strafe/wander for aggressive movement
	if target_direction == Vector2.ZERO:
		target_direction = (player_position - current_pos).normalized()
	# Cheap obstacle avoidance
	var avoid: Vector2 = _compute_avoidance_vector(current_pos) * avoidance_weight
	# Optional boids-lite from FlockingSystem (V2 arrays)
	var flock_force := Vector2.ZERO
	if FlockingSystem.instance:
		flock_force = FlockingSystem.instance.get_v2_force(id)
	var combined_direction: Vector2 = (target_direction * 3.0 + avoid + flock_force).normalized()
	
	# Effective speed - base speed + temporary boost if active
	var effective_speed: float = move_speeds[id]
	var current_time = Time.get_ticks_msec() / 1000.0
	if boost_end_times[id] > current_time:
		effective_speed += temporary_speed_boosts[id]
	
	# Apply movement at full speed - no arrive mechanics, no stopping
	var target_velocity = combined_direction * effective_speed
	
	# Direct velocity assignment - no smoothing for instant response
	velocities[id] = target_velocity
	
	# Position integration moved to _integrate_positions_and_behaviors for smoother motion
	
	# Update rotation to face path direction (reduces wobble from strafe/avoidance jitter)
	if target_direction.length() > 0.001:
		var target_rotation: float = target_direction.angle()
		# small deadband so tiny changes don't cause constant wiggle
		var d: float = abs(wrapf(target_rotation - rotations[id], -PI, PI))
		if d > 0.08:
			rotations[id] = lerp_angle(rotations[id], target_rotation, delta * 4.0)

# Attack logic removed - handled by PlayerCollisionDetector
func _update_enemy_attack(_id: int, _delta: float):
	pass  # All attack logic is in PlayerCollisionDetector

func _update_enemy_regeneration(id: int, delta: float):
	# Apply regeneration if enemy has any
	if regen_rates[id] > 0:
		var current_health = healths[id]
		var max_health = max_healths[id]
		if current_health < max_health:
			healths[id] = min(current_health + regen_rates[id] * delta, max_health)

func _integrate_positions_and_behaviors(delta: float):
	# Lightweight per-frame integration for smooth motion
	var array_size = min(positions.size(), alive_flags.size())
	var any_moved := false
	for i in range(array_size):
		if alive_flags[i] == 0:
			continue
		
		# Stop movement ONLY if casting an ability (not for regular attacks)
		if i < ability_casting_flags.size() and ability_casting_flags[i] > 0:
			velocities[i] = Vector2.ZERO
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
		# Update flash timer
		if flash_timers[i] > 0.0:
			flash_timers[i] = max(0.0, flash_timers[i] - delta)
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
			var dist_len = d.length()
			if dist_len < prad and dist_len > 0.001:
				repel += d / dist_len * ((prad - dist_len) / prad)
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
	if multi_mesh_instance == null:
		return
	var minion_mesh = multi_mesh_instance.multimesh
	var minion_succ_mesh = multi_mesh_minion_succubus.multimesh if multi_mesh_minion_succubus else null
	var minion_wood_mesh = multi_mesh_minion_woodland.multimesh if multi_mesh_minion_woodland else null
	if not minion_mesh:
		return
	
	# Dense packing per category: only minions (0-2) - bosses use node-based system
	var minion_count = 0
	var minion_succ_count = 0
	var minion_wood_count = 0
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
		
		# Skip boss types - they use node-based system
		if int(entity_types[enemy_id]) > 2:
			continue
			
		if do_cull and not cull_rect.has_point(positions[enemy_id]):
			continue
		
		var transform = Transform2D()
		# Flip X for direction, NEGATIVE Y to flip sprites right-side up
		var flip_x = -1.0 if rotations[enemy_id] > PI/2 and rotations[enemy_id] < 3*PI/2 else 1.0
		transform = transform.scaled(Vector2(flip_x * scales[enemy_id], -scales[enemy_id]))
		transform.origin = positions[enemy_id]
		
		# Apply flash color if enemy is flashing
		var color = Color.WHITE
		if flash_timers[enemy_id] > 0.0:
			# Check if this is a boost effect (longer than damage flash)
			if flash_timers[enemy_id] > FLASH_DURATION:
				# Yellow boost effect
				var boost_intensity = 0.8  # Strong yellow tint
				color = Color(1.0 + boost_intensity, 1.0 + boost_intensity, 0.5, 1.0)  # Yellow glow
			else:
				# White damage flash
				var flash_intensity = flash_timers[enemy_id] / FLASH_DURATION
				color = Color(1.0 + flash_intensity * 2.0, 1.0 + flash_intensity * 2.0, 1.0 + flash_intensity * 2.0, 1.0)
		
		match int(entity_types[enemy_id]):
			1:
				if minion_succ_mesh and minion_succ_count < minion_succ_mesh.instance_count:
					minion_succ_mesh.set_instance_transform_2d(minion_succ_count, transform)
					minion_succ_mesh.set_instance_color(minion_succ_count, color)
				minion_succ_count += 1
			2:
				if minion_wood_mesh and minion_wood_count < minion_wood_mesh.instance_count:
					minion_wood_mesh.set_instance_transform_2d(minion_wood_count, transform)
					minion_wood_mesh.set_instance_color(minion_wood_count, color)
				minion_wood_count += 1
			_:
				# Default case (type 0 - rats)
				if minion_count < minion_mesh.instance_count:
					minion_mesh.set_instance_transform_2d(minion_count, transform)
					minion_mesh.set_instance_color(minion_count, color)
				minion_count += 1
	
	# Update visible counts per mesh - only minions
	minion_mesh.visible_instance_count = minion_count
	if minion_succ_mesh:
		minion_succ_mesh.visible_instance_count = minion_succ_count
	if minion_wood_mesh:
		minion_wood_mesh.visible_instance_count = minion_wood_count

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

func _flash_enemy_white(enemy_id: int):
	if enemy_id < 0 or enemy_id >= flash_timers.size():
		return
	flash_timers[enemy_id] = FLASH_DURATION

func _drop_xp_orb(enemy_id: int):
	# 75% chance to drop XP (25% chance not to drop)
	if randf() > 0.75:
		return
	
	# Check if resource exists before trying to load
	var xp_orb_path = "res://entities/pickups/xp_orb.tscn"
	if not ResourceLoader.exists(xp_orb_path):
		print("⚠️ XP orb scene not found at: ", xp_orb_path)
		return
	
	# Base XP value (2x increase from 1 to 2)
	var base_xp = 2
	
	# Scale XP based on MXP buffs if this is a chatter entity
	var max_xp = base_xp
	var username = chatter_usernames[enemy_id]
	if username != "" and ChatterEntityManager.instance:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		var total_mxp_spent = chatter_data.get("total_upgrades", 0)
		
		# Each MXP spent adds 2 XP to max potential
		max_xp += total_mxp_spent * 2
		
		if total_mxp_spent > 0:
			print("DEBUG: Chatter '%s' spent %d MXP, max XP: %d" % [username, total_mxp_spent, max_xp])
	
	# Roll between 1 and max value
	var xp_value = randi_range(1, max_xp)
	
	# Spawn single XP orb with rolled value
	var xp_orb_scene = load(xp_orb_path)
	if not xp_orb_scene:
		print("⚠️ Failed to load XP orb scene")
		return
	
	var xp_orb = xp_orb_scene.instantiate()
	xp_orb.global_position = positions[enemy_id]
	xp_orb.xp_value = xp_value
	
	if GameController.instance:
		GameController.instance.call_deferred("add_child", xp_orb)

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
	aoe_scales.resize(new_size)
	regen_rates.resize(new_size)
	last_boost_times.resize(new_size)
	temporary_speed_boosts.resize(new_size)
	boost_end_times.resize(new_size)
	behavior_strafe_dir.resize(new_size)
	behavior_wander_phase.resize(new_size)
	behavior_wander_speed.resize(new_size)
	speed_jitter.resize(new_size)
	burst_timer.resize(new_size)
	burst_cooldown.resize(new_size)
	_halted.resize(new_size)
	alive_flags.resize(new_size)
	entity_types.resize(new_size)
	ai_types.resize(new_size)
	chatter_usernames.resize(new_size)
	chatter_colors.resize(new_size)
	rarity_types.resize(new_size)
	flash_timers.resize(new_size)
	ability_casting_flags.resize(new_size)
	ability_cooldowns.resize(new_size)
	
	# Add new IDs to free pool
	for i in range(current_size, new_size):
		free_ids.append(i)
		alive_flags[i] = 0

func _get_type_name(type: int) -> String:
	match type:
		0: return "Rat"
		1: return "Succubus" 
		2: return "Woodland Joe"
		_: return "Unknown Minion"

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
		_: return "unknown_minion"

func get_enemy_type_from_string(type_str: String) -> int:
	match type_str.to_lower():
		"twitch_rat": return 0
		"succubus": return 1
		"woodland_joe", "woodlandjoe": return 2
		_: return 0  # Default to rat - boss types not handled by EnemyManager

func get_enemy_position(id: int) -> Vector2:
	if id < 0 or id >= positions.size() or id >= alive_flags.size() or alive_flags[id] == 0:
		return Vector2.ZERO
	return positions[id]

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

func reset_all_evolutions():
	# Reset all enemies to their base type (rat)
	var array_size = min(positions.size(), alive_flags.size())
	for i in range(array_size):
		if alive_flags[i] == 1:
			evolve_enemy(i, 0)  # Reset to rat (type 0)
