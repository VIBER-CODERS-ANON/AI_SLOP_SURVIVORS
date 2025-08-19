extends Node
class_name TicketSpawnManager

## DATA-ORIENTED TICKET SPAWNING SYSTEM
## Integrates with EnemyManager for high-performance entity spawning
## Maintains the same ticket-based mechanics but spawns data instead of Nodes

signal chatter_joined(username: String)
signal entity_spawned(username: String, entity_id: int)
signal monster_power_changed(current_power: float, threshold: float)

static var instance: TicketSpawnManager

# Session tracking
var joined_chatters: Dictionary = {}  # username -> { monster_type: String, ticket_multiplier: float }

# Ticket pool
var ticket_pool: Array = []  # Array of { username: String, weight: int }
var total_tickets: int = 0

# Monster power tracking
var alive_monsters: Dictionary = {}  # username -> Array[entity_id]
var current_monster_power: float = 0.0

# Ramping system
var base_monster_power_threshold: float = 0.0
var time_ramp_bonus: float = 0.0
var boss_death_bonus: float = 0.0
var monster_power_threshold: float = 0.0

# Monster ticket values (base values) 
const MONSTER_TICKETS = {
	"twitch_rat": 100,
	"succubus": 20,
	"woodland_joe": 20
}

# Monster type mappings for EnemyManager
const MONSTER_TYPE_IDS = {
	"twitch_rat": 0,
	"succubus": 1,
	"woodland_joe": 2
}

# Spawn settings
var spawn_check_interval: float = 0.5
var spawn_timer: float = 0.0
var max_spawn_per_tick: int = 10  # Can spawn more with data-oriented system

# Off-screen spawn settings
var spawn_inner_margin: float = 50.0
var spawn_outer_margin: float = 300.0

# Ramping timers
var ramp_timer: float = 0.0
const RAMP_INTERVAL: float = 1.0
const RAMP_AMOUNT: float = 0.002
const BOSS_DEATH_BONUS_AMOUNT: float = 1.0

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Connect to EnemyManager death signal - defer connection if not ready
	call_deferred("_connect_to_enemy_manager")
	
	print("🎫 TicketSpawnManager initialized!")

func _connect_to_enemy_manager():
	if EnemyManager.instance:
		EnemyManager.instance.enemy_died.connect(_on_enemy_died)
		print("🔗 TicketSpawnManager connected to EnemyManager")
	else:
		print("⚠️ EnemyManager not found during connection attempt")

func _process(delta):
	if get_tree().paused:
		return
	
	# Check if spawning is disabled
	if DebugSettings.instance and not DebugSettings.instance.spawning_enabled:
		return
	
	# Handle ramping
	ramp_timer += delta
	if ramp_timer >= RAMP_INTERVAL:
		ramp_timer -= RAMP_INTERVAL
		_apply_time_ramp()
	
	# Handle spawning
	spawn_timer += delta
	if spawn_timer >= spawn_check_interval:
		spawn_timer = 0.0
		_check_and_spawn()

func reset_session():
	joined_chatters.clear()
	ticket_pool.clear()
	total_tickets = 0
	
	# Reset ramping values
	time_ramp_bonus = 0.0
	boss_death_bonus = 0.0
	ramp_timer = 0.0
	_recalculate_threshold()
	
	# Clear alive monsters tracking
	alive_monsters.clear()
	current_monster_power = 0.0
	
	print("🎫 Session reset - all chatters cleared")

func handle_join_command(username: String) -> bool:
	if joined_chatters.has(username):
		return false  # Already joined
	
	# Get chatter's monster type from ChatterEntityManager
	var monster_type = "twitch_rat"  # Default
	if ChatterEntityManager.instance:
		monster_type = ChatterEntityManager.instance.get_entity_type(username)
	
	# Register chatter
	joined_chatters[username] = {
		"monster_type": monster_type,
		"ticket_multiplier": 1.0
	}
	
	# Rebuild ticket pool
	_rebuild_ticket_pool()
	
	chatter_joined.emit(username)
	print("🎫 %s joined the session as %s" % [username, monster_type])
	
	# Notify in action feed
	if GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.add_message(
				"⚔️ %s joined the battle!" % username,
				Color.CYAN
			)
	
	return true

func _rebuild_ticket_pool():
	ticket_pool.clear()
	total_tickets = 0
	
	for username in joined_chatters:
		var data = joined_chatters[username]
		var base_tickets = MONSTER_TICKETS.get(data.monster_type, 100)
		
		# Apply ticket multiplier from upgrades
		var ticket_multiplier = data.ticket_multiplier
		if ChatterEntityManager.instance:
			var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
			var ticket_bonus = chatter_data.upgrades.get("ticket_multiplier", 1.0)
			ticket_multiplier *= ticket_bonus
		
		var final_tickets = int(base_tickets * ticket_multiplier)
		
		# Add tickets to pool
		for i in range(final_tickets):
			ticket_pool.append(username)
		
		total_tickets += final_tickets
	
	print("🎫 Ticket pool rebuilt: %d total tickets from %d chatters" % [total_tickets, joined_chatters.size()])

