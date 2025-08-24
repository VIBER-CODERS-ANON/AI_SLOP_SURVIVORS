extends Node
class_name AbilityExecutor

## MODULAR ABILITY EXECUTION SYSTEM
## Executes abilities from AbilityResource definitions
## Works with both multimesh enemies (data-oriented) and node-based bosses

static var instance: AbilityExecutor

signal ability_executed(entity_id: int, ability_id: String)
signal ability_failed(entity_id: int, ability_id: String, reason: String)

# Ability cooldowns per entity
var entity_cooldowns: Dictionary = {}  # entity_id -> Dictionary[ability_id -> float]

# Active abilities tracking
var active_abilities: Dictionary = {}  # entity_id -> Array[AbilityResource]

# References to other systems
var enemy_manager: EnemyManager
var game_controller: Node

func _ready():
	instance = self
	call_deferred("_connect_to_systems")
	print("⚡ AbilityExecutor initialized")

func _connect_to_systems():
	enemy_manager = EnemyManager.instance
	game_controller = GameController.instance
	
	if enemy_manager:
		print("✅ AbilityExecutor connected to EnemyManager")
	else:
		print("⚠️ AbilityExecutor: EnemyManager not found")

func _process(delta: float):
	_update_cooldowns(delta)
	_update_ability_ai(delta)

func _update_cooldowns(delta: float):
	for entity_id in entity_cooldowns:
		var cooldowns = entity_cooldowns[entity_id]
		for ability_id in cooldowns:
			if cooldowns[ability_id] > 0:
				cooldowns[ability_id] -= delta

# AI system for ability execution
func _update_ability_ai(delta: float):
	if not enemy_manager or not game_controller or not game_controller.player:
		return
	
	# Debug: Show how many entities have abilities (use member var instead of static)
	if not has_meta("debug_timer"):
		set_meta("debug_timer", 0.0)
	var debug_timer = get_meta("debug_timer") + delta
	set_meta("debug_timer", debug_timer)
	if active_abilities.size() > 0 and debug_timer > 2.0:
		set_meta("debug_timer", 0.0)
		print("🔍 AbilityExecutor tracking %d entities with abilities" % active_abilities.size())
	
	# Process each entity with registered abilities
	for entity_id in active_abilities:
		# Skip dead entities
		if entity_id >= enemy_manager.alive_flags.size() or enemy_manager.alive_flags[entity_id] == 0:
			continue
		
		# Skip entities currently casting
		if entity_id < enemy_manager.ability_casting_flags.size() and enemy_manager.ability_casting_flags[entity_id] > 0:
			continue
		
		# Get entity position
		var entity_pos = _get_entity_position(entity_id)
		if entity_pos == Vector2.INF:
			continue
		
		var player_pos = game_controller.player.global_position
		var distance_to_player = entity_pos.distance_to(player_pos)
		
		# Try abilities in order (priority based on array order)
		var abilities = active_abilities[entity_id]
		for ability_res in abilities:
			if not ability_res is AbilityResource:
				continue
			
			# Skip passive abilities
			if ability_res.trigger_type == "passive":
				continue
			
			# Skip command-only abilities
			var is_command_only = ability_res.additional_parameters.get("command_only", false)
			if is_command_only:
				continue
			
			# Check cooldown - if on cooldown, skip to next ability
			if not _check_cooldown(entity_id, ability_res.ability_id):
				continue
			
			# IMPORTANT: If we reach here, the ability is OFF cooldown
			# This means we MUST try to use it and NOT fall through to other abilities
			# The only exception is if we're out of range - then we wait
			
			# Check if we're in range for this ability
			var range_buffer = 0.95 if ability_res.trigger_type == "channeled" else 1.0
			if distance_to_player > ability_res.ability_range * range_buffer:
				# Out of range for our highest priority ability that's off cooldown
				# DON'T try other abilities - just wait to get in range
				break
			
			# We're in range and off cooldown - prepare to execute
			var target_data = _prepare_target_data(ability_res, entity_pos, player_pos)
			
			print("🎮 Entity %d attempting ability: %s (range: %.0f, distance: %.0f)" % [entity_id, ability_res.ability_id, ability_res.ability_range, distance_to_player])
			
			# Try to execute ability
			if execute_ability(entity_id, ability_res, target_data):
				print("  ✅ Ability executed successfully!")
			else:
				print("  ❌ Ability execution failed!")
			
			# Whether it succeeded or failed, we tried our highest priority ability
			# Don't fall through to lower priority abilities
			break


