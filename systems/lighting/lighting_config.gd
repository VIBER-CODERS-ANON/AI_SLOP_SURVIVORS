extends Resource

class_name LightingConfig

## Resource for storing lighting configuration presets
## Can be saved/loaded and swapped at runtime

@export_group("Ambient Settings")
@export var ambient_color: Color = Color(0.05, 0.05, 0.1, 1.0)
@export var ambient_intensity: float = 0.2
@export var fog_enabled: bool = false
@export var fog_color: Color = Color(0.1, 0.1, 0.15, 0.5)
@export var fog_density: float = 0.5

@export_group("Global Light Settings")
@export var global_energy_multiplier: float = 1.0
@export var enable_shadows: bool = true
@export var shadow_softness: float = 0.5
@export var shadow_opacity: float = 0.7
@export var max_visible_lights: int = 30

@export_group("Performance Settings")
@export var light_culling_distance: float = 1500.0
@export var update_frequency: float = 0.016  # 60 FPS
@export var use_light_pooling: bool = true
@export var dynamic_quality_adjustment: bool = true

@export_group("Effect Intensities")
@export var flicker_intensity_multiplier: float = 1.0
@export var pulse_intensity_multiplier: float = 1.0
@export var color_variation_multiplier: float = 1.0

@export_group("Player Light Overrides")
@export var player_light_radius_multiplier: float = 1.0
@export var player_light_energy_multiplier: float = 1.0
@export var player_light_color_override: Color = Color.WHITE
@export var use_player_light_override: bool = false

@export_group("Environmental Light Defaults")
@export var torch_energy_multiplier: float = 1.0
@export var torch_radius_multiplier: float = 1.0
@export var environmental_shadow_enabled: bool = true

# Preset name for identification
@export var preset_name: String = "Default"
@export var description: String = ""

# Apply this configuration to the lighting manager
func apply_to_manager(manager: LightingManager) -> void:
	if not manager:
		return
	
	manager.ambient_color = ambient_color
	manager.ambient_intensity = ambient_intensity
	manager.global_light_energy_multiplier = global_energy_multiplier
	manager.enable_shadows = enable_shadows
	
	# Update canvas modulate
	manager.set_ambient_lighting(ambient_color, ambient_intensity)
	
	# Update all active lights
	for light in manager.active_lights:
		light.update_energy()

# Create preset configurations
static func create_dungeon_preset() -> LightingConfig:
	var config = LightingConfig.new()
	config.preset_name = "Dark Dungeon"
	config.ambient_color = Color(0.05, 0.05, 0.1)
	config.ambient_intensity = 0.15
	config.global_energy_multiplier = 0.9
	config.player_light_radius_multiplier = 1.2
	config.torch_energy_multiplier = 0.8
	config.enable_shadows = true
	config.fog_enabled = true
	config.fog_density = 0.3
	return config

static func create_hell_preset() -> LightingConfig:
	var config = LightingConfig.new()
	config.preset_name = "Hellfire"
	config.ambient_color = Color(0.2, 0.05, 0.0)
	config.ambient_intensity = 0.25
	config.global_energy_multiplier = 1.2
	config.player_light_color_override = Color(1.0, 0.7, 0.5)
	config.use_player_light_override = true
	config.torch_energy_multiplier = 1.5
	config.flicker_intensity_multiplier = 1.5
	return config

static func create_crypt_preset() -> LightingConfig:
	var config = LightingConfig.new()
	config.preset_name = "Ancient Crypt"
	config.ambient_color = Color(0.0, 0.05, 0.1)
	config.ambient_intensity = 0.1
	config.global_energy_multiplier = 0.7
	config.player_light_radius_multiplier = 1.5
	config.torch_energy_multiplier = 0.5
	config.enable_shadows = true
	config.shadow_opacity = 0.9
	config.fog_enabled = true
	config.fog_color = Color(0.0, 0.05, 0.1, 0.7)
	config.fog_density = 0.6
	return config

static func create_crystal_cave_preset() -> LightingConfig:
	var config = LightingConfig.new()
	config.preset_name = "Crystal Cave"
	config.ambient_color = Color(0.1, 0.15, 0.3)
	config.ambient_intensity = 0.3
	config.global_energy_multiplier = 1.1
	config.environmental_shadow_enabled = false
	config.color_variation_multiplier = 2.0
	config.pulse_intensity_multiplier = 1.5
	return config

# Save/Load functionality
func save_to_file(path: String) -> void:
	ResourceSaver.save(self, path)

static func load_from_file(path: String) -> LightingConfig:
	return load(path) as LightingConfig
