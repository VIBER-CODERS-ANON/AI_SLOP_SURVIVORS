extends BaseBoss
class_name ForsenBoss

## Forsen - The Meme Lord
## A melee boss with chat interaction abilities
## Transforms into HORSEN at 20% HP

signal forsen_summon_swarm_started()
signal forsen_summon_swarm_ended()
signal forsen_transform_horsen()
signal forsen_spawn_horses()

@export_group("Forsen Specific")
@export var summon_swarm_enabled: bool = true
@export var summon_swarm_cooldown: float = 25.0
@export var summon_swarm_duration: float = 10.0
@export var transform_threshold: float = 0.2  # Transform at 20% health
@export var horse_spawn_count: int = 5
@export var periodic_horse_charge_enabled: bool = true
@export var horse_charge_cooldown: float = 15.0  # Spawn horses every 15 seconds
@export var horses_per_charge: int = 5  # Spawn 5 horses that charge once then despawn

# Forsen state
var summon_swarm_timer: float = 0.0
var is_channeling_swarm: bool = false
var swarm_channel_time: float = 0.0
var has_transformed: bool = false
var horse_charge_timer: float = 0.0  # Timer for periodic horse charges
var ugandan_warrior_scene: PackedScene
var horse_scene: PackedScene

# Chat interaction tracking
var chat_users_summoned: Dictionary = {}  # Track which users have summoned this swarm

# Visual states
var original_sprite_texture: Texture2D
var horsen_sprite_texture: Texture2D

func _ready():
	# Set Forsen specific properties
	boss_name = "Forsen"
	boss_title = "The Meme Lord"
	boss_health = 700.0
	boss_damage = 20.0
	boss_move_speed = 100.0
	boss_attack_range = 60.0  # Melee range
	boss_attack_cooldown = 1.5
	boss_scale = 1.2
	custom_modulate = Color(1.0, 1.0, 1.0)
	
	# Set attack type
	attack_type = AttackType.MELEE
	
	# Enable phases for transformation
	phases_enabled = false  # We'll handle transformation manually
	
	# Load resources
	_load_forsen_resources()
	
	# Call parent ready
	super._ready()
	
	# Fix sprite reference - ForsenBoss uses AnimatedSprite2D not Sprite
	sprite = get_node_or_null("AnimatedSprite2D")
	if sprite and sprite_texture:
		# Apply the texture to the AnimatedSprite2D
		var frames = SpriteFrames.new()
		if not frames.has_animation("default"):
			frames.add_animation("default")
		frames.clear("default")  # Clear any existing frames
		frames.add_frame("default", sprite_texture)
		sprite.sprite_frames = frames
		sprite.play("default")
	
	# Add Forsen-specific tags
	if taggable:
		taggable.add_tag("Forsen")
		taggable.add_tag("Melee")
		taggable.add_tag("Unique")
	
	# Start boss buff
	_activate_boss_buff()

func _load_forsen_resources():
	# Preload all resources up front to avoid runtime driver hiccups
	sprite_texture = preload("res://BespokeAssetSources/forsen/forsen.png")
	original_sprite_texture = sprite_texture
	horsen_sprite_texture = preload("res://BespokeAssetSources/forsen/horsen.png")
	ugandan_warrior_scene = preload("res://entities/enemies/special/ugandan_warrior/ugandan_warrior.tscn")
	horse_scene = preload("res://entities/enemies/special/horse_enemy/horse_enemy.tscn")

func _announce_spawn():
	# Play Forsen spawn VO if available
	_play_forsen_vo("spawn")

func _entity_physics_process(delta: float):
	# Stop movement during channeling
	if is_channeling_swarm:
		movement_velocity = Vector2.ZERO
	
	super._entity_physics_process(delta)
	
	# Update ability timers
	if summon_swarm_timer > 0:
		summon_swarm_timer -= delta
	
	if horse_charge_timer > 0:
		horse_charge_timer -= delta
	
	# Handle swarm channeling
	if is_channeling_swarm:
		swarm_channel_time += delta
		if swarm_channel_time >= summon_swarm_duration:
			_end_summon_swarm()
		return  # Skip other abilities while channeling
	
	# Check for transformation
	if not has_transformed and current_health / max_health <= transform_threshold:
		_transform_to_horsen()
	
	# Check for abilities
	if not is_channeling_swarm and not has_transformed:
		_check_abilities()

