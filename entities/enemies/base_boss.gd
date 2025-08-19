extends BaseEnemy
class_name BaseBoss

## Base boss class for all major boss enemies
## Provides common boss functionality and can be extended for specific bosses

signal boss_spawned(boss_name: String)
signal boss_defeated(boss_name: String)
signal boss_phase_changed(phase: int)
signal boss_dialogue(text: String)

@export_group("Boss Settings")
@export var boss_name: String = "Boss"
@export var boss_title: String = "The Unknown"
@export var is_boss: bool = true
@export var shows_health_bar: bool = true
@export var phases_enabled: bool = false
@export var phase_thresholds: Array[float] = [0.75, 0.5, 0.25]  # Health percentages for phase changes

@export_group("Boss Stats")
@export var boss_health: float = 100.0
@export var boss_damage: float = 5.0
@export var boss_move_speed: float = 100.0
@export var boss_attack_range: float = 60.0
@export var boss_attack_cooldown: float = 2.0
@export var boss_scale: float = 1.5

@export_group("Boss Visuals")
@export var sprite_texture: Texture2D
@export var death_effect_scale: float = 2.0
@export var custom_modulate: Color = Color.WHITE

# Boss state
var current_phase: int = 0
var has_spawned_announcement: bool = false

# Visual components
var boss_health_bar: BossHealthBar

# Dialogue system
var dialogue_queue: Array = []
var dialogue_timer: float = 0.0
var dialogue_cooldown: float = 5.0
var is_speaking: bool = false

func _ready():
	# Set up boss stats
	max_health = boss_health
	current_health = boss_health
	damage = boss_damage
	move_speed = boss_move_speed
	attack_range = boss_attack_range
	attack_cooldown = boss_attack_cooldown
	
	# Set boss tag
	if taggable:
		taggable.add_tag("Boss")
	
	# Call parent ready
	super._ready()
	
	# Connect health signal for HP bar updates
	health_changed.connect(_update_health_bar)
	
	# Set up boss visuals
	_setup_boss_visuals()
	
	# Create OOP health bar component
	if shows_health_bar:
		boss_health_bar = BossHealthBar.new()
		boss_health_bar.name = "BossHealthBar"
		add_child(boss_health_bar)
	
	# Initialize health bar
	_update_health_bar(current_health, max_health)
	
	# Announce boss spawn
	if not has_spawned_announcement:
		has_spawned_announcement = true
		boss_spawned.emit(boss_name)
		_announce_spawn()

func _setup_boss_visuals():
	# Apply custom sprite if provided and sprite doesn't already have a texture
	if sprite_texture and sprite:
		if sprite is Sprite2D and not sprite.texture:
			sprite.texture = sprite_texture
		elif sprite is AnimatedSprite2D and not sprite.sprite_frames:
			# Create a simple sprite frames with the texture
			var frames = SpriteFrames.new()
			frames.add_animation("default")
			frames.add_frame("default", sprite_texture)
			sprite.sprite_frames = frames
			sprite.play("default")
	
	# Apply boss scale only if sprite scale is too large (backward compatibility)
	if sprite and sprite.scale.x > 1.0:
		sprite.scale *= boss_scale
	
	# Apply custom modulate
	if sprite:
		sprite.modulate = custom_modulate
	
	# Set up collision shape scaling
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.scale *= boss_scale

func _entity_physics_process(delta: float):
	super._entity_physics_process(delta)
	
	# Handle dialogue timer
	if dialogue_timer > 0:
		dialogue_timer -= delta
	
	# Check for phase changes
	if phases_enabled:
		_check_phase_change()

func _check_phase_change():
	var health_percentage = current_health / max_health
	var new_phase = 0
	
	for i in range(phase_thresholds.size()):
		if health_percentage <= phase_thresholds[i]:
			new_phase = i + 1
	
	if new_phase != current_phase:
		current_phase = new_phase
		boss_phase_changed.emit(current_phase)
		_on_phase_changed(current_phase)

## Virtual function - Override in child classes for phase-specific behavior
func _on_phase_changed(_phase: int):
	pass