func _check_and_spawn():
	if ticket_pool.is_empty() or not EnemyManager.instance:
		return
	
	# Calculate current monster power
	_update_monster_power()
	
	# Spawn monsters if below threshold
	var spawns_this_tick = 0
	while current_monster_power < monster_power_threshold and spawns_this_tick < max_spawn_per_tick:
		if not _spawn_random_monster():
			break
		spawns_this_tick += 1
		_update_monster_power()

func _spawn_random_monster() -> bool:
	if ticket_pool.is_empty() or not EnemyManager.instance:
		return false
	
	# Draw random ticket
	var ticket_index = randi() % ticket_pool.size()
	var username = ticket_pool[ticket_index]
	
	if not joined_chatters.has(username):
		return false
	
	var data = joined_chatters[username]
	var monster_type = data.monster_type
	var monster_type_id = MONSTER_TYPE_IDS.get(monster_type, 0)
	
	# Get spawn position
	if not GameController.instance or not GameController.instance.player:
		return false
	
	var spawn_pos = _get_off_screen_spawn_position()
	var color = _get_user_color(username)
	
	# Spawn using EnemyManager
	var enemy_id = EnemyManager.instance.spawn_enemy(monster_type_id, spawn_pos, username, color)
	if enemy_id == -1:
		return false  # Failed to spawn
	
	# Track the entity
	if not alive_monsters.has(username):
		alive_monsters[username] = []
	alive_monsters[username].append(enemy_id)
	
	# Apply upgrades if needed
	if ChatterEntityManager.instance:
		_apply_upgrades_to_entity(enemy_id, username)
	
	entity_spawned.emit(username, enemy_id)
	
	return true

func _apply_upgrades_to_entity(enemy_id: int, username: String):
	# Apply chatter upgrades to the enemy data
	if not ChatterEntityManager.instance:
		return
	
	var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
	var enemy_manager = EnemyManager.instance
	
	# Apply health upgrades
	if chatter_data.upgrades.has("health_multiplier"):
		var health_mult = chatter_data.upgrades.health_multiplier
		enemy_manager.max_healths[enemy_id] *= health_mult
		enemy_manager.healths[enemy_id] = enemy_manager.max_healths[enemy_id]
	
	# Apply damage upgrades
	if chatter_data.upgrades.has("damage_multiplier"):
		var damage_mult = chatter_data.upgrades.damage_multiplier
		enemy_manager.attack_damages[enemy_id] *= damage_mult
	
	# Apply speed upgrades
	if chatter_data.upgrades.has("speed_multiplier"):
		var speed_mult = chatter_data.upgrades.speed_multiplier
		enemy_manager.move_speeds[enemy_id] *= speed_mult
	
	# Apply scale upgrades (visual only)
	if chatter_data.upgrades.has("scale_multiplier"):
		var scale_mult = chatter_data.upgrades.scale_multiplier
		enemy_manager.scales[enemy_id] = scale_mult

func _on_enemy_died(enemy_id: int, _killer_name: String, _death_cause: String):
	# Find which chatter owned this enemy and remove it from tracking
	for username in alive_monsters:
		var entities = alive_monsters[username]
		var index = entities.find(enemy_id)
		if index >= 0:
			entities.remove_at(index)
			if entities.is_empty():
				alive_monsters.erase(username)
			break
	
	_update_monster_power()

func _update_monster_power():
	if not EnemyManager.instance:
		return
	
	current_monster_power = 0.0
	
	for username in alive_monsters:
		if not joined_chatters.has(username):
			continue
		
		var data = joined_chatters[username]
		var base_tickets = MONSTER_TICKETS.get(data.monster_type, 100)
		var monster_power = 1.0 / base_tickets
		
		var entities = alive_monsters[username]
		for entity_id in entities:
			# Check if entity is still alive in EnemyManager
			if entity_id >= 0 and entity_id < EnemyManager.instance.MAX_ENEMIES:
				if EnemyManager.instance.alive_flags[entity_id] == 1:
					current_monster_power += monster_power
	
	monster_power_changed.emit(current_monster_power, monster_power_threshold)

func get_alive_entities_for_chatter(username: String) -> Array[int]:
	if not alive_monsters.has(username):
		return []
	
	var valid_entities: Array[int] = []
	var entities = alive_monsters[username]
	
	if not EnemyManager.instance:
		return []
	
	for entity_id in entities:
		# Check if entity is still alive in EnemyManager
		if entity_id >= 0 and entity_id < EnemyManager.instance.MAX_ENEMIES:
			if EnemyManager.instance.alive_flags[entity_id] == 1:
				valid_entities.append(entity_id)
	
	return valid_entities

