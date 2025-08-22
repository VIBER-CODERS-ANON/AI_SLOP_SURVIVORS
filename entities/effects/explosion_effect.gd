extends Node2D
class_name ExplosionEffect

## Explosion effect with telegraph and damage

@export var damage: float = 10.0
@export var explosion_radius: float = 120.0
@export var telegraph_time: float = 0.8  # Time to show warning before explosion
@export var explosion_duration: float = 0.5
@export var damage_tags: Array[String] = ["AoE", "Fire"]

var source_entity: Node = null
var source_name: String = "Explosion"  # Fallback name if source is freed
var is_telegraphing: bool = true
var has_exploded: bool = false
var telegraph_timer: float = 0.0
var applied_aoe_scale: float = 1.0  # Track AoE scale for this explosion

# Tuning constants
const EXPLOSION_PREWAIT_MAX: float = 0.4
const EXPLOSION_WARN_DB: float = -18.0
const EXPLOSION_IMPACT_DB: float = 0.0

# Stagger telegraph start to reduce spam layering
var _rng := RandomNumberGenerator.new()
var _prewait: float = 0.0
var _prewait_timer: float = 0.0
var _waiting_before_telegraph: bool = true

func _ready():
	# Ensure explosion pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Start with a brief random wait to stagger many explosions
	_prewait = _rng.randf_range(0.0, EXPLOSION_PREWAIT_MAX)
	_waiting_before_telegraph = _prewait > 0.0
	set_process(true)
	z_index = 10  # Draw above most things
	
	# Set name for death messages
	name = source_name
	
	# Defer warning sound until telegraph actually begins

func _process(_delta):
	# Handle optional pre-wait before telegraph starts
	if _waiting_before_telegraph:
		_prewait_timer += _delta
		if _prewait_timer >= _prewait:
			_waiting_before_telegraph = false
			# Begin telegraph and play warning sound now
			if AudioManager.instance:
				AudioManager.instance.play_sfx(
					preload("res://audio/sfx_Retro_20250811_093319.mp3"),
					global_position,
					EXPLOSION_WARN_DB,
					1.5
				)
		return

	if is_telegraphing:
		telegraph_timer += _delta
		queue_redraw()
		if telegraph_timer >= telegraph_time:
			_explode()
	else:
		queue_redraw()

func _draw():
	if is_telegraphing:
		# Draw expanding warning circle
		var progress = telegraph_timer / telegraph_time
		var current_radius = explosion_radius * applied_aoe_scale * progress
		
		# Pulsing effect
		var pulse = sin(telegraph_timer * 20.0) * 0.2 + 0.8
		
		# Draw multiple circles for effect
		for i in range(3):
			var radius = current_radius - (i * 10)
			if radius > 0:
				var alpha = (1.0 - float(i) / 3.0) * pulse * 0.8
				var color = Color(1, 0.5, 0, alpha)
				draw_circle(Vector2.ZERO, radius, color)
		
		# Draw danger zone outline
		var outline_color = Color(1, 0.2, 0, pulse)
		draw_arc(Vector2.ZERO, explosion_radius * applied_aoe_scale, 0, TAU, 64, outline_color, 5.0)
		
		# Draw warning symbol in center
		if progress > 0.3:
			var font = ThemeDB.fallback_font
			var text = "!"
			var text_size = 48 * pulse
			draw_string(font, Vector2(-15, 15), text, HORIZONTAL_ALIGNMENT_CENTER, -1, text_size, Color(1, 0.8, 0, pulse))
	
	elif has_exploded:
		# Draw explosion effect
		var fade = 1.0 - (get_process_delta_time() * 2)
		if fade > 0:
			# Draw blast wave
			for i in range(5):
				var radius = explosion_radius * applied_aoe_scale * (1.0 - float(i) / 5.0)
				var alpha = fade * (1.0 - float(i) / 5.0) * 0.5
				draw_circle(Vector2.ZERO, radius, Color(1, 0.5, 0.1, alpha))

func _explode():
	is_telegraphing = false
	has_exploded = true
	
	# Create explosion particles
	var particles = CPUParticles2D.new()
	particles.amount = 200
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.emitting = true
	particles.spread = 45.0
	particles.initial_velocity_min = 200.0
	particles.initial_velocity_max = 400.0
	particles.gravity = Vector2(0, 500)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = Color(1, 0.6, 0.1, 1)
	add_child(particles)
	
	# Play explosion sound using AudioManager
	if AudioManager.instance:
		AudioManager.instance.play_sfx(
			preload("res://audio/sfx_Retro_20250811_093319.mp3"),
			global_position,
			EXPLOSION_IMPACT_DB
		)
	
	# Deal damage
	_damage_in_radius()
	
	# Clean up after explosion
	await get_tree().create_timer(explosion_duration).timeout
	queue_free()

func _damage_in_radius():
	var space = get_world_2d().direct_space_state
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius * applied_aoe_scale
	
	var params = PhysicsShapeQueryParameters2D.new()
	params.shape = circle
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_areas = true
	params.collide_with_bodies = true
	
	var results = space.intersect_shape(params, 64)
	
	for result in results:
		var collider = result["collider"]
		if collider and collider != source_entity and collider.has_method("take_damage"):
			var final_damage = damage
			
			# 50% damage reduction for lesser units
			if collider.has_method("has_tag") and collider.has_tag("Lesser"):
				final_damage = damage * 0.5  # 50% damage to lesser units
			
			# Use the explosion itself as damage source to avoid freed reference issues
			collider.take_damage(final_damage, self, damage_tags)

## Death attribution methods
func get_killer_display_name() -> String:
	# Try to get from source entity first
	if source_entity and is_instance_valid(source_entity):
		if source_entity.has_method("get_killer_display_name"):
			return source_entity.get_killer_display_name()
		elif source_entity.has_method("get_chatter_username"):
			return source_entity.get_chatter_username()
	
	# Fall back to stored source name
	return source_name

func get_chatter_username() -> String:
	if source_entity and is_instance_valid(source_entity):
		if source_entity.has_method("get_chatter_username"):
			return source_entity.get_chatter_username()
	return source_name

func get_chatter_color() -> Color:
	if source_entity and is_instance_valid(source_entity):
		if source_entity.has_method("get_chatter_color"):
			return source_entity.get_chatter_color()
	return Color.WHITE

func get_attack_name() -> String:
	return "explosion"
