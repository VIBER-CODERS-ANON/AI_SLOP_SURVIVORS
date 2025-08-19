extends Node
class_name TicketSpawnManager

signal chatter_joined(username: String)
signal entity_spawned(username: String, entity: Node)
signal monster_power_changed(current_power: float, threshold: float)

static var instance: TicketSpawnManager

# Session tracking
var joined_chatters: Dictionary = {}  # username -> { monster_type: String, ticket_multiplier: float }

# Ticket pool
var ticket_pool: Array = []  # Array of { username: String, weight: int }
var total_tickets: int = 0

# Monster power tracking
var alive_monsters: Dictionary = {}  # username -> Array[entity]
var current_monster_power: float = 0.0

# Ramping system - simple addition only
var base_monster_power_threshold: float = 0.0  # Starting threshold (starts at 0)
var time_ramp_bonus: float = 0.0  # Accumulated time bonus
var boss_death_bonus: float = 0.0  # Accumulated boss bonus
var monster_power_threshold: float = 0.0  # Total threshold (base + time + boss)

# Monster ticket values (base values)
const MONSTER_TICKETS = {
	"twitch_rat": 100,
	"succubus": 20,  # Reduced from 33
	"woodland_joe": 20
}

# Spawn settings
var spawn_check_interval: float = 0.5  # Check every 0.5 seconds
var spawn_timer: float = 0.0
var max_spawn_per_tick: int = 5  # Prevent lag spikes

# Off-screen spawn settings (pixels from edge of screen)
var spawn_inner_margin: float = 50.0  # Minimum distance from screen edge
var spawn_outer_margin: float = 300.0  # Maximum distance from screen edge

# Ramping timers
var ramp_timer: float = 0.0
const RAMP_INTERVAL: float = 1.0  # Every 1 second
const RAMP_AMOUNT: float = 0.002  # +0.002 per interval
const BOSS_DEATH_BONUS_AMOUNT: float = 1.0  # +1 per boss death

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE
	print("🎫 Ticket Spawn Manager initialized!")

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
	
	# Clean up all alive monsters
	for username in alive_monsters:
		var entities = alive_monsters[username]
		for entity in entities:
			if is_instance_valid(entity):
				entity.queue_free()
	alive_monsters.clear()
	current_monster_power = 0.0
	
	print("🎫 Session reset - all chatters and monsters cleared")

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
		"ticket_multiplier": 1.0  # Will be modified by upgrades
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
	if ticket_pool.is_empty():
		return
	
	# Calculate current monster power
	_update_monster_power()
	
	# Spawn monsters if below threshold
	var spawns_this_tick = 0
	while current_monster_power < monster_power_threshold and spawns_this_tick < max_spawn_per_tick:
		if not await _spawn_random_monster():
			break
		spawns_this_tick += 1
		_update_monster_power()

func _spawn_random_monster() -> bool:
	if ticket_pool.is_empty():
		return false
	
	# Draw random ticket
	var ticket_index = randi() % ticket_pool.size()
	var username = ticket_pool[ticket_index]
	
	if not joined_chatters.has(username):
		return false
	
	var data = joined_chatters[username]
	var monster_type = data.monster_type
	
	# Get spawn position
	if not GameController.instance or not GameController.instance.player:
		return false
	
	# Use clever off-screen spawning
	var spawn_pos = _get_off_screen_spawn_position()
	
	# Determine scene path based on monster type
	var scene_path = _get_monster_scene_path(monster_type)
	
	# Create the creature
	var color = _get_user_color(username)
	var creature = BaseCreature.create_chatter_entity(scene_path, username, color)
	if not creature:
		return false
	
	creature.process_mode = Node.PROCESS_MODE_PAUSABLE
	GameController.instance.add_child(creature)
	creature.global_position = spawn_pos
	
	# Wait for initialization
	await GameController.instance.get_tree().process_frame
	
	# Assign NPC rarity
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager:
		rarity_manager.assign_random_rarity(creature)
	
	# Apply upgrades
	ChatterEntityManager.instance.apply_upgrades_to_entity(creature, username)
	
	# Track the entity
	if not alive_monsters.has(username):
		alive_monsters[username] = []
	alive_monsters[username].append(creature)
	
	# Connect death signal
	creature.died.connect(_on_monster_died.bind(username, creature))
	
	# Store username in creature for command handling
	creature.set_meta("chatter_username", username)
	
	entity_spawned.emit(username, creature)
	
	# Debug: Verify off-screen spawning
	if Engine.is_editor_hint() or OS.is_debug_build():
		var camera = GameController.instance.player.get_node("Camera2D") as Camera2D
		if camera:
			var viewport_rect = camera.get_viewport_rect()
			var screen_pos = camera.unproject_position(creature.global_position) if camera.has_method("unproject_position") else Vector2.ZERO
			print("🎯 Spawned %s at world pos %s (off-screen: %s)" % [
				monster_type,
				creature.global_position,
				not viewport_rect.has_point(screen_pos)
			])
	
	return true

