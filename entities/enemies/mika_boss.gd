extends BaseBoss
class_name MikaBoss

## Mika - The swift boss
## Modular boss with customizable abilities and behaviors

signal mika_dash_attack()
signal mika_summon_allies()
signal mika_enrage()

@export_group("Mika Specific")
@export var dash_attack_enabled: bool = false
@export var dash_attack_cooldown: float = 8.0
@export var dash_attack_range: float = 200.0
@export var summon_enabled: bool = false
@export var summon_cooldown: float = 20.0
@export var enrage_enabled: bool = false
@export var enrage_threshold: float = 0.3  # Enrage at 30% health

# Mika specific state
var dash_attack_timer: float = 0.0
var summon_timer: float = 0.0
var is_enraged: bool = false
var dash_target_position: Vector2
var is_dashing: bool = false

# Visual states
var original_modulate: Color

func _ready():
	# Set Mika specific properties
	boss_name = "Mika"
	boss_title = "The Swift"
	boss_health = 100.0
	boss_damage = 4.0
	boss_move_speed = 120.0  # Faster than other bosses
	boss_attack_range = 50.0  # Shorter range, prefers close combat
	boss_attack_cooldown = 1.5  # Faster attacks
	boss_scale = 1.0  # Normal sized, but fast
	custom_modulate = Color(1.0, 0.9, 0.9)  # Slight red tint
	
	# Load Mika sprite (commented out - loaded in spawn function)
	# _load_mika_sprites()
	
	# Store original modulate for enrage effect
	original_modulate = custom_modulate
	
	# Call parent ready
	super._ready()
	
	# Set up Mika specific features
	_setup_mika_abilities()

func _load_mika_sprites():
	# Load Mika sprite
	var mika_sprite = load("res://BespokeAssetSources/mika.png")
	if mika_sprite:
		sprite_texture = mika_sprite

func _setup_mika_abilities():
	# Initialize any special ability setups here
	phases_enabled = true  # Enable phase system for Mika

func _entity_physics_process(delta: float):
	super._entity_physics_process(delta)
	
	# Update ability timers
	if dash_attack_timer > 0:
		dash_attack_timer -= delta
	if summon_timer > 0:
		summon_timer -= delta
	
	# Handle dashing movement
	if is_dashing:
		_handle_dash_movement()
	
	# Check for enrage
	if enrage_enabled and not is_enraged:
		if current_health / max_health <= enrage_threshold:
			_activate_enrage()
	
	# Check for abilities
	if not is_dashing:
		_check_abilities()

func _check_abilities():
	var player = _find_player()
	if not player:
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Dash attack check
	if dash_attack_enabled and dash_attack_timer <= 0:
		if distance_to_player > attack_range and distance_to_player < dash_attack_range:
			_perform_dash_attack(player.global_position)
	
	# Summon check
	if summon_enabled and summon_timer <= 0:
		if distance_to_player < 300:  # Only summon when player is nearby
			_perform_summon()

func _perform_dash_attack(target_pos: Vector2):
	dash_attack_timer = dash_attack_cooldown
	mika_dash_attack.emit()
	
	is_dashing = true
	dash_target_position = target_pos
	
	# Visual telegraph
	_create_dash_telegraph()
	
	# Dialogue
	var dash_lines = [
		"Too slow!",
		"Catch me if you can!",
		"Strike!",
		"You're mine!"
	]
	speak_dialogue(dash_lines[randi() % dash_lines.size()])

func _handle_dash_movement():
	var dash_speed = move_speed * 3.0  # Triple speed during dash
	var direction = (dash_target_position - global_position).normalized()
	var distance = global_position.distance_to(dash_target_position)
	
	if distance < 10:
		# Reached target
		is_dashing = false
		_create_dash_impact()
		
		# Deal damage in small area
		var bodies = get_tree().get_nodes_in_group("player")
		for body in bodies:
			if body.global_position.distance_to(global_position) < 40:
				if body.has_method("take_damage"):
					body.take_damage(damage * 1.5, self, ["Physical", "Dash"])
	else:
		# Continue dashing
		velocity = direction * dash_speed
		move_and_slide()
		
		# Leave trail effect
		if randf() < 0.3:
			_create_dash_trail()

func _create_dash_telegraph():
	# Red line showing dash path
	var line = Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(dash_target_position - global_position)
	line.width = 3.0
	line.default_color = Color(1, 0.3, 0.3, 0.5)
	line.z_index = 49
	add_child(line)
	
	# Fade and remove
	var tween = create_tween()
	
	# Kill tween when line is freed
	line.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(line, "modulate:a", 0.0, 0.5)
	tween.tween_callback(line.queue_free)