func _check_abilities():
	var player = _find_player()
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Periodic horse charge check (prioritize this over swarm)
	if periodic_horse_charge_enabled and horse_charge_timer <= 0:
		if distance_to_player < 600:  # Longer range for horse charges
			_spawn_periodic_horses()
			return  # Don't use other abilities this frame
	
	# Summon swarm check
	if summon_swarm_enabled and summon_swarm_timer <= 0:
		if distance_to_player < 400:  # Only summon when player is somewhat close
			_start_summon_swarm()

func _start_summon_swarm():
	summon_swarm_timer = summon_swarm_cooldown
	is_channeling_swarm = true
	swarm_channel_time = 0.0
	chat_users_summoned.clear()
	
	forsen_summon_swarm_started.emit()
	
	# Visual feedback - start glowing
	_create_channel_effect()
	
	# Disable movement during channel
	move_speed = 0
	
	# Connect to chat system
	_connect_chat_listener()
	
	# Announce with voice
	_play_forsen_vo("summon_swarm")
	
	# Action feed announcement
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message("🔴 %s is channeling SUMMON SWARM! Type Forsen emotes to summon warriors!" % boss_name, Color(1, 0.5, 0))

func _end_summon_swarm():
	is_channeling_swarm = false
	move_speed = boss_move_speed  # Restore movement
	chat_users_summoned.clear()
	
	forsen_summon_swarm_ended.emit()
	
	# Disconnect chat listener
	_disconnect_chat_listener()
	
	# Remove visual effect
	_remove_channel_effect()
	
	speak_dialogue("The swarm has answered!")

func _create_channel_effect():
	# Create super saiyan-like effect
	if sprite:
		# Store original scale
		set_meta("original_scale", sprite.scale)
		
		# Make Forsen grow larger
		var size_tween = create_tween()
		size_tween.tween_property(sprite, "scale", sprite.scale * 1.5, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
		# Create pulsing glow effect
		var glow_tween = create_tween()
		glow_tween.set_loops(-1)
		set_meta("channel_tween", glow_tween)
		
		# Kill tweens when channel ends
		tree_exiting.connect(func(): 
			if glow_tween and glow_tween.is_valid():
				glow_tween.kill()
			if size_tween and size_tween.is_valid():
				size_tween.kill()
		)
		
		# Intense golden-red pulsing like super saiyan
		glow_tween.tween_property(sprite, "modulate", Color(2.0, 1.5, 0.5), 0.3)  # Golden glow
		glow_tween.tween_property(sprite, "modulate", Color(1.5, 0.8, 0.8), 0.3)  # Red tint
	
	# Create energy particles around Forsen
	_create_channel_particles()
	
	# Screen shake for dramatic effect
	if GameController.instance and GameController.instance.has_method("shake_camera"):
		GameController.instance.shake_camera(0.3, summon_swarm_duration)

func _create_channel_particles():
	# Create energy particles swirling around Forsen (super saiyan aura)
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 100
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 50.0
	particles.spread = 45.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.angular_velocity_min = -360.0
	particles.angular_velocity_max = 360.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 2.0
	particles.color = Color(1.0, 0.8, 0.2, 1)  # Golden energy
	particles.z_index = 100
	
	# Create gradient for fade out
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 1, 1, 1))
	gradient.add_point(0.5, Color(1, 0.8, 0.2, 1))
	gradient.add_point(1.0, Color(1, 0.2, 0.2, 0))
	particles.color_ramp = gradient
	
	add_child(particles)
	set_meta("channel_particles", particles)

func _remove_channel_effect():
	if has_meta("channel_tween"):
		var tween = get_meta("channel_tween")
		if tween and tween.is_valid():
			tween.kill()
		remove_meta("channel_tween")
	
	# Restore original scale with animation
	if sprite and has_meta("original_scale"):
		var shrink_tween = create_tween()
		shrink_tween.tween_property(sprite, "scale", get_meta("original_scale"), 0.3)
		remove_meta("original_scale")
	
	if sprite:
		sprite.modulate = custom_modulate
	
	# Clean up particles
	if has_meta("channel_particles"):
		var particles = get_meta("channel_particles")
		if particles and is_instance_valid(particles):
			particles.emitting = false
			particles.queue_free()
		remove_meta("channel_particles")

