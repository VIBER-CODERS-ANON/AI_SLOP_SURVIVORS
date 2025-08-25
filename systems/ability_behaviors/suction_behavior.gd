extends BaseAbilityBehavior
class_name SuctionBehavior

## Self-contained beam-based life drain channeled ability
## Handles full lifecycle: start → continuous updates → break distance → cleanup
## Based on proven patterns from original hardcoded implementation

# Static/persistent data storage for active channels
static var active_channels: Dictionary = {}
static var instance: SuctionBehavior = null

func _init():
	if not instance:
		instance = self

func execute(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Validate preconditions (same as original)
	if not _can_start_suction(entity_id, ability, pos, target_data):
		return false
	
	# Mark entity as casting (prevents other abilities)
	_static_set_entity_casting(entity_id, true)
	
	# Create channel instance
	var channel = _create_suction_channel(entity_id, ability, pos, target_data)
	if not channel:
		_static_set_entity_casting(entity_id, false)
		return false
	
	# Register channel in static storage
	active_channels[entity_id] = channel
	
	print("🎯 Suction started by entity %d" % entity_id)
	return true

func _can_start_suction(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Check if already channeling
	if active_channels.has(entity_id):
		return false
	
	# Check if already casting
	if _static_is_entity_casting(entity_id):
		return false
	
	# Validate target
	var target = target_data.get("target_enemy")
	if not target or not is_instance_valid(target):
		return false
	
	# Check range
	var distance = pos.distance_to(target.global_position)
	if distance > ability.ability_range:
		return false
	
	return true

func _create_suction_channel(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> Dictionary:
	var target = target_data.get("target_enemy")
	if not target:
		return {}
	
	# Extract parameters from ability resource
	var params = _extract_suction_parameters(ability)
	
	# Create visual beam
	var beam = _create_suction_beam(pos, target.global_position, params)
	if not beam:
		print("❌ Failed to create suction beam for entity %d" % entity_id)
		return {}
	
	# Create update timer
	var timer = Timer.new()
	timer.wait_time = 0.05  # 20 updates per second
	timer.one_shot = false
	
	# Add timer to persistent scene
	if GameController.instance:
		GameController.instance.add_child(timer)
	else:
		Engine.get_main_loop().current_scene.add_child(timer)
	
	# Build channel data structure
	var channel = {
		"entity_id": entity_id,
		"ability": ability,
		"target": target,
		"beam": beam,
		"audio": null,  # Will be created on first successful update
		"audio_stream": ability.sound_effect,
		"timer": timer,
		"duration_remaining": params.duration,
		"damage_delay_remaining": params.damage_delay,
		"damage_started": false,
		"damage_accumulator": 0.0,
		"damage_per_second": params.damage_total / params.duration,
		"break_distance": ability.ability_range * params.break_multiplier,
		"params": params
	}
	
	# Connect timer to update method using static reference
	timer.timeout.connect(_static_update_suction_channel.bind(entity_id))
	timer.start()
	
	return channel

func _extract_suction_parameters(ability: AbilityResource) -> Dictionary:
	var params = ability.additional_parameters
	return {
		"duration": params.get("channel_duration", ability.duration),
		"damage_delay": params.get("damage_delay", ability.cast_time),
		"damage_total": params.get("damage_total", ability.damage),
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
	if GameController.instance:
		GameController.instance.add_child(beam)
	else:
		Engine.get_main_loop().current_scene.add_child(beam)
	
	return beam

# Static method for timer callbacks
static func _static_update_suction_channel(entity_id: int):
	if not active_channels.has(entity_id):
		return
	
	var channel_data = active_channels[entity_id]
	
	# Validate channel can continue
	if not _static_validate_channel_continuation(channel_data):
		_static_end_suction_channel(channel_data)
		return
	
	# Update visual components
	_static_update_channel_visuals(channel_data)
	
	# Update timing
	_static_update_channel_timing(channel_data)
	
	# Process damage
	_static_process_channel_damage(channel_data)
	
	# Check completion
	if _static_is_channel_complete(channel_data):
		_static_end_suction_channel(channel_data)

static func _static_validate_channel_continuation(channel_data: Dictionary) -> bool:
	# Check entity alive
	if not _static_is_entity_alive(channel_data.entity_id):
		return false
	
	# Check target valid
	var target = channel_data.get("target")
	if not _static_is_target_valid(target):
		return false
	
	# Check position valid
	var entity_pos = _static_get_entity_position(channel_data.entity_id)
	if entity_pos == Vector2.INF:
		return false
	
	# Check break distance
	if not _static_is_within_break_distance(entity_pos, target.global_position, channel_data.break_distance):
		return false
	
	return true

static func _static_update_channel_visuals(channel_data: Dictionary):
	var beam = channel_data.get("beam")
	if not beam or not is_instance_valid(beam):
		return
	
	var target = channel_data.get("target")
	if not _static_is_target_valid(target):
		return
	
	var entity_pos = _static_get_entity_position(channel_data.entity_id)
	var target_pos = target.global_position
	
	# Update beam points
	beam.points[0] = entity_pos
	beam.points[1] = target_pos
	
	# Handle audio - create it ONLY if beam exists and we don't have audio yet
	_static_ensure_channel_audio(channel_data, entity_pos)

static func _static_ensure_channel_audio(channel_data: Dictionary, entity_pos: Vector2):
	var beam = channel_data.get("beam")
	if not beam or not is_instance_valid(beam):
		return
	
	var audio = channel_data.get("audio")
	if audio and is_instance_valid(audio):
		audio.global_position = entity_pos
		return
	
	# Create audio for the first time
	var audio_stream = channel_data.get("audio_stream")
	if audio_stream:
		var new_audio = _static_create_channel_audio(entity_pos, audio_stream)
		if new_audio:
			channel_data["audio"] = new_audio

static func _static_create_channel_audio(pos: Vector2, sound: AudioStream) -> AudioStreamPlayer2D:
	if not sound:
		return null
	
	var audio = AudioStreamPlayer2D.new()
	audio.stream = sound
	audio.global_position = pos
	audio.bus = "SFX"
	audio.volume_db = -5.0
	audio.max_distance = 2000.0
	
	# Add to scene tree first
	if GameController.instance:
		GameController.instance.add_child(audio)
	else:
		Engine.get_main_loop().current_scene.add_child(audio)
	
	# Play after it's in the tree
	audio.play()
	
	return audio

static func _static_update_channel_timing(channel_data: Dictionary):
	var delta = 0.05  # Timer tick rate
	channel_data.duration_remaining -= delta
	
	# Handle damage delay phase
	if not channel_data.damage_started and channel_data.damage_delay_remaining > 0:
		channel_data.damage_delay_remaining -= delta
		if channel_data.damage_delay_remaining <= 0:
			_static_activate_damage_phase(channel_data)

static func _static_activate_damage_phase(channel_data: Dictionary):
	channel_data.damage_started = true
	
	# Intensify beam visual
	var beam = channel_data.beam
	if beam and is_instance_valid(beam):
		var base_width = channel_data.params.get("beam_width", 20.0)
		beam.width = base_width * 1.5
		beam.default_color = Color(1.0, 0.1, 0.4, 0.9)

static func _static_process_channel_damage(channel_data: Dictionary):
	if not channel_data.damage_started:
		return
	
	# Calculate damage per tick
	var delta = 0.05
	var damage_per_tick = channel_data.damage_per_second * delta
	channel_data.damage_accumulator += damage_per_tick
	
	# Apply accumulated damage
	if channel_data.damage_accumulator >= 1.0:
		_static_apply_accumulated_damage(channel_data)

static func _static_apply_accumulated_damage(channel_data: Dictionary):
	var damage_to_apply = int(channel_data.damage_accumulator)
	channel_data.damage_accumulator -= damage_to_apply
	
	var target = channel_data.get("target")
	if not _static_is_target_valid(target):
		return
	
	if target.has_method("take_damage"):
		# Create damage source proxy for attribution
		var proxy = _static_create_damage_proxy(channel_data.entity_id)
		target.take_damage(damage_to_apply, proxy)
		proxy.queue_free()

static func _static_end_suction_channel(channel_data: Dictionary):
	var entity_id = channel_data.entity_id
	
	# Clear casting flag
	_static_set_entity_casting(entity_id, false)
	
	# Cleanup visual components
	_static_cleanup_channel_visuals(channel_data)
	
	# Cleanup audio components
	_static_cleanup_channel_audio(channel_data)
	
	# Cleanup timer
	_static_cleanup_channel_timer(channel_data)
	
	# Unregister channel
	active_channels.erase(entity_id)
	
	print("🛑 Suction ended for entity %d" % entity_id)

# Helper functions
static func _static_is_entity_alive(entity_id: int) -> bool:
	if EnemyManager.instance and entity_id >= 0 and entity_id < EnemyManager.instance.alive_flags.size():
		return EnemyManager.instance.alive_flags[entity_id] != 0
	return false

static func _static_is_target_valid(target) -> bool:
	if not target:
		return false
	if not is_instance_valid(target):
		return false
	if target is Node:
		if not target.is_inside_tree():
			return false
		if target.is_queued_for_deletion():
			return false
	return true

static func _static_is_within_break_distance(from: Vector2, to: Vector2, max_distance: float) -> bool:
	return from.distance_to(to) <= max_distance

static func _static_get_entity_position(entity_id: int) -> Vector2:
	if EnemyManager.instance and entity_id >= 0 and entity_id < EnemyManager.instance.positions.size():
		if EnemyManager.instance.alive_flags[entity_id] > 0:
			return EnemyManager.instance.positions[entity_id]
	return Vector2.INF

static func _static_create_damage_proxy(entity_id: int) -> Node2D:
	var proxy = Node2D.new()
	proxy.set_meta("entity_id", entity_id)
	proxy.global_position = _static_get_entity_position(entity_id)
	return proxy

static func _static_is_channel_complete(channel_data: Dictionary) -> bool:
	return channel_data.duration_remaining <= 0

static func _static_cleanup_channel_visuals(channel_data: Dictionary):
	var beam = channel_data.get("beam")
	if beam and is_instance_valid(beam):
		beam.queue_free()

static func _static_cleanup_channel_audio(channel_data: Dictionary):
	var audio = channel_data.get("audio")
	if audio and is_instance_valid(audio):
		audio.stop()
		audio.queue_free()

static func _static_cleanup_channel_timer(channel_data: Dictionary):
	var timer = channel_data.get("timer")
	if timer and is_instance_valid(timer):
		timer.stop()
		timer.queue_free()

# Casting flag management
static func _static_is_entity_casting(entity_id: int) -> bool:
	if EnemyManager.instance and entity_id >= 0 and entity_id < EnemyManager.instance.ability_casting_flags.size():
		return EnemyManager.instance.ability_casting_flags[entity_id] != 0
	return false

static func _static_set_entity_casting(entity_id: int, casting: bool):
	if EnemyManager.instance and entity_id >= 0 and entity_id < EnemyManager.instance.ability_casting_flags.size():
		EnemyManager.instance.ability_casting_flags[entity_id] = 1 if casting else 0