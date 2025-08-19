extends Node2D

class_name LightSource

## Base class for all light sources in the game
## Provides common functionality for lights with support for effects and pooling

# Signals
@warning_ignore("unused_signal")
signal light_registered    # Emitted by LightingManager when registering lights
@warning_ignore("unused_signal")
signal light_unregistered  # Emitted by LightingManager when unregistering lights
signal energy_changed(new_energy: float)

# Light configuration
@export_group("Light Properties")
@export var base_energy: float = 1.0
@export var base_color: Color = Color.WHITE
@export var base_scale: float = 1.0
@export var texture_path: String = ""  # Path to light texture
@export var range_scale: float = 1.0  # Multiplier for light range

@export_group("Shadow Settings")
@export var cast_shadows: bool = true
@export var shadow_color: Color = Color(0, 0, 0, 0.5)
@export var shadow_filter: Light2D.ShadowFilter = Light2D.SHADOW_FILTER_PCF5

@export_group("Effect Settings")
@export var enable_effects: bool = true
@export var effect_intensity: float = 1.0

# Internal state
var current_energy: float = 0.0
var current_color: Color = Color.WHITE
var current_scale: float = 1.0
var light_node: Light2D = null
var is_active: bool = false
var effect_time: float = 0.0

# Performance
var update_frequency: float = 0.016  # 60 FPS by default
var time_since_update: float = 0.0

func _ready() -> void:
	# Set up the light
	_setup_light()
	
	# Register with lighting manager
	if LightingManager.instance:
		LightingManager.instance.register_light_source(self)

func _exit_tree() -> void:
	# Unregister and return light to pool
	if LightingManager.instance:
		LightingManager.instance.unregister_light_source(self)
	
	if light_node and LightingManager.instance:
		LightingManager.instance.return_light_to_pool(light_node)

func _setup_light() -> void:
	# Get a light from the pool
	if LightingManager.instance:
		light_node = LightingManager.instance.get_pooled_light()
		
		if light_node:
			# Configure the light
			light_node.enabled = true
			light_node.energy = base_energy
			light_node.color = base_color
			light_node.texture_scale = base_scale * range_scale
			
			# Set up shadows
			light_node.shadow_enabled = cast_shadows
			light_node.shadow_color = shadow_color
			light_node.shadow_filter = shadow_filter
			
			# Load texture if specified
			if texture_path != "":
				light_node.texture = load(texture_path)
			else:
				# Use default gradient texture for point lights
				_create_default_light_texture()
			
			# Parent to this node
			light_node.reparent(self)
			light_node.position = Vector2.ZERO
			
			# Set initial values
			current_energy = base_energy
			current_color = base_color
			current_scale = base_scale
			is_active = true

func _create_default_light_texture() -> void:
	# Create a radial gradient texture for the light
	var gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill = GradientTexture2D.FILL_RADIAL
	gradient_texture.fill_from = Vector2(0.5, 0.5)
	gradient_texture.fill_to = Vector2(1.0, 0.5)
	gradient_texture.width = 512
	gradient_texture.height = 512
	
	if light_node:
		light_node.texture = gradient_texture

func _process(delta: float) -> void:
	if not is_active or not light_node:
		return
	
	# Update timer
	time_since_update += delta
	effect_time += delta
	
	# Only update at specified frequency
	if time_since_update >= update_frequency:
		time_since_update = 0.0
		_update_light()
		
		if enable_effects:
			_apply_effects(delta)

func _update_light() -> void:
	if not light_node:
		return
	
	# Apply global multiplier
	var energy_multiplier = 1.0
	if LightingManager.instance:
		energy_multiplier = LightingManager.instance.global_light_energy_multiplier
	
	light_node.energy = current_energy * energy_multiplier
	light_node.color = current_color
	light_node.texture_scale = current_scale * range_scale

func _apply_effects(_delta: float) -> void:
	# Override in derived classes for specific effects
	pass

func set_energy(energy: float) -> void:
	current_energy = clamp(energy, 0.0, 10.0)
	energy_changed.emit(current_energy)
	_update_light()

func set_color(color: Color) -> void:
	current_color = color
	_update_light()

func set_light_scale(light_scale: float) -> void:
	current_scale = clamp(light_scale, 0.1, 10.0)
	_update_light()

func update_energy() -> void:
	_update_light()

func get_current_energy() -> float:
	return current_energy

func get_effective_range() -> float:
	if not light_node or not light_node.texture:
		return 100.0
	
	return light_node.texture.get_width() * light_node.texture_scale * 0.5

func enable() -> void:
	is_active = true
	if light_node:
		light_node.enabled = true

func disable() -> void:
	is_active = false
	if light_node:
		light_node.enabled = false

# Utility functions for effects
func pulse(frequency: float = 1.0, amplitude: float = 0.2) -> void:
	var pulse_value = sin(effect_time * frequency * TAU) * amplitude
	current_energy = base_energy + (base_energy * pulse_value)

func flicker(intensity: float = 0.3, _speed: float = 10.0) -> void:
	var flicker_value = randf_range(-intensity, intensity)
	current_energy = base_energy + (base_energy * flicker_value)

func fade_to(target_energy: float, duration: float) -> void:
	var tween = create_tween()
	tween.tween_property(self, "current_energy", target_energy, duration)

func flash(intensity: float = 2.0, duration: float = 0.2) -> void:
	var original_energy = current_energy
	current_energy = base_energy * intensity
	_update_light()
	
	var tween = create_tween()
	tween.tween_property(self, "current_energy", original_energy, duration)
