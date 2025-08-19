extends Node

class_name LightingManager

## Central manager for all lighting in the game
## Handles ambient lighting, light sources, and lighting presets

# Singleton reference
static var instance: LightingManager

# Light configuration
@export_group("Ambient Lighting")
@export var ambient_color: Color = Color(0.05, 0.05, 0.1, 1.0)  # Dark blue tint for dungeon feel
@export var ambient_intensity: float = 0.8

@export_group("Global Light Settings")
@export var global_light_energy_multiplier: float = 1.0
@export var enable_shadows: bool = true
@export var shadow_softness: float = 0.5
@export var enable_light_occlusion: bool = true

# Light pools for performance
var active_lights: Array[LightSource] = []
var light_pool: Array[Light2D] = []
var max_lights: int = 50

# Canvas modulate for ambient lighting
var canvas_modulate: CanvasModulate

# Light presets
var lighting_presets := {
	"normal": {
		"ambient_color": Color(0.15, 0.15, 0.2, 1.0),
		"ambient_intensity": 0.3,
		"energy_multiplier": 1.0
	},
	"dark": {
		"ambient_color": Color(0.05, 0.05, 0.1, 1.0),
		"ambient_intensity": 0.15,
		"energy_multiplier": 0.8
	},
	"dark_red": {
		"ambient_color": Color(0.15, 0.05, 0.05, 1.0),
		"ambient_intensity": 0.2,
		"energy_multiplier": 0.9
	},
	"hellfire": {
		"ambient_color": Color(0.2, 0.1, 0.05, 1.0),
		"ambient_intensity": 0.25,
		"energy_multiplier": 1.2
	},
	"foggy": {
		"ambient_color": Color(0.2, 0.2, 0.25, 1.0),
		"ambient_intensity": 0.4,
		"energy_multiplier": 0.7
	}
}

func _ready() -> void:
	instance = self
	_setup_ambient_lighting()
	_initialize_light_pool()

func _setup_ambient_lighting() -> void:
	# Create canvas modulate for ambient lighting
	canvas_modulate = CanvasModulate.new()
	# Don't multiply alpha channel to avoid transparency
	var final_color = ambient_color * ambient_intensity
	final_color.a = 1.0  # Force full opacity
	canvas_modulate.color = final_color
	add_child(canvas_modulate)

func _initialize_light_pool() -> void:
	# Pre-create lights for pooling
	for i in range(max_lights):
		var light = PointLight2D.new()
		light.enabled = false
		light.shadow_enabled = enable_shadows
		light.texture_scale = 1.0
		light.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(light)
		light_pool.append(light)

func register_light_source(light_source: LightSource) -> void:
	if light_source not in active_lights:
		active_lights.append(light_source)
		light_source.light_registered.emit()

func unregister_light_source(light_source: LightSource) -> void:
	active_lights.erase(light_source)
	light_source.light_unregistered.emit()

func get_pooled_light() -> Light2D:
	for light in light_pool:
		if not light.enabled:
			return light
	
	# If no lights available, create a new one
	push_warning("Light pool exhausted, creating new light")
	var new_light = PointLight2D.new()
	new_light.shadow_enabled = enable_shadows
	add_child(new_light)
	light_pool.append(new_light)
	return new_light

func return_light_to_pool(light: Light2D) -> void:
	light.enabled = false
	light.energy = 0.0
	if light.get_parent():
		light.reparent(self)

func apply_preset(preset_name: String) -> void:
	if preset_name not in lighting_presets:
		push_error("Unknown lighting preset: " + preset_name)
		return
	
	var preset = lighting_presets[preset_name]
	ambient_color = preset["ambient_color"]
	ambient_intensity = preset["ambient_intensity"]
	global_light_energy_multiplier = preset["energy_multiplier"]
	
	# Update canvas modulate
	if canvas_modulate:
		canvas_modulate.color = ambient_color * ambient_intensity
	
	# Update all active lights
	for light_source in active_lights:
		light_source.update_energy()

func set_ambient_lighting(color: Color, intensity: float) -> void:
	ambient_color = color
	ambient_intensity = intensity
	if canvas_modulate:
		var final_color = ambient_color * ambient_intensity
		final_color.a = 1.0  # Force full opacity
		canvas_modulate.color = final_color

func get_lights_at_position(pos: Vector2, radius: float = 500.0) -> Array[LightSource]:
	var nearby_lights: Array[LightSource] = []
	for light in active_lights:
		if light.global_position.distance_to(pos) <= radius:
			nearby_lights.append(light)
	return nearby_lights

func get_total_light_energy_at_position(pos: Vector2) -> float:
	var total_energy = ambient_intensity
	for light in active_lights:
		var distance = light.global_position.distance_to(pos)
		if distance < light.get_effective_range():
			var falloff = 1.0 - (distance / light.get_effective_range())
			total_energy += light.get_current_energy() * falloff
	return total_energy

# Debug functions
func get_active_light_count() -> int:
	return active_lights.size()

func get_debug_info() -> Dictionary:
	return {
		"active_lights": active_lights.size(),
		"pooled_lights": light_pool.size(),
		"ambient_intensity": ambient_intensity,
		"global_multiplier": global_light_energy_multiplier
	}
