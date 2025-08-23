class_name SuctionAbilityV2
extends BaseAbility

## Simplified Suction ability for V2 enemies
## Drains health from target over time

@export var damage_per_second: float = 6.25  # 18.75 total over 3 seconds
@export var channel_duration: float = 3.0
@export var suction_range: float = 200.0
@export var break_range: float = 240.0  # 20% further than cast range

# Channel state
var is_channeling: bool = false
var channel_target: Node = null
var channel_time_remaining: float = 0.0
var beam_visual: Line2D = null
var audio_player: AudioStreamPlayer2D = null
var damage_tick_timer: float = 0.0
var damage_tick_interval: float = 0.1  # Apply damage every 0.1 seconds, not every frame

signal channel_started(target: Node)
signal channel_ended()

func _init() -> void:
	ability_id = "suction_v2"
	ability_name = "Life Drain"
	ability_type = 0  # ACTIVE
	ability_tags = ["Channel", "Magic", "DoT"]
	base_cooldown = 30.0  # Not used by V2 system
	base_range = suction_range
	targeting_type = 1  # TARGET_ENEMY

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# Already channeling?
	if is_channeling:
		return false
	
	# Valid target?
	if not target_data or not target_data.has("target_enemy"):
		return false
	
	var target = target_data.target_enemy
	if not is_instance_valid(target):
		return false
	
	# In range?
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	
	if entity:
		var distance = entity.global_position.distance_to(target.global_position)
		if distance > suction_range:
			return false
	
	return true

func _execute_ability(holder, target_data) -> void:
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if not entity:
		return
	
	var target = target_data.target_enemy
	if not is_instance_valid(target):
		return
	
	# Start channeling
	is_channeling = true
	channel_target = target
	channel_time_remaining = channel_duration
	
	# Create beam visual
	if entity:
		beam_visual = Line2D.new()
		beam_visual.width = 15.0
		beam_visual.default_color = Color(1.0, 0.2, 0.5, 0.7)
		beam_visual.add_point(Vector2.ZERO)
		beam_visual.add_point(entity.to_local(target.global_position))
		entity.add_child(beam_visual)
	
	# Create and start audio
	if entity:
		audio_player = AudioStreamPlayer2D.new()
		var stream = load("res://BespokeAssetSources/Succubus/succAudioLoop.mp3")
		if stream:
			audio_player.stream = stream
			audio_player.bus = "SFX"
			audio_player.volume_db = -10.0
			entity.add_child(audio_player)
			audio_player.play()
	
	# Stop entity movement (for V2 proxy)
	if holder.has_method("_stop_movement"):
		holder._stop_movement()
	
	print("💜 Suction started on %s" % target.name)
	channel_started.emit(target)
	executed.emit(target_data)

func update(delta: float, holder) -> void:
	super.update(delta, holder)
	
	if not is_channeling:
		return
	
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	
	# Check target still valid
	if not channel_target or not is_instance_valid(channel_target):
		_end_channel(holder)
		return
	
	# Check break range
	if entity:
		var distance = entity.global_position.distance_to(channel_target.global_position)
		if distance > break_range:
			print("💔 Suction broken - target out of range")
			_end_channel(holder)
			return
	
	# Update beam visual
	if beam_visual and is_instance_valid(beam_visual) and entity:
		beam_visual.points[1] = beam_visual.to_local(channel_target.global_position)
	
	# Apply damage at intervals, not every frame
	damage_tick_timer += delta
	if damage_tick_timer >= damage_tick_interval:
		var damage = damage_per_second * damage_tick_interval
		if channel_target.has_method("take_damage"):
			channel_target.take_damage(damage, entity, ["Magic", "DoT"])
		damage_tick_timer = 0.0
	
	# Update timer
	channel_time_remaining -= delta
	if channel_time_remaining <= 0:
		print("✅ Suction completed")
		_end_channel(holder)

func _end_channel(holder = null) -> void:
	if not is_channeling:
		return
	
	is_channeling = false
	channel_target = null
	channel_time_remaining = 0.0
	damage_tick_timer = 0.0
	
	# Clean up visuals
	if beam_visual and is_instance_valid(beam_visual):
		beam_visual.queue_free()
		beam_visual = null
	
	# Stop audio
	if audio_player and is_instance_valid(audio_player):
		audio_player.stop()
		audio_player.queue_free()
		audio_player = null
	
	# Restore movement (for V2 proxy)
	if holder and holder.has_method("_restore_movement"):
		holder._restore_movement()
	
	channel_ended.emit()

func on_removed(holder) -> void:
	_end_channel(holder)
	super.on_removed(holder)