func _create_dash_trail():
	# Speed trail effect
	var trail = Sprite2D.new()
	if sprite:
		trail.texture = sprite.texture
		trail.scale = sprite.scale * scale
		trail.modulate = Color(1, 0.5, 0.5, 0.3)
		trail.global_position = global_position
		trail.z_index = z_index - 1
		get_tree().current_scene.add_child(trail)
		
		var tween = trail.create_tween()
		
		# Kill tween when trail is freed
		trail.tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(trail, "modulate:a", 0.0, 0.3)
		tween.tween_callback(trail.queue_free)

func _create_dash_impact():
	# Impact particles
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 30
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 5.0
	particles.spread = 45.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 2.0
	particles.color = Color(1, 0.3, 0.3, 1)
	
	particles.global_position = global_position
	get_tree().current_scene.add_child(particles)

func _perform_summon():
	summon_timer = summon_cooldown
	mika_summon_allies.emit()
	
	# Create summoning effect
	_create_summon_effect()
	
	# Summon 2-3 weak minions
	var summon_count = randi_range(2, 3)
	for i in range(summon_count):
		_summon_minion(i)
	
	# Dialogue
	var summon_lines = [
		"Friends, aid me!",
		"You're outnumbered!",
		"Attack together!",
		"Swarm them!"
	]
	speak_dialogue(summon_lines[randi() % summon_lines.size()])

func _summon_minion(_index: int):
	# Create a basic enemy minion
	# This would spawn actual enemies in the full implementation
	var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	_create_summon_effect(global_position + offset)
	
	# In full implementation, spawn actual enemy here

func _create_summon_effect(pos: Vector2 = global_position):
	# Red summoning circle
	var circle = Line2D.new()
	circle.width = 3.0
	circle.default_color = Color(1, 0.2, 0.2, 0.8)
	circle.z_index = 49
	
	# Create circle
	var points = 32
	var radius = 30.0
	for i in range(points + 1):
		var angle = (i / float(points)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * radius
		circle.add_point(point)
	
	circle.global_position = pos
	get_tree().current_scene.add_child(circle)
	
	# Animate
	var tween = circle.create_tween()
	tween.set_parallel()
	
	# Kill tween when circle is freed
	circle.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(circle, "scale", Vector2(0.1, 0.1), 0.5).from(Vector2(2, 2))
	tween.tween_property(circle, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(circle.queue_free)

func _activate_enrage():
	is_enraged = true
	mika_enrage.emit()
	
	# Visual changes
	if sprite:
		sprite.modulate = Color(1.5, 0.5, 0.5)  # Red glow
	
	# Stat boosts
	move_speed *= 1.5
	attack_cooldown *= 0.5
	dash_attack_cooldown *= 0.7
	
	# Announcement
	speak_dialogue("NOW YOU'VE MADE ME ANGRY!")
	
	# Continuous red aura
	_create_enrage_aura()

func _create_enrage_aura():
	# Add a pulsing red effect
	if sprite:
		var tween = create_tween()
		tween.set_loops(-1)  # Infinite loops
		
		# Store tween reference for cleanup
		set_meta("enrage_tween", tween)
		
		# Kill tween when boss dies or when enrage ends
		tree_exiting.connect(func(): 
			if tween and tween.is_valid():
				tween.kill()
		)
		
		tween.tween_property(sprite, "modulate", Color(2, 0.3, 0.3), 0.5)
		tween.tween_property(sprite, "modulate", Color(1.5, 0.5, 0.5), 0.5)

func _on_phase_changed(phase: int):
	match phase:
		1:
			speak_dialogue("Warming up!")
			dash_attack_enabled = true
		2:
			speak_dialogue("Let's get serious!")
			summon_enabled = true
			move_speed *= 1.2
		3:
			speak_dialogue("Time to end this!")
			enrage_enabled = true

func _on_boss_damaged(_amount: float, _source: Node):
	# Quick counter-attack chance when hit
	if randf() < 0.15:  # 15% chance
		var damage_lines = [
			"Quick reflexes!",
			"Not fast enough!",
			"Nice try!",
			"My turn!"
		]
		speak_dialogue(damage_lines[randi() % damage_lines.size()])
		
		# Small dash backwards
		if _source:
			var away_direction = (global_position - _source.global_position).normalized()
			global_position += away_direction * 50