func _transform_to_horsen():
	has_transformed = true
	forsen_transform_horsen.emit()
	
	# Update stats for HORSEN form
	boss_name = "HORSEN"
	boss_title = "The Quadruped Terror"
	max_health = 200.0
	current_health = 200.0
	damage = 10.0
	move_speed = 200.0  # Unmatched speed
	
	# Update sprite
	if sprite and horsen_sprite_texture:
		if sprite is AnimatedSprite2D:
			# Replace frames with HORSEN static frame
			var frames = SpriteFrames.new()
			if not frames.has_animation("default"):
				frames.add_animation("default")
			frames.clear("default")  # Clear any existing frames
			frames.add_frame("default", horsen_sprite_texture)
			sprite.sprite_frames = frames
			sprite.play("default")
		else:
			# Fallback for Sprite2D if used
			sprite.texture = horsen_sprite_texture
		sprite.scale *= 1.5  # Make HORSEN bigger
	
	# Update tags
	if taggable:
		taggable.add_tag("HORSEN")
		taggable.add_tag("Transformed")
	
	# Announce transformation with voice
	_play_forsen_vo("transform")
	
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message("⚠️ %s has transformed into HORSEN! HP: %d" % [boss_name, int(max_health)], Color(1, 0.2, 0.2))
	
	# Spawn horses
	_spawn_horses()
	
	# Generate horse noises
	_play_horse_sounds()

func _spawn_periodic_horses():
	horse_charge_timer = horse_charge_cooldown
	
	_play_forsen_vo("charge")
	
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message("🐴 %s summons charging horses!" % boss_name, Color(0.8, 0.4, 0))
	
	var player = _find_player()
	if not player or not horse_scene:
		return
	
	# Spawn fewer horses for periodic charges
	for i in range(horses_per_charge):
		var horse = horse_scene.instantiate()
		
		# Position horses to the sides of the screen
		var side = (i % 2) * 2 - 1  # -1 or 1
		var offset_x = side * randf_range(400, 600)
		var offset_y = randf_range(-100, 100)
		
		horse.global_position = player.global_position + Vector2(offset_x, offset_y)
		horse.set_charge_target(player)
		
		get_parent().add_child(horse)

func _spawn_horses():
	forsen_spawn_horses.emit()
	
	var player = _find_player()
	if not player or not horse_scene:
		return
	
	for i in range(horse_spawn_count):
		var horse = horse_scene.instantiate()
		
		# Position horses to the sides of the screen
		var side = (i % 2) * 2 - 1  # -1 or 1
		var offset_x = side * randf_range(300, 500)
		var offset_y = randf_range(-200, 200)
		
		horse.global_position = player.global_position + Vector2(offset_x, offset_y)
		horse.set_charge_target(player)
		
		get_parent().add_child(horse)

func _play_horse_sounds():
	# Play a random horse SFX from res://audio/horses
	var files = _list_audio_files_in("res://audio/horses")
	if files.is_empty():
		return
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = load(files[randi() % files.size()])
	player.volume_db = -3.0
	player.play()

func _on_boss_damaged(_amount: float, _source: Node):
	if has_transformed:
		# HORSEN reactions
		var horse_lines = [
			"NEIGH!",
			"*horse noises*",
			"GALLOPING INTENSIFIES!",
			"YOU CAN'T STOP THE HORSE!"
		]
		if randf() < 0.2:  # 20% chance
			speak_dialogue(horse_lines[randi() % horse_lines.size()])
	else:
		# Regular Forsen reactions
		if randf() < 0.15:  # 15% chance
			_play_forsen_vo("hit")

# Chat system integration
func _connect_chat_listener():
	# Connect to game controller's chat system
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_signal("chat_message_received"):
		if not game_controller.is_connected("chat_message_received", _on_chat_message):
			game_controller.chat_message_received.connect(_on_chat_message)

func _disconnect_chat_listener():
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_signal("chat_message_received"):
		if game_controller.is_connected("chat_message_received", _on_chat_message):
			game_controller.chat_message_received.disconnect(_on_chat_message)

func _on_chat_message(username: String, message: String, _user_color: Color):
	if not is_channeling_swarm:
		return
	
	# Check if message contains forsen-related emotes
	var forsen_emotes = ["forsen", "forsene", "forsenE", "OMEGALUL", "LULW", "ZULUL", "Pepega"]
	var has_forsen_emote = false
	
	for emote in forsen_emotes:
		if emote.to_lower() in message.to_lower():
			has_forsen_emote = true
			break
	
	if has_forsen_emote:
		# Check if this user already summoned this swarm
		if username in chat_users_summoned:
			return
		
		# 30% chance to summon warrior
		if randf() < 0.3:
			_summon_ugandan_warrior(username)
			chat_users_summoned[username] = true

