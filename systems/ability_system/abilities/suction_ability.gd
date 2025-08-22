class_name SuctionAbility
extends BaseAbility

## Suction (Succ) ability - channeled beam that drains health from target
## Used by Succubus enemies

# Succ properties
@export var damage_total: float = 18.75  # Total damage over duration (nerfed by 0.5)
@export var channel_duration: float = 3.0
@export var succ_range: float = 200.0
@export var break_distance_multiplier: float = 1.2  # Channel breaks at range * multiplier

# Audio
@export var succ_audio_path: String = "res://BespokeAssetSources/Succubus/succAudioLoop.mp3"

# Visual
@export var beam_color: Color = Color(1.0, 0.2, 0.5, 0.7)
@export var beam_width: float = 20.0

# Channel state
var is_channeling: bool = false
var channel_target: Node = null
var channel_time_remaining: float = 0.0
var damage_accumulator: float = 0.0
var succ_beam: Line2D = null
var succ_audio_player: AudioStreamPlayer2D = null

# Damage delay
var damage_delay: float = 0.8  # 800ms delay before damage starts
var damage_delay_remaining: float = 0.0
var damage_started: bool = false

# Animation state
var sprite_animation_tween: Tween = null
var beam_pulse_tween: Tween = null
var channeling_entity: Node = null  # Store entity reference for cleanup

# Movement state (to make entity stand still during channel)
var stored_velocity: Vector2 = Vector2.ZERO
var stored_movement_velocity: Vector2 = Vector2.ZERO

signal succ_started(target: Node)
signal succ_ended()
signal request_move_to_target(target: Node, desired_range: float)