# Prepare target data based on ability type
func _prepare_target_data(ability: AbilityResource, entity_pos: Vector2, player_pos: Vector2) -> Dictionary:
	var target_data = {
		"target_position": player_pos,
		"target_enemy": game_controller.player if game_controller.player else null,
		"direction": (player_pos - entity_pos).normalized()
	}
	
	# That's it! Simple and generic
	# Each ability handler will use what it needs from the target_data
	
	return target_data

# Register abilities for an entity from resources
func register_entity_abilities(entity_id: int, abilities: Array):
	if not active_abilities.has(entity_id):
		active_abilities[entity_id] = []
		entity_cooldowns[entity_id] = {}
	
	for ability in abilities:
		if ability is AbilityResource:
			active_abilities[entity_id].append(ability)
			entity_cooldowns[entity_id][ability.ability_id] = 0.0
			print("  ✅ Registered ability: %s for entity %d" % [ability.ability_id, entity_id])
		else:
			print("  ❌ Invalid ability resource in array")
	
	print("  📊 Entity %d now has %d abilities" % [entity_id, active_abilities[entity_id].size()])

# Execute ability from resource
func execute_ability(entity_id: int, ability_res: AbilityResource, target_data: Dictionary = {}):
	if not ability_res:
		ability_failed.emit(entity_id, "unknown", "Invalid ability resource")
		return false
	
	# Check cooldown
	if not _check_cooldown(entity_id, ability_res.ability_id):
		ability_failed.emit(entity_id, ability_res.ability_id, "On cooldown")
		return false
	
	# Get entity position (works for both multimesh and node entities)
	var entity_pos = _get_entity_position(entity_id)
	if entity_pos == Vector2.INF:
		ability_failed.emit(entity_id, ability_res.ability_id, "Invalid entity position")
		return false
	
	# Execute based on trigger type
	var success = false
	match ability_res.trigger_type:
		"instant":
			success = _execute_instant(entity_id, ability_res, entity_pos, target_data)
		"projectile":
			success = _execute_projectile(entity_id, ability_res, entity_pos, target_data)
		"channeled":
			success = _execute_channeled(entity_id, ability_res, entity_pos, target_data)
		"area":
			success = _execute_area(entity_id, ability_res, entity_pos, target_data)
		"passive":
			# Passive abilities don't execute actively
			return true
		_:
			ability_failed.emit(entity_id, ability_res.ability_id, "Unknown trigger type")
			return false
	
	if success:
		# Set cooldown
		_set_cooldown(entity_id, ability_res.ability_id, ability_res.cooldown)
		ability_executed.emit(entity_id, ability_res.ability_id)
	
	return success

# Execute ability by ID (convenience method)
func execute_ability_by_id(entity_id: int, ability_id: String, target_data: Dictionary = {}):
	if not active_abilities.has(entity_id):
		ability_failed.emit(entity_id, ability_id, "Entity has no abilities")
		return false
	
	for ability in active_abilities[entity_id]:
		if ability.ability_id == ability_id:
			return execute_ability(entity_id, ability, target_data)
	
	ability_failed.emit(entity_id, ability_id, "Ability not found")
	return false

func _execute_instant(entity_id: int, ability: AbilityResource, pos: Vector2, _target_data: Dictionary) -> bool:
	# Spawn effect if configured
	if ability.effect_scene:
		var effect = ability.effect_scene.instantiate()
		effect.global_position = pos
		
		# Apply scaling modifiers
		var aoe_scale = _get_entity_aoe_scale(entity_id)
		if aoe_scale > 1.0:
			effect.scale *= aoe_scale
		
		# Set damage if the effect has it
		if "damage" in effect:
			var damage_mult = _get_entity_damage_mult(entity_id)
			effect.damage = ability.damage * damage_mult
		
		# Set source for proper attribution
		var username = _get_entity_username(entity_id)
		if username != "" and "source_name" in effect:
			effect.source_name = username
		
		if game_controller:
			game_controller.add_child(effect)
		else:
			get_tree().current_scene.add_child(effect)
	
	# Play sound if configured
	if ability.sound_effect:
		_play_sound_at(ability.sound_effect, pos)
	
	return true