# Execute commands on all chatter's entities
func execute_command_on_entities(username: String, command: String):
	var entities = get_alive_entities_for_chatter(username)
	if entities.is_empty():
		return
	
	# Use V2Bridge for command execution if available
	if EnemyBridge.instance:
		for entity_id in entities:
			EnemyBridge.instance.execute_command_for_enemy(entity_id, command)
	else:
		# Fallback to old method
		match command:
			"explode":
				_trigger_explode_for_entities(entities)
			"fart":
				_trigger_fart_for_entities(entities)
			"boost":
				_trigger_boost_for_entities(entities)

func _trigger_explode_for_entities(entity_ids: Array[int]):
	# Create explosion effects at entity positions
	for entity_id in entity_ids:
		if not EnemyManager.instance:
			continue
		
		var pos = EnemyManager.instance.get_enemy_position(entity_id)
		if pos != Vector2.ZERO:
			_create_explosion_at_position(pos)
			# Kill the entity after explosion
			EnemyManager.instance.despawn_enemy(entity_id)

func _trigger_fart_for_entities(entity_ids: Array[int]):
	# Create fart clouds at entity positions
	for entity_id in entity_ids:
		if not EnemyManager.instance:
			continue
		
		var pos = EnemyManager.instance.get_enemy_position(entity_id)
		if pos != Vector2.ZERO:
			_create_fart_cloud_at_position(pos)

func _trigger_boost_for_entities(entity_ids: Array[int]):
	# Apply speed boost to entities
	for entity_id in entity_ids:
		if not EnemyManager.instance:
			continue
		
		# Double speed for 5 seconds
		var original_speed = EnemyManager.instance.move_speeds[entity_id]
		EnemyManager.instance.move_speeds[entity_id] = original_speed * 2.0
		
		# Set up timer to reset speed
		var timer = Timer.new()
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.timeout.connect(func(): 
			if entity_id < EnemyManager.instance.MAX_ENEMIES:
				EnemyManager.instance.move_speeds[entity_id] = original_speed
			timer.queue_free()
		)
		add_child(timer)
		timer.start()

func _create_explosion_at_position(pos: Vector2):
	var explosion_scene = preload("res://entities/effects/explosion_effect.tscn")
	var explosion = explosion_scene.instantiate()
	explosion.global_position = pos
	
	if GameController.instance:
		GameController.instance.add_child(explosion)

func _create_fart_cloud_at_position(pos: Vector2):
	var fart_scene = preload("res://entities/effects/poison_cloud.tscn")
	var fart = fart_scene.instantiate()
	fart.global_position = pos
	
	if GameController.instance:
		GameController.instance.add_child(fart)

func _get_user_color(username: String) -> Color:
	var hash_value = username.hash()
	var hue = float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.7, 0.9)

func _get_off_screen_spawn_position() -> Vector2:
	var player = GameController.instance.player
	if not player:
		return Vector2.ZERO
	
	var camera = player.get_node("Camera2D") as Camera2D
	if not camera:
		return player.global_position + Vector2(300, 0)
	
	# Same off-screen spawning logic as original
	var viewport_size = camera.get_viewport_rect().size
	var zoom = camera.zoom
	var camera_pos = camera.get_screen_center_position()
	
	var visible_width = viewport_size.x / zoom.x
	var _visible_height = viewport_size.y / zoom.y
	
	# Try to find a valid spawn position
	for attempt in range(20):
		var angle = randf() * TAU
		var distance = randf_range(visible_width * 0.6, visible_width * 1.2)
		var spawn_pos = camera_pos + Vector2(cos(angle), sin(angle)) * distance
		
		if GameController.instance._is_position_safe(spawn_pos):
			return spawn_pos
	
	# Fallback
	var fallback_angle = randf() * TAU
	var fallback_dist = visible_width * 0.8
	return camera_pos + Vector2(cos(fallback_angle), sin(fallback_angle)) * fallback_dist

# Ramping system (same as original)
func _apply_time_ramp():
	time_ramp_bonus = time_ramp_bonus + RAMP_AMOUNT
	_recalculate_threshold()

func add_boss_death_bonus():
	boss_death_bonus = boss_death_bonus + BOSS_DEATH_BONUS_AMOUNT
	_recalculate_threshold()

func _recalculate_threshold():
	monster_power_threshold = base_monster_power_threshold + time_ramp_bonus + boss_death_bonus
	monster_power_changed.emit(current_monster_power, monster_power_threshold)

func adjust_monster_power_threshold(delta: float):
	base_monster_power_threshold = max(0.0, base_monster_power_threshold + delta)
	_recalculate_threshold()

func get_ramping_stats() -> Dictionary:
	return {
		"base": base_monster_power_threshold,
		"time_bonus": time_ramp_bonus,
		"boss_bonus": boss_death_bonus,
		"total": monster_power_threshold,
		"current_power": current_monster_power,
		"time_to_next_ramp": RAMP_INTERVAL - ramp_timer
	}