func _init() -> void:
	# Set base properties
	ability_id = "suction"
	ability_name = "Suction"
	ability_description = "Channels a life-draining beam at the target"
	ability_tags = ["Channel", "Magic", "DoT", "Succ"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = 30.0  # 30 second cooldown per entity
	resource_costs = {}  # No resource cost
	
	# Targeting - requires target enemy
	targeting_type = 1  # TARGET_ENEMY
	base_range = succ_range

func on_added(holder) -> void:
	super.on_added(holder)
	
	# Create audio player for looping sound
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if entity:
		succ_audio_player = AudioStreamPlayer2D.new()
		succ_audio_player.name = "SuccAudioPlayer"
		if succ_audio_path != "":
			succ_audio_player.stream = load(succ_audio_path)
		succ_audio_player.bus = "SFX"
		succ_audio_player.volume_db = -5.0
		entity.add_child(succ_audio_player)
	
	# SuctionAbility added

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# Cannot start new channel while channeling
	if is_channeling:
		return false
	
	# Need a valid target
	if not target_data or not target_data.has("target_enemy"):
		return false
	
	var target = target_data.target_enemy
	if not is_instance_valid(target):
		return false
	
	# Don't check range here - we'll move into range if needed
	# Range check moved to the actual execution
	
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
	
	# Check if we're in range
	var distance = entity.global_position.distance_to(target.global_position)
	if distance > succ_range:
		# Request move to range
		# The entity's AI should handle this and re-attempt the ability when in range
		request_move_to_target.emit(target, succ_range * 0.9)  # Move to 90% of max range
		# DO NOT start cooldown here - only start after successfully beginning channel
		return
	
	# Start channeling
	is_channeling = true
	channel_target = target
	channel_time_remaining = channel_duration
	damage_accumulator = 0.0
	damage_delay_remaining = damage_delay
	damage_started = false
	channeling_entity = entity  # Store entity reference for cleanup
	
	# Stop entity movement during channel
	if "velocity" in entity:
		stored_velocity = entity.velocity
		entity.velocity = Vector2.ZERO
	if "movement_velocity" in entity:
		stored_movement_velocity = entity.movement_velocity
		entity.movement_velocity = Vector2.ZERO
	
	# Succubus started SUCC (800ms before damage)
	
	# Create visual beam
	_create_succ_beam(entity)
	
	# Start suction animations
	_start_suction_animation(entity)
	
	# Don't play audio immediately - wait for first frame of channeling
	# Audio will start in _update_channel after validation
	
	# Start cooldown immediately (prevents re-casting)
	_start_cooldown(holder)
	
	# Notify holder
	holder.on_ability_executed(self)
	executed.emit(target_data)
	succ_started.emit(target)

func update(delta: float, holder) -> void:
	super.update(delta, holder)
	
	# Update channel if active
	if is_channeling:
		_update_channel(delta, holder)

func _update_channel(delta: float, holder) -> void:
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if not entity:
		_end_channel()
		return
	
	# Keep entity still during channel
	if "velocity" in entity:
		entity.velocity = Vector2.ZERO
	if "movement_velocity" in entity:
		entity.movement_velocity = Vector2.ZERO
	
	# Check if target is still valid
	if not channel_target or not is_instance_valid(channel_target):
		_end_channel()
		return
	
	# Start audio on first valid frame of channeling (not in _execute_ability)
	if succ_audio_player and not succ_audio_player.playing and succ_audio_player.stream:
		# Create a new stream instance to avoid modifying the original
		var audio_stream = succ_audio_player.stream.duplicate()
		audio_stream.loop = true
		succ_audio_player.stream = audio_stream
		succ_audio_player.play()
	
	# Check break distance
	var distance = entity.global_position.distance_to(channel_target.global_position)
	if distance > succ_range * break_distance_multiplier:
		# Succ broken - target escaped
		_end_channel()
		return
	
	# Update channel timer
	channel_time_remaining -= delta
	
	# Update damage delay timer
	if damage_delay_remaining > 0:
		damage_delay_remaining -= delta
		if damage_delay_remaining <= 0:
			damage_started = true
			# Succ damage started
			# Visual feedback when damage starts - make beam more intense
			if succ_beam:
				succ_beam.width = beam_width * 1.5
				succ_beam.default_color = Color(1.0, 0.1, 0.4, 0.9)  # More intense color
				
				# Update gradient to be more intense
				var gradient = Gradient.new()
				gradient.add_point(0.0, Color(1.0, 0.2, 0.5, 0.3))  # Stronger at succubus
				gradient.add_point(0.7, Color(1.0, 0.4, 0.6, 0.8))  # Stronger in middle
				gradient.add_point(1.0, Color(1.0, 0.1, 0.4, 1.0))  # Strongest at target
				succ_beam.gradient = gradient
	
	# Only apply damage after delay has passed
	if damage_started:
		# Calculate and apply damage
		var damage_per_second = get_modified_value(damage_total, "spell_power", holder) / channel_duration
		damage_accumulator += delta
		
		# Apply damage every 0.1 seconds
		if damage_accumulator >= 0.1:
			damage_accumulator -= 0.1
			var damage_to_apply = damage_per_second * 0.1
			
			if channel_target.has_method("take_damage"):
				# Pass entity as damage source (can't pass Resource)
				# Set metadata on entity temporarily for proper attribution
				entity.set_meta("active_ability_name", "life drain")
				entity.set_meta("active_ability", self)
				channel_target.take_damage(damage_to_apply, entity, ["Magic", "DoT", "Succ"])
				entity.remove_meta("active_ability_name")
				entity.remove_meta("active_ability")
	
	# Update beam visual
	if succ_beam and is_instance_valid(succ_beam):
		succ_beam.points[1] = succ_beam.to_local(channel_target.global_position)
	
	# Check if channel completed
	if channel_time_remaining <= 0:
		var _total_damage = get_modified_value(damage_total, "spell_power", holder)
		# Succ completed
		_end_channel()

func _create_succ_beam(entity: Node) -> void:
	succ_beam = Line2D.new()
	succ_beam.name = "SuccBeam"
	succ_beam.width = beam_width * 0.7  # Start thinner during warning phase
	succ_beam.default_color = Color(1.0, 0.4, 0.7, 0.5)  # Lighter pink during warning
	succ_beam.add_point(Vector2.ZERO)
	succ_beam.add_point(Vector2.ZERO)
	succ_beam.z_index = -1  # Draw behind entities
	entity.add_child(succ_beam)
	
	# Add gradient for suction effect - weaker during warning phase
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.4, 0.7, 0.2))  # Very weak at succubus
	gradient.add_point(0.7, Color(1.0, 0.5, 0.7, 0.4))  # Weak in middle
	gradient.add_point(1.0, Color(1.0, 0.3, 0.6, 0.6))  # Slightly stronger at target
	succ_beam.gradient = gradient
	
	# Start beam pulsing animation
	if entity:
		beam_pulse_tween = entity.create_tween()
		beam_pulse_tween.set_loops()
		beam_pulse_tween.tween_property(succ_beam, "width", beam_width * 1.5, 0.3)
		beam_pulse_tween.tween_property(succ_beam, "width", beam_width * 0.7, 0.3)