## Virtual function - Override for custom spawn announcements
func _announce_spawn():
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message("⚔️ %s %s has entered the battlefield! HP: %d" % [boss_name, boss_title, int(max_health)], Color(1, 0.2, 0.2))

func take_damage(amount: float, source: Node = null, damage_tags: Array = []):
	super.take_damage(amount, source, damage_tags)
	
	# Boss-specific damage reactions
	if current_health > 0:
		_on_boss_damaged(amount, source)

## Virtual function - Override for custom damage reactions
func _on_boss_damaged(_amount: float, _source: Node):
	pass

func _update_health_bar(new_health: float, max_hp: float):
	# Use OOP health bar component
	if boss_health_bar:
		boss_health_bar.update_health(new_health, max_hp)
		return
	
	# Legacy fallback for existing bosses until they're migrated
	var health_container = get_node_or_null("HealthContainer")
	if health_container:
		var health_bar = health_container.get_node_or_null("HealthBar")
		if health_bar:
			health_bar.max_value = max_hp
			health_bar.value = new_health
		
		var health_label = health_container.get_node_or_null("HealthLabel")
		if health_label:
			health_label.text = "%d/%d" % [int(new_health), int(max_hp)]
	else:
		# Fallback for Thor who has direct children
		var health_bar = get_node_or_null("HealthBar")
		if health_bar:
			health_bar.max_value = max_hp
			health_bar.value = new_health
		
		var health_label = get_node_or_null("HealthLabel")
		if health_label:
			health_label.text = "%d/%d" % [int(new_health), int(max_hp)]

func die():
	boss_defeated.emit(boss_name)
	
	# Boss death announcement
	var action_feed = get_action_feed()
	if action_feed:
		action_feed.add_message("💀 %s %s has been defeated!" % [boss_name, boss_title], Color(0.2, 1, 0.2))
	
	# Trigger monster power ramping bonus
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.add_boss_death_bonus()
	
	# Create bigger death effect for bosses
	_create_boss_death_effect()
	
	super.die()

func _create_boss_death_effect():
	# Enhanced death particles for bosses
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 100  # More particles for bosses
	particles.lifetime = 1.5
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 30.0 * death_effect_scale
	particles.spread = 45.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.angular_velocity_min = -180.0
	particles.angular_velocity_max = 180.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1, 0.2, 0.2, 1)
	
	particles.global_position = global_position
	get_tree().current_scene.add_child(particles)
	particles.emitting = true

## Queue dialogue to be spoken
func queue_dialogue(text: String, priority: bool = false):
	if priority:
		dialogue_queue.push_front(text)
	else:
		dialogue_queue.append(text)

## Process dialogue queue
func _process_dialogue():
	if dialogue_timer <= 0 and dialogue_queue.size() > 0 and not is_speaking:
		var text = dialogue_queue.pop_front()
		speak_dialogue(text)

## Speak dialogue immediately
func speak_dialogue(text: String):
	is_speaking = true
	dialogue_timer = dialogue_cooldown
	boss_dialogue.emit(text)
	
	# Visual feedback - speech bubble or text above boss
	_show_dialogue_bubble(text)
	
	# Schedule end of speaking
	get_tree().create_timer(2.0).timeout.connect(func(): is_speaking = false)

func _show_dialogue_bubble(text: String):
	# Create floating text above boss
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 1, 0.8)
	label.z_index = 100
	
	# Position above boss
	label.position = Vector2(-100, -60 * boss_scale)
	add_child(label)
	
	# Animate and remove
	var tween = create_tween()
	tween.set_parallel()
	
	# Kill tween when label is freed
	label.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(label, "position:y", label.position.y - 30, 3.0)
	tween.tween_property(label, "modulate:a", 0.0, 3.0)
	tween.chain().tween_callback(label.queue_free)

## Get reference to action feed
func get_action_feed():
	var game = get_tree().get_first_node_in_group("game_controller")
	if game and game.has_method("get_action_feed"):
		return game.get_action_feed()
	return null
