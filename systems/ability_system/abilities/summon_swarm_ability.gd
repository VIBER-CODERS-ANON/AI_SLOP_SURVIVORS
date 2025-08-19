class_name SummonSwarmAbility
extends BaseAbility

## Summon Swarm - Forsen's channeled ability that interacts with chat
## During the channel, Forsen emotes in chat have a chance to summon Ugandan Warriors

# Ability properties
@export var channel_duration: float = 10.0
@export var summon_chance: float = 0.3  # 30% chance per emote
@export var warrior_scene_path: String = "res://entities/enemies/special/ugandan_warrior/ugandan_warrior.tscn"
@export var max_warriors_per_user: int = 1

# Visual/Audio
@export var channel_effect_color: Color = Color(1.5, 0.5, 0.5)
@export var summon_effect_color: Color = Color(0.5, 0, 0.5)  # Purple

# State
var is_channeling: bool = false
var channel_time: float = 0.0
var users_summoned: Dictionary = {}  # Track which users have summoned this channel
var warrior_scene: PackedScene
var channel_tween: Tween

# Forsen emotes to detect
const FORSEN_EMOTES = ["forsen", "forsene", "forsenE", "OMEGALUL", "LULW", "ZULUL", "Pepega"]

func _init() -> void:
	# Set base properties
	ability_id = "summon_swarm"
	ability_name = "Summon Swarm"
	ability_description = "Channel for 10 seconds. Chat members typing Forsen emotes have 30% chance to summon warriors"
	ability_tags = ["Summon", "Channeled", "ChatInteraction"]
	ability_type = 0  # ACTIVE
	
	# Cooldown
	base_cooldown = 25.0
	
	# No resource cost
	resource_costs = {}
	
	# Self-targeted
	targeting_type = 0  # SELF
	base_range = 0.0

func on_added(holder) -> void:
	super.on_added(holder)
	
	# Preload warrior scene
	if warrior_scene_path != "":
		warrior_scene = load(warrior_scene_path)
	
	# Summon Swarm ability added

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# Cannot use while already channeling
	if is_channeling:
		return false
	
	var entity = _get_entity(holder)
	if not entity:
		return false
	
	# Check if entity is alive
	if entity.has_method("is_alive") and not entity.is_alive:
		return false
	
	return true

func _execute_ability(holder, target_data) -> void:
	var entity = _get_entity(holder)
	if not entity:
		return
	
	# Start channeling
	is_channeling = true
	channel_time = 0.0
	users_summoned.clear()
	
	# Report to action feed
	_report_channel_start(entity)
	
	# Play Forsen's "crashing this plane" dialog if this is Forsen
	if entity.name == "ForsenBoss" or entity.has_method("is_forsen_boss"):
		_play_forsen_crash_dialog(entity)
	
	# Play animation
	_play_animation(holder, "channel")
	
	# Create visual effect
	_create_channel_visual(entity)
	
	# Disable entity movement
	if entity.has_method("set_can_move"):
		entity.set_can_move(false)
	
	# Connect to chat system
	_connect_chat_listener(entity)
	
	# Start cooldown immediately
	_start_cooldown(holder)
	
	# Notify systems
	holder.on_ability_executed(self)
	executed.emit(target_data)

func update(delta: float, holder) -> void:
	super.update(delta, holder)
	
	if is_channeling:
		channel_time += delta
		
		# Check if channel is complete
		if channel_time >= channel_duration:
			_complete_channel(holder)

func _complete_channel(holder) -> void:
	is_channeling = false
	
	var entity = _get_entity(holder)
	if entity:
		# Re-enable movement
		if entity.has_method("set_can_move"):
			entity.set_can_move(true)
		
		# Disconnect chat listener
		_disconnect_chat_listener(entity)
		
		# Remove visual effect
		_remove_channel_visual(entity)
		
		# Report completion
		_report_channel_end(entity)

func _interrupt_channel(holder) -> void:
	if not is_channeling:
		return
	
	is_channeling = false
	channel_time = 0.0
	
	_complete_channel(holder)
	
	var entity = _get_entity(holder)
	if entity:
		var action_feed = _get_action_feed()
		if action_feed:
			action_feed.add_message("❌ %s's Summon Swarm was interrupted!" % entity.name, Color(1, 0.5, 0))

# Visual effects
func _create_channel_visual(entity) -> void:
	if not entity or not entity.has_node("Sprite") and not entity.has_node("AnimatedSprite2D"):
		return
	
	var sprite_node = entity.get_node_or_null("Sprite")
	if not sprite_node:
		sprite_node = entity.get_node_or_null("AnimatedSprite2D")
	
	if sprite_node:
		# Create pulsing effect
		channel_tween = entity.create_tween()
		channel_tween.set_loops(-1)
		
		channel_tween.tween_property(sprite_node, "modulate", channel_effect_color, 0.5)
		channel_tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.5)

