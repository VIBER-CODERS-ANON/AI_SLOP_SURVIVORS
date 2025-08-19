extends LightSource

class_name EnvironmentalLight

## Light source for environmental objects like torches, braziers, candles, etc.
## Supports various dynamic effects to create atmospheric lighting

enum LightType {
	TORCH,
	BRAZIER,
	CANDLE,
	CRYSTAL,
	MAGIC_ORB,
	LAVA_GLOW,
	MUSHROOM,
	CUSTOM
}

@export var light_type: LightType = LightType.TORCH
@export_group("Effect Parameters")
@export var flicker_enabled: bool = true
@export var flicker_intensity: float = 0.3
@export var flicker_speed: float = 10.0
@export var pulse_enabled: bool = false
@export var pulse_frequency: float = 1.0
@export var pulse_amplitude: float = 0.2
@export var wind_sway_enabled: bool = false
@export var wind_intensity: float = 0.1
@export var wind_speed: float = 2.0

@export_group("Color Variation")
@export var enable_color_variation: bool = true
@export var color_variation_speed: float = 0.5
@export var color_variation_amount: float = 0.1

# Preset configurations for different light types
var light_presets = {
	LightType.TORCH: {
		"base_energy": 0.8,
		"base_color": Color(1.0, 0.7, 0.3),
		"base_scale": 0.8,
		"flicker_intensity": 0.3,
		"flicker_speed": 8.0,
		"wind_sway_enabled": true,
		"shadow_enabled": true
	},
	LightType.BRAZIER: {
		"base_energy": 1.2,
		"base_color": Color(1.0, 0.6, 0.2),
		"base_scale": 1.2,
		"flicker_intensity": 0.2,
		"flicker_speed": 6.0,
		"shadow_enabled": true
	},
	LightType.CANDLE: {
		"base_energy": 0.4,
		"base_color": Color(1.0, 0.9, 0.6),
		"base_scale": 0.3,
		"flicker_intensity": 0.4,
		"flicker_speed": 12.0,
		"wind_sway_enabled": true,
		"shadow_enabled": false
	},
	LightType.CRYSTAL: {
		"base_energy": 0.9,
		"base_color": Color(0.6, 0.8, 1.0),
		"base_scale": 0.9,
		"pulse_enabled": true,
		"pulse_frequency": 0.5,
		"pulse_amplitude": 0.2,
		"flicker_enabled": false,
		"shadow_enabled": false
	},
	LightType.MAGIC_ORB: {
		"base_energy": 1.0,
		"base_color": Color(0.8, 0.3, 1.0),
		"base_scale": 0.7,
		"pulse_enabled": true,
		"pulse_frequency": 1.0,
		"pulse_amplitude": 0.3,
		"enable_color_variation": true,
		"shadow_enabled": false
	},
	LightType.LAVA_GLOW: {
		"base_energy": 1.5,
		"base_color": Color(1.0, 0.3, 0.1),
		"base_scale": 1.5,
		"flicker_intensity": 0.1,
		"flicker_speed": 3.0,
		"pulse_enabled": true,
		"pulse_frequency": 0.3,
		"shadow_enabled": true
	},
	LightType.MUSHROOM: {
		"base_energy": 0.5,
		"base_color": Color(0.4, 1.0, 0.6),
		"base_scale": 0.6,
		"pulse_enabled": true,
		"pulse_frequency": 0.2,
		"pulse_amplitude": 0.1,
		"shadow_enabled": false
	}
}

# Effect state
var noise: FastNoiseLite
var wind_offset: float = 0.0
var color_offset: float = 0.0
var original_position: Vector2

func _ready() -> void:
	# Apply preset if not custom
	if light_type != LightType.CUSTOM:
		_apply_preset(light_type)
	
	# Initialize noise for random effects
	noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.1
	
	# Store original position for wind sway
	original_position = position
	
	# Add random start offset for effects to prevent synchronization
	effect_time = randf() * TAU
	
	super._ready()

func _apply_preset(type: LightType) -> void:
	if type not in light_presets:
		return
	
	var preset = light_presets[type]
	
	# Apply all preset values
	for key in preset:
		if key in self:
			set(key, preset[key])

func _apply_effects(_delta: float) -> void:
	# Apply flicker effect
	if flicker_enabled:
		_apply_flicker()
	
	# Apply pulse effect
	if pulse_enabled:
		pulse(pulse_frequency, pulse_amplitude)
	
	# Apply wind sway
	if wind_sway_enabled:
		_apply_wind_sway()
	
	# Apply color variation
	if enable_color_variation:
		_apply_color_variation()
	
	# Update the light
	_update_light()

func _apply_flicker() -> void:
	# Use noise for more realistic flicker
	var flicker_noise = noise.get_noise_1d(effect_time * flicker_speed)
	var flicker_value = flicker_noise * flicker_intensity
	
	# Add occasional stronger flickers
	if randf() < 0.01:  # 1% chance per frame
		flicker_value += randf_range(-0.5, -0.2)
	
	current_energy = base_energy + (base_energy * flicker_value)
	current_energy = max(current_energy, base_energy * 0.3)  # Don't go too dark

func _apply_wind_sway() -> void:
	wind_offset += effect_time * wind_speed
	
	# Create complex wind pattern
	var wind_x = sin(wind_offset) * cos(wind_offset * 0.7) * wind_intensity
	var wind_y = cos(wind_offset * 1.3) * sin(wind_offset * 0.5) * wind_intensity * 0.5
	
	# Apply position offset
	if light_node:
		light_node.position = Vector2(wind_x * 10, wind_y * 5)

func _apply_color_variation() -> void:
	color_offset += effect_time * color_variation_speed
	
	# Create subtle color shifts
	var hue_shift = sin(color_offset) * color_variation_amount
	var saturation_shift = cos(color_offset * 0.7) * color_variation_amount * 0.5
	
	# Apply color modification using HSV
	var h = base_color.h
	var s = base_color.s
	var v = base_color.v
	
	# Apply shifts
	h = fmod(h + hue_shift, 1.0)
	s = clamp(s + saturation_shift, 0.0, 1.0)
	
	current_color = Color.from_hsv(h, s, v, base_color.a)

# Environmental interaction methods
func react_to_wind(wind_strength: Vector2) -> void:
	if not wind_sway_enabled:
		return
	
	# Temporary increase in wind effect
	wind_intensity = clamp(wind_intensity + wind_strength.length() * 0.1, 0.0, 1.0)
	
	# Create tween to return to normal
	var tween = create_tween()
	tween.tween_property(self, "wind_intensity", 0.1, 2.0)

func extinguish(duration: float = 1.0) -> void:
	# Fade out and disable
	fade_to(0.0, duration)
	
	# Disable after fade
	get_tree().create_timer(duration).timeout.connect(disable)

func ignite(duration: float = 0.5) -> void:
	# Start from darkness
	current_energy = 0.0
	enable()
	fade_to(base_energy, duration)

# Interaction methods
func interact() -> void:
	# Different interactions based on type
	match light_type:
		LightType.TORCH, LightType.CANDLE:
			if is_active:
				extinguish()
			else:
				ignite()
		LightType.CRYSTAL, LightType.MAGIC_ORB:
			# Pulse on interaction
			flash(2.0, 0.5)

# Static method to spawn environmental lights
static func create_light(type: LightType, pos: Vector2, parent: Node) -> EnvironmentalLight:
	var light_instance = EnvironmentalLight.new()
	light_instance.light_type = type
	light_instance.position = pos
	parent.add_child(light_instance)
	return light_instance