func _get_monster_scene_path(monster_type: String) -> String:
	match monster_type:
		"succubus":
			return "res://entities/enemies/succubus.tscn"
		"woodland_joe":
			return "res://entities/enemies/woodland_joe.tscn"
		_:
			return "res://entities/enemies/twitch_rat.tscn"

func _on_monster_died(_killer_name: String, _death_cause: String, username: String, entity: Node):
	if not alive_monsters.has(username):
		return
	
	var entities = alive_monsters[username]
	var index = entities.find(entity)
	if index >= 0:
		entities.remove_at(index)
	
	# Clear NPC rarity
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager and is_instance_valid(entity):
		rarity_manager.clear_rarity(entity)
	
	# Clean up empty arrays
	if entities.is_empty():
		alive_monsters.erase(username)
	
	_update_monster_power()

func _update_monster_power():
	current_monster_power = 0.0
	
	for username in alive_monsters:
		if not joined_chatters.has(username):
			continue
		
		var data = joined_chatters[username]
		var base_tickets = MONSTER_TICKETS.get(data.monster_type, 100)
		var monster_power = 1.0 / base_tickets
		
		var entities = alive_monsters[username]
		for entity in entities:
			if is_instance_valid(entity) and entity.is_alive:
				current_monster_power += monster_power
	
	monster_power_changed.emit(current_monster_power, monster_power_threshold)

func get_alive_entities_for_chatter(username: String) -> Array:
	if not alive_monsters.has(username):
		return []
	
	var valid_entities = []
	var entities = alive_monsters[username]
	
	for entity in entities:
		if is_instance_valid(entity) and entity.is_alive:
			valid_entities.append(entity)
	
	return valid_entities

func set_monster_power_threshold(_new_threshold: float):
	# Deprecated - use add_boss_death_bonus() instead
	print("⚠️ set_monster_power_threshold is deprecated. Use ramping system instead.")

func _get_user_color(username: String) -> Color:
	var hash_value = username.hash()
	var hue = float(hash_value % 360) / 360.0
	return Color.from_hsv(hue, 0.7, 0.9)

