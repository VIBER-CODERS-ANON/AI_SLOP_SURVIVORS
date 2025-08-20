extends Area2D
class_name PlayerCollisionDetector

## UNIFIED ENEMY ATTACK SYSTEM FOR DATA-ORIENTED MINIONS
## This system handles all attacks from V2 enemies (rats, succubus, etc)
## Node-based enemies (bosses) use their own BaseEnemy attack system
##
## CONFIGURATION:
## - detection_radius: How close enemies need to be to attack (default: 100 pixels)
## - damage_cooldown: Time between attacks from same enemy (default: 0.5s = 2 APS)

signal enemy_overlap_detected(enemy_id: int)

# Attack configuration
var detection_radius: float = 20.0  # Attack range for V2 enemies (tight melee range)
var damage_cooldown: float = 0.5  # 0.5s = 2 attacks per second per enemy
var last_damage_times: Dictionary = {}  # enemy_id -> last_damage_time

# Player capsule hitbox dimensions (from player.tscn)
var capsule_radius: float = 16.0
var capsule_height: float = 60.0

# Visual debug
var debug_draw_enabled: bool = false

func _ready():
	# Set up collision detection
	collision_layer = 0  # Player detector doesn't need to be on a layer
	collision_mask = 0   # We'll handle detection manually
	
	# DON'T create a collision shape - this Area2D is only for manual detection
	# The visual collision box should only come from the main CharacterBody2D
	
	# Connect to player
	if get_parent().has_signal("health_changed"):
		# This is attached to a player-like entity
		pass

func _physics_process(_delta: float):
	if not EnemyManager.instance:
		return
	
	var player_pos = global_position
	_check_enemy_collisions(player_pos)

func _check_enemy_collisions(player_pos: Vector2):
	var enemy_manager = EnemyManager.instance
	var time_seconds = Time.get_ticks_msec() / 1000.0
	
	# Use spatial grid for efficiency if available
	if enemy_manager.enable_spatial_grid:
		_check_collisions_with_spatial_grid(player_pos, time_seconds)
	else:
		_check_collisions_brute_force(player_pos, time_seconds)

func _check_collisions_with_spatial_grid(player_pos: Vector2, current_time: float):
	var enemy_manager = EnemyManager.instance
	var grid_size = enemy_manager.GRID_SIZE
	
	# Check player's grid cell and surrounding cells
	var player_grid = Vector2i(player_pos / grid_size)
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var check_grid = Vector2i(player_grid.x + dx, player_grid.y + dy)
			
			if not enemy_manager.spatial_grid.has(check_grid):
				continue
			
			var cell_enemies = enemy_manager.spatial_grid[check_grid] as Array[int]
			for enemy_id in cell_enemies:
				_check_single_enemy_collision(enemy_id, player_pos, current_time)

func _check_collisions_brute_force(player_pos: Vector2, current_time: float):
	var enemy_manager = EnemyManager.instance
	
	# Check all enemies (less efficient but works without spatial grid)
	var array_size = min(enemy_manager.positions.size(), enemy_manager.alive_flags.size())
	for i in range(array_size):
		if enemy_manager.alive_flags[i] == 0:
			continue
		
		_check_single_enemy_collision(i, player_pos, current_time)

func _check_single_enemy_collision(enemy_id: int, player_pos: Vector2, current_time: float):
	var enemy_manager = EnemyManager.instance
	# Validate enemy id and alive state before accessing arrays
	if enemy_id < 0 or enemy_id >= enemy_manager.alive_flags.size() or enemy_id >= enemy_manager.positions.size():
		return
	if enemy_manager.alive_flags[enemy_id] == 0:
		return
	var enemy_pos = enemy_manager.positions[enemy_id]
	
	# Calculate distance from enemy to edge of player's capsule hitbox
	var distance = _get_distance_to_capsule_edge(player_pos, enemy_pos)
	if distance > detection_radius:
		return
	
	# Check damage cooldown
	if last_damage_times.has(enemy_id):
		if current_time - last_damage_times[enemy_id] < damage_cooldown:
			return
	
	# Apply damage to player
	var damage = _calculate_enemy_damage(enemy_id)
	_damage_player(damage, enemy_id)
	
	# Record damage time
	last_damage_times[enemy_id] = current_time
	
	# Emit signal for other systems
	enemy_overlap_detected.emit(enemy_id)

func _calculate_enemy_damage(enemy_id: int) -> float:
	var enemy_manager = EnemyManager.instance
	var base_damage = enemy_manager.attack_damages[enemy_id]
	
	# Could add modifiers here based on enemy type, player buffs, etc.
	return base_damage

func _damage_player(damage: float, source_enemy_id: int):
	var player = get_parent()
	
	if player.has_method("take_damage"):
		# Create a fake damage source for the death system
		var damage_source = Node.new()
		damage_source.name = "EnemyAttack"
		
		# Add metadata for death reporting
		var enemy_manager = EnemyManager.instance
		var username = enemy_manager.chatter_usernames[source_enemy_id]
		var enemy_type = enemy_manager.entity_types[source_enemy_id]
		
		damage_source.set_meta("source_name", username)
		damage_source.set_meta("attack_name", _get_attack_name(enemy_type))
		
		# Apply damage
		player.take_damage(damage, damage_source)
		
		# Clean up
		damage_source.queue_free()

func _get_attack_name(enemy_type: int) -> String:
	match enemy_type:
		0: return "rat bite"
		1: return "succubus drain"
		2: return "woodland strike"
		_: return "unknown attack"

## Calculate distance from a point to the edge of a capsule shape
func _get_distance_to_capsule_edge(capsule_center: Vector2, point: Vector2) -> float:
	# Capsule is vertical (taller than wide)
	# It consists of a rectangle with semicircles on top and bottom
	
	# Half-height of the rectangular part (excluding the radius caps)
	var half_rect_height = (capsule_height - capsule_radius * 2) / 2.0
	
	# Get point relative to capsule center
	var relative_point = point - capsule_center
	
	# Clamp the y position to the rectangular part of the capsule
	var clamped_y = clamp(relative_point.y, -half_rect_height, half_rect_height)
	
	# Find the closest point on the capsule's center line
	var closest_on_centerline = Vector2(0, clamped_y)
	
	# Calculate distance from the point to the closest point on centerline
	var dist_to_centerline = relative_point.distance_to(closest_on_centerline)
	
	# Subtract the capsule radius to get distance to edge
	# If negative, the point is inside the capsule
	return max(0, dist_to_centerline - capsule_radius)

func set_detection_radius(new_radius: float):
	detection_radius = new_radius
	# No collision shape to update - using manual detection only

# Debug visualization
func _draw():
	if debug_draw_enabled:
		draw_circle(Vector2.ZERO, detection_radius, Color.RED, false, 2.0)

func enable_debug_draw(enabled: bool):
	debug_draw_enabled = enabled
	queue_redraw()

# Area2D collision for special cases (bosses, live subset)
func _on_area_entered(area: Area2D):
	# Handle collision with special enemies that still use Area2D
	if area.has_meta("enemy_id"):
		var enemy_id = area.get_meta("enemy_id")
		enemy_overlap_detected.emit(enemy_id)

func _on_body_entered(body: CharacterBody2D):
	# Handle collision with live enemy bodies from EnemyManager
	if body.has_meta("enemy_id"):
		var enemy_id = body.get_meta("enemy_id")
		var time_seconds = Time.get_ticks_msec() / 1000.0
		
		_check_single_enemy_collision(enemy_id, global_position, time_seconds)
