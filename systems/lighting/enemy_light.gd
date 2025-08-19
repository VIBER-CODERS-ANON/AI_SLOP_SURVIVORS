extends LightSource

class_name EnemyLight

## Light source for enemies with special effects based on enemy type and state
## Supports various enemy-specific lighting behaviors

enum EnemyLightType {
	NONE,
	GLOWING_EYES,
	FIRE_AURA,
	FROST_AURA,
	POISON_GLOW,
	ELECTRIC_SPARKS,
	SHADOW_AURA,
	HOLY_GLOW,
	DEMON_FIRE,
	SPECTRAL,
	CUSTOM
}

@export var enemy_light_type: EnemyLightType = EnemyLightType.GLOWING_EYES
@export_group("Light Behavior")
@export var scales_with_enemy_size: bool = true
@export var fades_on_death: bool = true
@export var death_fade_duration: float = 2.0
@export var pulses_when_attacking: bool = true
@export var attack_pulse_intensity: float = 1.5
@export var reacts_to_damage: bool = true
@export var damage_flash_color: Color = Color(1.0, 1.0, 1.0)

@export_group("Aggro Effects")
@export var aggro_energy_multiplier: float = 1.5
@export var aggro_color_shift: Color = Color(1.0, 0.5, 0.5)
@export var aggro_transition_speed: float = 2.0

# Enemy light presets
var enemy_light_presets = {
	EnemyLightType.GLOWING_EYES: {
		"base_energy": 0.3,
		"base_color": Color(1.0, 0.0, 0.0),
		"base_scale": 0.2,
		"cast_shadows": false,
		"position_offset": Vector2(0, -20)
	},
	EnemyLightType.FIRE_AURA: {
		"base_energy": 0.8,
		"base_color": Color(1.0, 0.5, 0.2),
		"base_scale": 0.8,
		"flicker_enabled": true,
		"flicker_intensity": 0.3
	},
	EnemyLightType.FROST_AURA: {
		"base_energy": 0.6,
		"base_color": Color(0.5, 0.8, 1.0),
		"base_scale": 0.7,
		"pulse_enabled": true,
		"pulse_frequency": 0.5
	},
	EnemyLightType.POISON_GLOW: {
		"base_energy": 0.5,
		"base_color": Color(0.3, 1.0, 0.2),
		"base_scale": 0.6,
		"pulse_enabled": true,
		"cast_shadows": false
	},
	EnemyLightType.ELECTRIC_SPARKS: {
		"base_energy": 0.7,
		"base_color": Color(0.8, 0.8, 1.0),
		"base_scale": 0.5,
		"flicker_enabled": true,
		"flicker_intensity": 0.5,
		"flicker_speed": 20.0
	},
	EnemyLightType.SHADOW_AURA: {
		"base_energy": -0.5,  # Negative light for darkness effect
		"base_color": Color(0.5, 0.0, 0.5),
		"base_scale": 1.0,
		"cast_shadows": false
	},
	EnemyLightType.DEMON_FIRE: {
		"base_energy": 1.0,
		"base_color": Color(1.0, 0.2, 0.0),
		"base_scale": 1.0,
		"flicker_enabled": true,
		"pulse_enabled": true
	},
	EnemyLightType.SPECTRAL: {
		"base_energy": 0.4,
		"base_color": Color(0.7, 0.7, 1.0),
		"base_scale": 0.8,
		"pulse_enabled": true,
		"cast_shadows": false,
		"alpha_fade": true
	}
}

# State tracking
var enemy_node: Node2D = null
var is_aggro: bool = false
var is_attacking: bool = false
var is_dying: bool = false
var original_scale: float = 1.0
var position_offset: Vector2 = Vector2.ZERO

# Effect state
var attack_pulse_timer: float = 0.0
var damage_flash_timer: float = 0.0
var aggro_blend: float = 0.0

func _ready() -> void:
	# Apply preset
	if enemy_light_type != EnemyLightType.NONE and enemy_light_type != EnemyLightType.CUSTOM:
		_apply_enemy_preset(enemy_light_type)
	
	# Get enemy node
	enemy_node = get_parent()
	
	# Scale based on enemy size if enabled
	if scales_with_enemy_size and enemy_node:
		_scale_to_enemy_size()
	
	super._ready()

func _apply_enemy_preset(type: EnemyLightType) -> void:
	if type not in enemy_light_presets:
		return
	
	var preset = enemy_light_presets[type]
	
	for key in preset:
		if key == "position_offset":
			position_offset = preset[key]
			position = position_offset
		elif key == "flicker_enabled":
			# Store for use in effects
			set_meta("flicker_enabled", preset[key])
		elif key == "flicker_intensity":
			set_meta("flicker_intensity", preset[key])
		elif key == "flicker_speed":
			set_meta("flicker_speed", preset[key])
		elif key == "pulse_enabled":
			set_meta("pulse_enabled", preset[key])
		elif key == "pulse_frequency":
			set_meta("pulse_frequency", preset[key])
		elif key in self:
			set(key, preset[key])