func _execute_projectile(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Special handling for heart_projectile ability
	if ability.ability_id == "heart_projectile":
		return _execute_heart_projectile(entity_id, ability, pos, target_data)
	
	# Generic projectile handling
	if not ability.effect_scene:
		return false
	
	var projectile = ability.effect_scene.instantiate()
	projectile.global_position = pos
	
	# Set projectile properties
	if "damage" in projectile:
		var damage_mult = _get_entity_damage_mult(entity_id)
		projectile.damage = ability.damage * damage_mult
	
	if "speed" in projectile:
		projectile.speed = ability.projectile_speed
	
	# Set direction toward target
	var target_pos = target_data.get("target_position", Vector2.ZERO)
	if target_pos == Vector2.ZERO and game_controller and game_controller.player:
		target_pos = game_controller.player.global_position
	
	if projectile.has_method("set_direction"):
		var direction = (target_pos - pos).normalized()
		projectile.set_direction(direction)
	
	# Set source
	var username = _get_entity_username(entity_id)
	if username != "" and "source_name" in projectile:
		projectile.source_name = username
	
	if game_controller:
		game_controller.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)
	
	return true

func _execute_channeled(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Special handling for suction ability
	if ability.ability_id == "suction":
		return _execute_suction(entity_id, ability, pos, target_data)
	
	# Generic channeled handling
	# Mark entity as casting (stops movement)
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 1
		
		# Create timer to end channel
		var timer = Timer.new()
		timer.wait_time = ability.duration if ability.duration > 0 else ability.cast_time
		timer.one_shot = true
		timer.timeout.connect(_end_channel.bind(entity_id))
		add_child(timer)
		timer.start()
	
	# Create channeling effect
	if ability.effect_scene:
		var effect = ability.effect_scene.instantiate()
		effect.global_position = pos
		
		# Apply scaling
		var aoe_scale = _get_entity_aoe_scale(entity_id)
		if aoe_scale > 1.0:
			effect.scale *= aoe_scale
		
		# Set channel duration
		if "duration" in effect:
			effect.duration = ability.duration if ability.duration > 0 else ability.cast_time
		
		# Set damage
		if "damage" in effect:
			var damage_mult = _get_entity_damage_mult(entity_id)
			effect.damage = ability.damage * damage_mult
		
		# Set source
		var username = _get_entity_username(entity_id)
		if username != "" and "source_name" in effect:
			effect.source_name = username
		
		if game_controller:
			game_controller.add_child(effect)
		else:
			get_tree().current_scene.add_child(effect)
	
	return true

func _execute_area(entity_id: int, ability: AbilityResource, pos: Vector2, _target_data: Dictionary) -> bool:
	# Create area effect
	if ability.effect_scene:
		var area = ability.effect_scene.instantiate()
		area.global_position = pos
		
		# Set area properties
		if "radius" in area:
			var aoe_scale = _get_entity_aoe_scale(entity_id)
			area.radius = ability.ability_range * aoe_scale
		
		if "damage" in area:
			var damage_mult = _get_entity_damage_mult(entity_id)
			area.damage = ability.damage * damage_mult
		
		if "duration" in area:
			area.duration = ability.duration
		
		# Set source
		var username = _get_entity_username(entity_id)
		if username != "" and "source_name" in area:
			area.source_name = username
		
		if game_controller:
			game_controller.add_child(area)
		else:
			get_tree().current_scene.add_child(area)
	
	return true

func _end_channel(entity_id: int):
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 0

# Cooldown management
func _check_cooldown(entity_id: int, ability_id: String) -> bool:
	if not entity_cooldowns.has(entity_id):
		return true
	
	var cooldowns = entity_cooldowns[entity_id]
	if not cooldowns.has(ability_id):
		return true
	
	return cooldowns[ability_id] <= 0

func _set_cooldown(entity_id: int, ability_id: String, cooldown: float):
	if not entity_cooldowns.has(entity_id):
		entity_cooldowns[entity_id] = {}
	
	entity_cooldowns[entity_id][ability_id] = cooldown

# Helper functions
func _get_entity_position(entity_id: int) -> Vector2:
	# Check if it's a multimesh enemy
	if enemy_manager and entity_id >= 0 and entity_id < enemy_manager.positions.size():
		if enemy_manager.alive_flags[entity_id] > 0:
			return enemy_manager.positions[entity_id]
	
	# Check if it's a node-based entity (boss)
	# Bosses use negative IDs or are tracked separately
	# This would need to be implemented based on your boss tracking system
	
	return Vector2.INF

func _get_entity_username(entity_id: int) -> String:
	if enemy_manager and entity_id >= 0 and entity_id < enemy_manager.chatter_usernames.size():
		return enemy_manager.chatter_usernames[entity_id]
	return ""

func _get_entity_aoe_scale(entity_id: int) -> float:
	var username = _get_entity_username(entity_id)
	if username != "" and ChatterEntityManager.instance:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		if chatter_data and chatter_data.upgrades.has("bonus_aoe"):
			var bonus_aoe = chatter_data.upgrades.bonus_aoe
			var rarity_mult = chatter_data.upgrades.get("rarity_multiplier", 1.0)
			return (1.0 + bonus_aoe) * rarity_mult
	return 1.0

func _get_entity_damage_mult(entity_id: int) -> float:
	var username = _get_entity_username(entity_id)
	if username != "" and ChatterEntityManager.instance:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		if chatter_data and chatter_data.upgrades.has("bonus_damage"):
			var bonus_damage = chatter_data.upgrades.bonus_damage
			var rarity_mult = chatter_data.upgrades.get("rarity_multiplier", 1.0)
			return (1.0 + bonus_damage) * rarity_mult
	return 1.0

func _play_sound_at(sound: AudioStream, position: Vector2):
	if AudioManager.instance and AudioManager.instance.has_method("play_sound_at"):
		AudioManager.instance.play_sound_at(sound, position)
	else:
		# Fallback: create a simple audio player
		var player = AudioStreamPlayer2D.new()
		player.stream = sound
		player.global_position = position
		player.autoplay = true
		player.finished.connect(player.queue_free)
		if game_controller:
			game_controller.add_child(player)
		else:
			get_tree().current_scene.add_child(player)

# Cleanup when entity is removed
func cleanup_entity(entity_id: int):
	if active_abilities.has(entity_id):
		active_abilities.erase(entity_id)
	if entity_cooldowns.has(entity_id):
		entity_cooldowns.erase(entity_id)

# Specific ability implementations for succubus
func _execute_heart_projectile(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Get target
	var target_pos = target_data.get("target_position", Vector2.ZERO)
	if target_pos == Vector2.ZERO and game_controller and game_controller.player:
		target_pos = game_controller.player.global_position
	
	# Check range
	var distance = pos.distance_to(target_pos)
	if distance > ability.ability_range:
		return false  # Out of range
	
	# Mark entity as casting for windup
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 1
		
		# Create windup timer
		var windup_duration = ability.additional_parameters.get("windup_duration", 1.0)
		var timer = Timer.new()
		timer.wait_time = windup_duration
		timer.one_shot = true
		timer.timeout.connect(_fire_heart_projectile.bind(entity_id, ability, pos, target_pos))
		add_child(timer)
		timer.start()
	
	# Play kiss sound if configured
	var kiss_sound_path = ability.additional_parameters.get("kiss_sound_path", "")
	if kiss_sound_path != "":
		var kiss_sound = load(kiss_sound_path)
		if kiss_sound:
			_play_sound_at(kiss_sound, pos)
	
	return true

func _fire_heart_projectile(entity_id: int, ability: AbilityResource, pos: Vector2, target_pos: Vector2):
	# Clear casting flag
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 0
	
	# Play shoot sound
	if ability.sound_effect:
		_play_sound_at(ability.sound_effect, pos)
	
	# Create projectile
	var projectile_path = ability.additional_parameters.get("projectile_scene_path", "")
	if projectile_path != "":
		var projectile_scene = load(projectile_path)
		if projectile_scene:
			var projectile = projectile_scene.instantiate()
			projectile.global_position = pos
			
			# Set projectile properties
			var direction = (target_pos - pos).normalized()
			if projectile.has_method("setup"):
				var damage_mult = _get_entity_damage_mult(entity_id)
				var final_damage = ability.damage * damage_mult
				
				# Create proxy entity for attribution
				var proxy = Node2D.new()
				proxy.global_position = pos
				proxy.set_meta("entity_id", entity_id)
				
				projectile.setup(direction, ability.projectile_speed, final_damage, proxy)
				proxy.queue_free()
			
			# Set lifetime
			var lifetime = ability.additional_parameters.get("projectile_lifetime", 3.0)
			if "lifetime" in projectile:
				projectile.lifetime = lifetime
			
			if game_controller:
				game_controller.add_child(projectile)
			else:
				get_tree().current_scene.add_child(projectile)

func _execute_suction(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Validate preconditions
	if not _can_start_suction(entity_id, ability, pos, target_data):
		return false
	
	# IMMEDIATELY mark entity as casting to prevent re-entry
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 1
	
	# Create channel instance
	var channel = _create_suction_channel(entity_id, ability, pos, target_data)
	if not channel:
		# Failed to create channel, clear casting flag
		if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
			enemy_manager.ability_casting_flags[entity_id] = 0
		return false
	
	# Register channel
	_register_active_channel(entity_id, channel)
	
	print("🎯 Suction started by entity %d" % entity_id)
	return true

func _can_start_suction(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Check if already channeling
	if _is_entity_channeling(entity_id):
		return false
	
	# Check if already casting (via casting flag)
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		if enemy_manager.ability_casting_flags[entity_id] != 0:
			return false  # Already casting something
	
	# Validate target
	var target = target_data.get("target_enemy")
	if not target or not is_instance_valid(target):
		return false
	
	# Check range
	var distance = pos.distance_to(target.global_position)
	if distance > ability.ability_range:
		return false
	
	# Check entity can cast
	if not enemy_manager or entity_id >= enemy_manager.ability_casting_flags.size():
		return false
	
	return true

func _is_entity_channeling(entity_id: int) -> bool:
	if not has_meta("active_channels"):
		return false
	var channels = get_meta("active_channels")
	return channels.has(entity_id)

func _create_suction_channel(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_enemy")
	if not target:
		return {}
	
	# Extract parameters from ability resource
	var params = _extract_suction_parameters(ability)
	
	# Create visual component FIRST
	var beam = _create_suction_beam(pos, target.global_position, params)
	if not beam or not is_instance_valid(beam):
		print("❌ Failed to create suction beam for entity %d" % entity_id)
		return {}  # No beam = no channel
	
	# Create update timer
	var timer = _create_channel_timer()
	
	# Build channel data structure (NO AUDIO YET)
	var channel = {
		"entity_id": entity_id,
		"ability": ability,
		"target": target,
		"beam": beam,
		"audio": null,  # Will be created on first successful update
		"audio_stream": ability.sound_effect,  # Store for later
		"timer": timer,
		"duration_remaining": params.duration,
		"damage_delay_remaining": params.damage_delay,
		"damage_started": false,
		"damage_accumulator": 0.0,
		"damage_per_second": params.damage_total / params.duration,
		"break_distance": ability.ability_range * params.break_multiplier,
		"params": params
	}
	
	# Connect timer to update method
	timer.timeout.connect(_update_suction_channel.bind(channel))
	timer.start()
	
	return channel

func _extract_suction_parameters(ability: AbilityResource) -> Dictionary:
	var params = ability.additional_parameters
	return {
		"duration": params.get("channel_duration", 3.0),
		"damage_delay": params.get("damage_delay", 0.8),
		"damage_total": params.get("damage_total", 18.75),
		"beam_color": params.get("beam_color", Color(1.0, 0.2, 0.5, 0.7)),
		"beam_width": params.get("beam_width", 20.0),
		"break_multiplier": params.get("break_distance_multiplier", 1.2)
	}

func _create_suction_beam(start_pos: Vector2, end_pos: Vector2, params: Dictionary) -> Line2D:
	var beam = Line2D.new()
	beam.width = params.beam_width * 0.7
	beam.default_color = Color(1.0, 0.4, 0.7, 0.5)
	beam.add_point(start_pos)
	beam.add_point(end_pos)
	beam.z_index = -1
	
	# Create gradient effect
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.4, 0.7, 0.2))
	gradient.add_point(0.7, Color(1.0, 0.5, 0.7, 0.4))
	gradient.add_point(1.0, Color(1.0, 0.3, 0.6, 0.6))
	beam.gradient = gradient
	
	# Add to scene
	if game_controller:
		game_controller.add_child(beam)
	else:
		get_tree().current_scene.add_child(beam)
	
	return beam


func _create_channel_timer() -> Timer:
	var timer = Timer.new()
	timer.wait_time = 0.05  # 20 updates per second
	timer.one_shot = false
	add_child(timer)
	return timer

func _register_active_channel(entity_id: int, channel: Dictionary):
	if not has_meta("active_channels"):
		set_meta("active_channels", {})
	var channels = get_meta("active_channels")
	channels[entity_id] = channel

func _update_suction_channel(channel_data: Dictionary):
	# Validate channel can continue
	if not _validate_channel_continuation(channel_data):
		_end_suction_channel(channel_data)
		return
	
	# Update visual components
	_update_channel_visuals(channel_data)
	
	# Update timing
	_update_channel_timing(channel_data)
	
	# Process damage
	_process_channel_damage(channel_data)
	
	# Check completion
	if _is_channel_complete(channel_data):
		_end_suction_channel(channel_data)

func _validate_channel_continuation(channel_data: Dictionary) -> bool:
	# Check entity alive
	if not _is_entity_alive(channel_data.entity_id):
		return false
	
	# Check target valid - MUST check this before accessing target properties
	var target = channel_data.get("target")
	if not _is_target_valid(target):
		return false
	
	# Check position valid
	var entity_pos = _get_entity_position(channel_data.entity_id)
	if entity_pos == Vector2.INF:
		return false
	
	# Now safe to access target.global_position since we validated it
	if not _is_within_break_distance(entity_pos, target.global_position, channel_data.break_distance):
		return false
	
	return true

func _is_entity_alive(entity_id: int) -> bool:
	if not enemy_manager or entity_id >= enemy_manager.alive_flags.size():
		return false
	return enemy_manager.alive_flags[entity_id] != 0

func _is_target_valid(target) -> bool:
	# First check if target exists
	if not target:
		return false
	
	# Check if it's a valid instance (not freed)
	if not is_instance_valid(target):
		return false
	
	# Additional check for Node types
	if target is Node:
		# Check if it's still in the tree (not queued for deletion)
		if not target.is_inside_tree():
			return false
		
		# Check if it's being deleted
		if target.is_queued_for_deletion():
			return false
	
	return true

func _is_within_break_distance(from: Vector2, to: Vector2, max_distance: float) -> bool:
	return from.distance_to(to) <= max_distance

func _update_channel_visuals(channel_data: Dictionary):
	var beam = channel_data.get("beam")
	if not beam or not is_instance_valid(beam):
		return
	
	var target = channel_data.get("target")
	if not _is_target_valid(target):
		return
	
	var entity_pos = _get_entity_position(channel_data.entity_id)
	var target_pos = target.global_position
	
	# Update beam points
	beam.points[0] = entity_pos
	beam.points[1] = target_pos
	
	# Handle audio - create it ONLY if beam exists and we don't have audio yet
	_ensure_channel_audio(channel_data, entity_pos)

func _ensure_channel_audio(channel_data: Dictionary, entity_pos: Vector2):
	# Only create audio if:
	# 1. We have a valid beam
	# 2. We don't have audio yet
	# 3. We have an audio stream to play
	
	var beam = channel_data.get("beam")
	if not beam or not is_instance_valid(beam):
		return  # No beam = no audio
	
	var audio = channel_data.get("audio")
	if audio and is_instance_valid(audio):
		# Audio exists, just update position
		audio.global_position = entity_pos
		return
	
	# Create audio for the first time
	var audio_stream = channel_data.get("audio_stream")
	if audio_stream:
		var new_audio = _create_channel_audio(entity_pos, audio_stream)
		if new_audio:
			channel_data["audio"] = new_audio
			print("🔊 Suction audio started for entity %d" % channel_data.entity_id)

func _create_channel_audio(pos: Vector2, sound: AudioStream) -> AudioStreamPlayer2D:
	if not sound:
		return null
	
	var audio = AudioStreamPlayer2D.new()
	audio.stream = sound
	audio.global_position = pos
	audio.bus = "SFX"
	audio.volume_db = -5.0
	audio.max_distance = 2000.0
	
	# Add to scene tree FIRST
	if game_controller:
		game_controller.add_child(audio)
	else:
		get_tree().current_scene.add_child(audio)
	
	# Play AFTER it's in the tree
	audio.play()
	
	return audio

func _update_channel_timing(channel_data: Dictionary):
	var delta = 0.05  # Timer tick rate
	channel_data.duration_remaining -= delta
	
	# Handle damage delay phase
	if not channel_data.damage_started and channel_data.damage_delay_remaining > 0:
		channel_data.damage_delay_remaining -= delta
		if channel_data.damage_delay_remaining <= 0:
			_activate_damage_phase(channel_data)

func _activate_damage_phase(channel_data: Dictionary):
	channel_data.damage_started = true
	
	# Intensify beam visual
	var beam = channel_data.beam
	if beam and is_instance_valid(beam):
		var base_width = channel_data.params.get("beam_width", 20.0)
		beam.width = base_width * 1.5
		beam.default_color = Color(1.0, 0.1, 0.4, 0.9)

func _process_channel_damage(channel_data: Dictionary):
	if not channel_data.damage_started:
		return
	
	# Calculate damage per tick
	var delta = 0.05
	var damage_per_tick = channel_data.damage_per_second * delta
	channel_data.damage_accumulator += damage_per_tick
	
	# Apply accumulated damage
	if channel_data.damage_accumulator >= 1.0:
		_apply_accumulated_damage(channel_data)

func _apply_accumulated_damage(channel_data: Dictionary):
	var damage_to_apply = int(channel_data.damage_accumulator)
	channel_data.damage_accumulator -= damage_to_apply
	
	var target = channel_data.get("target")
	if not _is_target_valid(target):
		return
	
	if target.has_method("take_damage"):
		# Create damage source proxy for attribution
		var proxy = _create_damage_proxy(channel_data.entity_id)
		target.take_damage(damage_to_apply, proxy)
		proxy.queue_free()

func _create_damage_proxy(entity_id: int) -> Node2D:
	var proxy = Node2D.new()
	proxy.set_meta("entity_id", entity_id)
	proxy.global_position = _get_entity_position(entity_id)
	return proxy

func _is_channel_complete(channel_data: Dictionary) -> bool:
	return channel_data.duration_remaining <= 0

func _end_suction_channel(channel_data: Dictionary):
	var entity_id = channel_data.entity_id
	
	# Clear entity state
	_clear_entity_casting_state(entity_id)
	
	# Cleanup visual components
	_cleanup_channel_visuals(channel_data)
	
	# Cleanup audio components
	_cleanup_channel_audio(channel_data)
	
	# Cleanup timer
	_cleanup_channel_timer(channel_data)
	
	# Unregister channel
	_unregister_channel(entity_id)
	
	print("🛑 Suction ended for entity %d" % entity_id)

func _clear_entity_casting_state(entity_id: int):
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 0

func _cleanup_channel_visuals(channel_data: Dictionary):
	var beam = channel_data.get("beam")
	if beam and is_instance_valid(beam):
		beam.queue_free()

func _cleanup_channel_audio(channel_data: Dictionary):
	var audio = channel_data.get("audio")
	if audio and is_instance_valid(audio):
		audio.stop()
		audio.queue_free()
		print("🔇 Suction audio stopped for entity %d" % channel_data.entity_id)

func _cleanup_channel_timer(channel_data: Dictionary):
	var timer = channel_data.get("timer")
	if timer and is_instance_valid(timer):
		timer.stop()
		timer.queue_free()

func _unregister_channel(entity_id: int):
	if not has_meta("active_channels"):
		return
	var channels = get_meta("active_channels")
	channels.erase(entity_id)