func _remove_channel_visual(entity) -> void:
	if channel_tween and channel_tween.is_valid():
		channel_tween.kill()
		channel_tween = null
	
	# Reset sprite color
	if entity:
		var sprite_node = entity.get_node_or_null("Sprite")
		if not sprite_node:
			sprite_node = entity.get_node_or_null("AnimatedSprite2D")
		if sprite_node:
			sprite_node.modulate = Color.WHITE

# Chat integration
func _connect_chat_listener(entity) -> void:
	var game_controller = entity.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_signal("chat_message_received"):
		if not game_controller.is_connected("chat_message_received", _on_chat_message):
			game_controller.chat_message_received.connect(_on_chat_message.bind(entity))

func _disconnect_chat_listener(entity) -> void:
	var game_controller = entity.get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.has_signal("chat_message_received"):
		if game_controller.is_connected("chat_message_received", _on_chat_message):
			game_controller.chat_message_received.disconnect(_on_chat_message)

func _on_chat_message(username: String, message: String, _user_color: Color, entity: Node) -> void:
	if not is_channeling or not entity:
		return
	
	# Check if message contains forsen emotes
	var has_forsen_emote = false
	for emote in FORSEN_EMOTES:
		if emote.to_lower() in message.to_lower():
			has_forsen_emote = true
			break
	
	if not has_forsen_emote:
		return
	
	# Check if user already summoned
	if username in users_summoned and users_summoned[username] >= max_warriors_per_user:
		return
	
	# Roll for summon chance
	if randf() < summon_chance:
		_summon_warrior(entity, username)
		
		# Track summon
		if not username in users_summoned:
			users_summoned[username] = 0
		users_summoned[username] += 1

func _summon_warrior(entity: Node, summoner_name: String) -> void:
	if not warrior_scene or not entity:
		return
	
	var warrior = warrior_scene.instantiate()
	
	# Set warrior properties
	if warrior.has_property("chatter_username"):
		warrior.chatter_username = summoner_name + "'s Warrior"
	
	# Position around entity
	var angle = randf() * TAU
	var distance = randf_range(100, 200)
	var offset = Vector2(cos(angle), sin(angle)) * distance
	
	warrior.global_position = entity.global_position + offset
	entity.get_parent().add_child(warrior)
	
	# Create spawn effect
	_create_summon_effect(warrior.global_position, entity)

func _create_summon_effect(pos: Vector2, entity: Node) -> void:
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
	particles.color = summon_effect_color
	
	particles.global_position = pos
	entity.get_tree().current_scene.add_child(particles)
	
	# Auto cleanup
	particles.emitting = true
	await particles.finished
	particles.queue_free()

# Reporting functions
func _report_channel_start(entity) -> void:
	var action_feed = _get_action_feed()
	if action_feed and entity.has_property("boss_name"):
		action_feed.add_message("🔴 %s is channeling SUMMON SWARM! Type Forsen emotes to summon warriors!" % entity.boss_name, Color(1, 0.5, 0))

func _report_channel_end(entity) -> void:
	var action_feed = _get_action_feed()
	if action_feed and entity.has_property("boss_name"):
		var warrior_count = 0
		for count in users_summoned.values():
			warrior_count += count
		action_feed.add_message("✅ %s's Summon Swarm ended! %d warriors summoned!" % [entity.boss_name, warrior_count], Color(0.2, 1, 0.2))

func _get_action_feed():
	var game = _get_entity(holder).get_tree().get_first_node_in_group("game_controller")
	if game and game.has_method("get_action_feed"):
		return game.get_action_feed()
	return null

func _play_forsen_crash_dialog(entity) -> void:
	# Array of crash dialog files
	var crash_dialogs = [
		"res://BespokeAssetSources/character_dialog_sfx/forsen/10lines/crash this plane with no survivors.mp3",
		"res://BespokeAssetSources/character_dialog_sfx/forsen/10lines/crashing this plane with no survivors1.mp3",
		"res://BespokeAssetSources/character_dialog_sfx/forsen/10lines/crashing this plane with no survivors2.mp3",
		"res://BespokeAssetSources/character_dialog_sfx/forsen/10lines/crashing this plane with no survivors3.mp3"
	]
	
	# Pick a random dialog
	var dialog_path = crash_dialogs[randi() % crash_dialogs.size()]
	
	# Load and play the audio
	if ResourceLoader.exists(dialog_path):
		var audio_stream = load(dialog_path)
		if AudioManager.instance:
			AudioManager.instance.play_sfx_on_node(audio_stream, entity, 0.0, 1.0)
		else:
			# Fallback: Create audio player directly
			var player = AudioStreamPlayer2D.new()
			entity.add_child(player)
			player.stream = audio_stream
			player.volume_db = 0.0
			player.play()
			
			# Clean up when done
			player.finished.connect(player.queue_free)
	
	# Also show in action feed
	var action_feed = _get_action_feed()
	if action_feed:
		action_feed.add_message("✈️ Forsen: \"Crashing this plane with no survivors!\"", Color(0.8, 0.2, 0.2))

# Override cleanup
func on_removed(holder) -> void:
	# Make sure to end channel if ability is removed
	if is_channeling:
		_interrupt_channel(holder)
	
	super.on_removed(holder)