func _get_off_screen_spawn_position() -> Vector2:
	## Clever off-screen spawning system that ensures monsters spawn outside the player's view
	## Uses a "donut" zone just outside the camera's visible area for optimal spawning
	
	var player = GameController.instance.player
	if not player:
		return Vector2.ZERO
	
	var camera = player.get_node("Camera2D") as Camera2D
	if not camera:
		return player.global_position + Vector2(300, 0)  # Fallback
	
	# Get viewport size and calculate visible rectangle in world coordinates
	var viewport_size = camera.get_viewport_rect().size
	var zoom = camera.zoom  # In Godot 4, lower zoom = zoomed in
	var camera_pos = camera.get_screen_center_position()
	
	# Calculate the visible area size in world coordinates
	var visible_width = viewport_size.x / zoom.x
	var visible_height = viewport_size.y / zoom.y
	
	# Define spawn zone boundaries (donut shape around visible area)
	# Inner boundary: Just outside the screen (configurable buffer)
	var inner_margin = spawn_inner_margin / zoom.x  # Convert pixel margin to world units
	var inner_rect = Rect2(
		camera_pos - Vector2(visible_width/2 + inner_margin, visible_height/2 + inner_margin),
		Vector2(visible_width + inner_margin * 2, visible_height + inner_margin * 2)
	)
	
	# Outer boundary: Not too far from screen (configurable max distance)
	var outer_margin = spawn_outer_margin / zoom.x  # Convert pixel margin to world units
	var _outer_rect = Rect2(
		camera_pos - Vector2(visible_width/2 + outer_margin, visible_height/2 + outer_margin),
		Vector2(visible_width + outer_margin * 2, visible_height + outer_margin * 2)
	)
	
	# Arena boundaries - use hardcoded arena size since GameController doesn't have arena_radius
	var arena_radius = 1500.0  # Half of 3000 arena size
	
	# Try to find a valid spawn position
	for attempt in range(50):
		var spawn_pos: Vector2
		
		# Smart sector-based spawning for even distribution
		var sector = attempt % 8  # Divide into 8 sectors around the player
		var base_angle = (sector * PI / 4) + randf_range(-PI/8, PI/8)
		
		# Choose distance in the donut zone
		var min_dist = (visible_width + visible_height) / 4 + inner_margin
		var max_dist = min_dist + (outer_margin - inner_margin)
		var distance = randf_range(min_dist, max_dist)
		
		spawn_pos = camera_pos + Vector2(cos(base_angle), sin(base_angle)) * distance
		
		# Validate position
		if not _is_position_valid_for_spawn(spawn_pos, camera_pos, inner_rect, arena_radius):
			continue
		
		# Check for obstacles
		if GameController.instance._is_position_safe(spawn_pos):
			return spawn_pos
	
	# Fallback: Expand search area if no valid position found
	for attempt in range(20):
		var angle = randf() * TAU
		var distance = randf_range(visible_width * 0.6, visible_width * 1.2)
		var spawn_pos = camera_pos + Vector2(cos(angle), sin(angle)) * distance
		
		if spawn_pos.distance_to(Vector2.ZERO) < arena_radius:
			if GameController.instance._is_position_safe(spawn_pos):
				return spawn_pos
	
	# Last resort fallback
	var fallback_angle = randf() * TAU
	var fallback_dist = visible_width * 0.8
	return camera_pos + Vector2(cos(fallback_angle), sin(fallback_angle)) * fallback_dist

func _is_position_valid_for_spawn(pos: Vector2, _camera_center: Vector2, inner_rect: Rect2, arena_radius: float) -> bool:
	# Check if position is outside the visible area (not in inner rect)
	if inner_rect.has_point(pos):
		return false
	
	# Check if within arena bounds
	if pos.distance_to(Vector2.ZERO) > arena_radius:
		return false
	
	return true

# Ramping System Functions - Simple addition only
func _apply_time_ramp():
	time_ramp_bonus = time_ramp_bonus + RAMP_AMOUNT
	_recalculate_threshold()
	print("⏰ Time ramp: +%.3f (total time bonus: %.3f)" % [RAMP_AMOUNT, time_ramp_bonus])

func add_boss_death_bonus():
	boss_death_bonus = boss_death_bonus + BOSS_DEATH_BONUS_AMOUNT
	_recalculate_threshold()
	print("💀 Boss killed! +%.1f power (total boss bonus: %.1f)" % [BOSS_DEATH_BONUS_AMOUNT, boss_death_bonus])

func _recalculate_threshold():
	# Simple kindergarten math: base + time + boss
	monster_power_threshold = base_monster_power_threshold + time_ramp_bonus + boss_death_bonus
	print("🎯 Monster power threshold: %.2f (base: %.1f + time: %.1f + boss: %.1f)" % [
		monster_power_threshold,
		base_monster_power_threshold,
		time_ramp_bonus,
		boss_death_bonus
	])
	monster_power_changed.emit(current_monster_power, monster_power_threshold)

func get_ramping_stats() -> Dictionary:
	return {
		"base": base_monster_power_threshold,
		"time_bonus": time_ramp_bonus,
		"boss_bonus": boss_death_bonus,
		"total": monster_power_threshold,
		"current_power": current_monster_power,
		"time_to_next_ramp": RAMP_INTERVAL - ramp_timer
	}

## Adjust the monster power threshold manually (e.g., via UI button)
func adjust_monster_power_threshold(delta: float):
	base_monster_power_threshold = max(0.0, base_monster_power_threshold + delta)
	_recalculate_threshold()
