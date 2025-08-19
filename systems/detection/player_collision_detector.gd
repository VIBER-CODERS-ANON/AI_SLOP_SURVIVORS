extends Area2D
class_name PlayerCollisionDetector

## INVERTED COLLISION SYSTEM
## Instead of thousands of enemy collision bodies, the player has one Area2D
## that detects overlaps with enemies using the EnemyManager data arrays

signal enemy_overlap_detected(enemy_id: int)

# Collision settings
var detection_radius: float = 32.0  # How far from player center to detect enemies
var damage_per_second: float = 60.0  # Base damage enemies deal to player
var last_damage_times: Dictionary = {}  # enemy_id -> last_damage_time
var damage_cooldown: float = 1.0  # Cooldown between damage from same enemy

# Visual debug
var debug_draw_enabled: bool = false

func _ready():
	# Set up collision detection
	collision_layer = 0  # Player detector doesn't need to be on a layer
	collision_mask = 0   # We'll handle detection manually
	
	# Create detection shape
	var shape = CircleShape2D.new()
	shape.radius = detection_radius
	
	var collision_shape = CollisionShape2D.new()
	collision_shape.shape = shape
	add_child(collision_shape)
	
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
	
	# Check if enemy is within detection radius
	var distance = player_pos.distance_to(enemy_pos)
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

func set_detection_radius(new_radius: float):
	detection_radius = new_radius
	
	# Update collision shape
	var collision_shape = get_child(0) as CollisionShape2D
	if collision_shape and collision_shape.shape is CircleShape2D:
		var shape = collision_shape.shape as CircleShape2D
		shape.radius = new_radius

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