func _summon_ugandan_warrior(summoner_name: String):
	if not ugandan_warrior_scene:
		return
	
	var warrior = ugandan_warrior_scene.instantiate()
	warrior.chatter_username = summoner_name + "'s Warrior"
	
	# Position around Forsen
	var angle = randf() * TAU
	var distance = randf_range(100, 200)
	var offset = Vector2(cos(angle), sin(angle)) * distance
	
	warrior.global_position = global_position + offset
	get_parent().add_child(warrior)
	
	# Visual spawn effect
	_create_summon_effect(warrior.global_position)

func _create_summon_effect(pos: Vector2):
	# Purple summoning effect for uganda warriors
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.5
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0
	particles.spread = 45.0
	particles.initial_velocity_min = 50.0
	particles.initial_velocity_max = 100.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = Color(0.5, 0, 0.5, 1)  # Purple for uganda
	
	particles.global_position = pos
	get_tree().current_scene.add_child(particles)

# Boss Buff System
func _activate_boss_buff():
	# Apply Forsen buff to all current and future chatter entities
	var buff_message = "🎮 FORSEN BUFF ACTIVE: All chatters have 1% chance to summon warriors on Forsen emotes!"
	
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message(buff_message, Color(0.8, 0.2, 0.8))
	
	# Apply to existing chatters
	var chatters = get_tree().get_nodes_in_group("twitch_mob")
	for chatter in chatters:
		_apply_forsen_buff(chatter)
	
	# Connect to spawn system for future chatters
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_signal("chatter_spawned"):
		game_controller.chatter_spawned.connect(_on_chatter_spawned)

func _on_chatter_spawned(chatter: Node):
	_apply_forsen_buff(chatter)

func _apply_forsen_buff(chatter: Node):
	# Add metadata to track buff
	chatter.set_meta("has_forsen_buff", true)
	
	# Visual indicator (slight purple tint)
	if chatter.has_node("Sprite") or chatter.has_node("AnimatedSprite2D"):
		var sprite_node = chatter.get_node_or_null("Sprite")
		if not sprite_node:
			sprite_node = chatter.get_node_or_null("AnimatedSprite2D")
		if sprite_node:
			sprite_node.modulate = Color(1.1, 1.0, 1.1)  # Slight purple

# Audio helpers
func _play_forsen_vo(event: String):
	# Maps events to files in BespokeAssetSources/character_dialog_sfx/forsen
	var base := "res://BespokeAssetSources/character_dialog_sfx/forsen"
	var candidates: Array = []
	match event:
		"spawn":
			candidates = _list_audio_files_in(base + "/spawn")
		"summon_swarm":
			candidates = _list_audio_files_in(base + "/summon_swarm")
		"transform":
			candidates = _list_audio_files_in(base + "/transform")
		"charge":
			candidates = _list_audio_files_in(base + "/charge")
		"hit":
			candidates = _list_audio_files_in(base + "/hit")
		"death":
			candidates = _list_audio_files_in(base + "/death")
		_:
			candidates = _list_audio_files_in(base)
	
	if candidates.is_empty():
		return

	var p := AudioStreamPlayer2D.new()
	add_child(p)
	p.stream = load(candidates[randi() % candidates.size()])
	# Louder VO (roughly double perceived loudness)
	p.volume_db = 6.0
	p.play()

func _list_audio_files_in(dir_path: String) -> Array:
	var files: Array = []
	var dir := DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var lower := file_name.to_lower()
				if lower.ends_with(".mp3") or lower.ends_with(".ogg") or lower.ends_with(".wav"):
					files.append(dir_path + "/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files

func get_killer_display_name() -> String:
	if has_transformed:
		return "HORSEN"
	return boss_name

func get_attack_name() -> String:
	if has_transformed:
		return "horse charge"
	return "meme punch"

func die():
	# Play death VO from parent so it persists after this node frees
	var death_files = _list_audio_files_in("res://BespokeAssetSources/character_dialog_sfx/forsen/death")
	if not death_files.is_empty():
		var p := AudioStreamPlayer2D.new()
		if get_parent():
			get_parent().add_child(p)
		else:
			add_child(p)
		p.stream = load(death_files[randi() % death_files.size()])
		# Louder VO on death as well
		p.volume_db = 6.0
		p.play()
	# Now perform normal death
	super.die()