func _scale_to_enemy_size() -> void:
	if not enemy_node:
		return
	
	# Try to get enemy scale from sprite or collision shape
	var scale_factor = 1.0
	
	if enemy_node.has_node("Sprite2D"):
		var sprite = enemy_node.get_node("Sprite2D")
		scale_factor = (sprite.scale.x + sprite.scale.y) * 0.5
	elif enemy_node.has_node("AnimatedSprite2D"):
		var sprite = enemy_node.get_node("AnimatedSprite2D")
		scale_factor = (sprite.scale.x + sprite.scale.y) * 0.5
	
	original_scale = base_scale * scale_factor
	current_scale = original_scale

func _apply_effects(delta: float) -> void:
	if not enemy_node:
		return
	
	# Update enemy state
	_update_enemy_state()
	
	# Apply aggro effects
	if is_aggro:
		aggro_blend = min(aggro_blend + delta * aggro_transition_speed, 1.0)
	else:
		aggro_blend = max(aggro_blend - delta * aggro_transition_speed, 0.0)
	
	# Apply attack effects
	if is_attacking and pulses_when_attacking:
		attack_pulse_timer += delta
		var pulse_value = sin(attack_pulse_timer * 10.0) * 0.3 + 0.7
		current_energy = base_energy * attack_pulse_intensity * pulse_value
	else:
		attack_pulse_timer = 0.0
	
	# Apply damage flash
	if damage_flash_timer > 0:
		damage_flash_timer -= delta
		var flash_blend = damage_flash_timer / 0.2
		current_color = base_color.lerp(damage_flash_color, flash_blend)
	
	# Apply type-specific effects
	_apply_type_effects(delta)
	
	# Blend aggro state
	if aggro_blend > 0:
		current_energy = lerp(base_energy, base_energy * aggro_energy_multiplier, aggro_blend)
		if aggro_color_shift != Color.WHITE:
			current_color = base_color.lerp(aggro_color_shift, aggro_blend * 0.5)

func _update_enemy_state() -> void:
	if not enemy_node:
		return
	
	# Check if enemy has state methods
	if enemy_node.has_method("is_aggro"):
		is_aggro = enemy_node.is_aggro()
	
	if enemy_node.has_method("is_attacking"):
		is_attacking = enemy_node.is_attacking()
	
	if enemy_node.has_method("is_dying") and enemy_node.is_dying():
		if not is_dying:
			is_dying = true
			_start_death_fade()

func _apply_type_effects(_delta: float) -> void:
	# Apply preset-specific effects
	if has_meta("flicker_enabled") and get_meta("flicker_enabled"):
		var intensity = get_meta("flicker_intensity", 0.3)
		var speed = get_meta("flicker_speed", 10.0)
		flicker(intensity, speed)
	
	if has_meta("pulse_enabled") and get_meta("pulse_enabled"):
		var frequency = get_meta("pulse_frequency", 1.0)
		pulse(frequency, 0.2)
	
	# Special effects for specific types
	match enemy_light_type:
		EnemyLightType.ELECTRIC_SPARKS:
			# Random bright flashes
			if randf() < 0.02:  # 2% chance
				flash(2.0, 0.1)
		
		EnemyLightType.SPECTRAL:
			# Fade in and out
			var alpha_wave = (sin(effect_time * 2.0) + 1.0) * 0.5
			current_energy = base_energy * (0.5 + alpha_wave * 0.5)

func _start_death_fade() -> void:
	if fades_on_death:
		fade_to(0.0, death_fade_duration)
		
		# Disable after fade
		get_tree().create_timer(death_fade_duration).timeout.connect(func(): 
			disable()
			queue_free()
		)

# Public methods for enemy interaction
func trigger_damage_flash() -> void:
	if reacts_to_damage:
		damage_flash_timer = 0.2
		flash(1.5, 0.1)

func set_aggro_state(aggro: bool) -> void:
	is_aggro = aggro

func set_attack_state(attacking: bool) -> void:
	is_attacking = attacking

func enhance_for_elite(multiplier: float = 2.0) -> void:
	# Make elite enemies more visually impressive
	base_energy *= multiplier
	base_scale *= 1.5
	current_scale = base_scale
	
	# Add special effects
	set_meta("pulse_enabled", true)
	set_meta("pulse_frequency", 2.0)

# Static helper to create enemy lights
static func create_for_enemy(enemy: Node2D, light_type: EnemyLightType) -> EnemyLight:
	if light_type == EnemyLightType.NONE:
		return null
	
	var light = EnemyLight.new()
	light.enemy_light_type = light_type
	enemy.add_child(light)
	return light