func _start_suction_animation(entity: Node) -> void:
	# Get sprite for animation
	var sprite = entity.get_node_or_null("Sprite")
	if sprite:
		# Create continuous suction animation - lean forward and pulse
		sprite_animation_tween = entity.create_tween()
		sprite_animation_tween.set_loops()
		sprite_animation_tween.set_parallel(true)
		
		# Lean forward slightly (scale X to look like leaning into suction)
		sprite_animation_tween.tween_property(sprite, "scale", Vector2(sprite.scale.x * 1.1, sprite.scale.y * 0.95), 0.4)
		sprite_animation_tween.tween_property(sprite, "scale", sprite.scale, 0.4)
		
		# Pulsing pink tint to show magical energy
		var succ_tint = Color(1.3, 0.7, 1.1)
		sprite_animation_tween.tween_property(sprite, "modulate", succ_tint, 0.5)
		sprite_animation_tween.tween_property(sprite, "modulate", Color.WHITE, 0.3)

func _end_channel() -> void:
	is_channeling = false
	channel_target = null
	damage_accumulator = 0.0
	damage_delay_remaining = 0.0
	damage_started = false
	
	# Restore entity movement (don't actually restore old velocity, just allow movement again)
	# We clear the stored values but don't apply them back
	stored_velocity = Vector2.ZERO
	stored_movement_velocity = Vector2.ZERO
	
	# Stop animations and reset sprite appearance
	if sprite_animation_tween:
		sprite_animation_tween.kill()
		sprite_animation_tween = null
	
	# Reset sprite to normal appearance immediately
	if channeling_entity and is_instance_valid(channeling_entity):
		var sprite = channeling_entity.get_node_or_null("Sprite")
		if sprite:
			# Force reset sprite to normal immediately
			sprite.modulate = Color.WHITE
			# Reset scale to normal (0.75 is the succubus normal scale from the scene)
			sprite.scale = Vector2(0.75, 0.75)
	
	channeling_entity = null  # Clear reference
	
	if beam_pulse_tween:
		beam_pulse_tween.kill()
		beam_pulse_tween = null
	
	# Remove beam visual
	if succ_beam and is_instance_valid(succ_beam):
		succ_beam.queue_free()
		succ_beam = null
	
	# Stop audio IMMEDIATELY and completely
	if succ_audio_player and is_instance_valid(succ_audio_player):
		# Force immediate stop - multiple redundant methods to ensure it stops
		succ_audio_player.stop()
		succ_audio_player.playing = false
		succ_audio_player.stream_paused = true
		# Clear the stream entirely
		var _old_stream = succ_audio_player.stream
		succ_audio_player.stream = null
		# Force process the stop (removed - was causing error)
		# Reload non-looping version for next time
		if succ_audio_path != "":
			var fresh_stream = load(succ_audio_path)
			if fresh_stream:
				fresh_stream.loop = false
				succ_audio_player.stream = fresh_stream
	
	# Emit signal
	succ_ended.emit()

func on_removed(holder) -> void:
	# Clean up channel if ability is removed while channeling
	if is_channeling:
		_end_channel()
	
	# Force stop audio and remove audio player
	if succ_audio_player:
		# Immediate forced stop
		succ_audio_player.stop()
		succ_audio_player.playing = false
		succ_audio_player.stream_paused = true
		succ_audio_player.stream = null  # Clear stream entirely
		if succ_audio_player.is_inside_tree():
			succ_audio_player.get_parent().remove_child(succ_audio_player)
		succ_audio_player.queue_free()
		succ_audio_player = null
	
	# Extra safety: reset sprite if we still have reference
	if channeling_entity and is_instance_valid(channeling_entity):
		var sprite = channeling_entity.get_node_or_null("Sprite")
		if sprite:
			sprite.modulate = Color.WHITE
			sprite.scale = Vector2(0.75, 0.75)
	
	channeling_entity = null
	
	super.on_removed(holder)

## Helper to create target data for this ability
static func create_target_data(enemy: Node) -> Dictionary:
	return {
		"target_enemy": enemy,
		"target_position": enemy.global_position if enemy else Vector2.ZERO
	}
