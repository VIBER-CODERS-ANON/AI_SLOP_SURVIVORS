extends Node
class_name DebugSettings

## Global debug settings for performance testing
## Toggle various systems to identify performance bottlenecks

static var instance: DebugSettings

const SAVE_PATH = "user://debug_settings.cfg"

# Visual toggles
var nameplates_enabled: bool = true
var health_bars_enabled: bool = true
var pillars_pits_enabled: bool = true
var lighting_enabled: bool = true
var shadows_enabled: bool = true
var particles_enabled: bool = true
var animations_enabled: bool = true
var visual_effects_enabled: bool = true

# Collision toggles
var player_collision_enabled: bool = true
var mob_to_mob_collision_enabled: bool = true
var projectile_collision_enabled: bool = true

# AI/Movement toggles
var mob_movement_enabled: bool = true
var mob_ai_enabled: bool = true
var pathfinding_enabled: bool = true
var flocking_enabled: bool = true  # mob to mob force

# Audio toggles
var sfx_enabled: bool = true
var music_enabled: bool = true
var voice_lines_enabled: bool = true

# System toggles
var ability_system_enabled: bool = true
var weapon_system_enabled: bool = true
var spawning_enabled: bool = true
var xp_drops_enabled: bool = true
var damage_numbers_enabled: bool = true

# Physics
var physics_interpolation_enabled: bool = true
# vsync_enabled removed - handled by SettingsManager

# Rendering
var post_processing_enabled: bool = true
var screen_effects_enabled: bool = true

func _ready():
	instance = self
	# Add to autoload
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load saved settings on startup
	load_settings()

func apply_settings():
	# Apply visual settings
	RenderingServer.directional_shadow_atlas_set_size(4096 if shadows_enabled else 0, true)
	
	# Apply collision layers
	if not mob_to_mob_collision_enabled:
		# Disable enemy-enemy collision by modifying physics layers
		ProjectSettings.set_setting("layer_names/2d_physics/layer_2", "")
	
	# Apply audio settings
	if not sfx_enabled:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
	if not music_enabled:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
	
	# DON'T apply vsync here - let SettingsManager handle display settings
	# This was overriding the menu settings!
	# if vsync_enabled:
	#	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	# else:
	#	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Save settings after applying
	save_settings()

func get_debug_string() -> String:
	var disabled_systems = []
	
	if not nameplates_enabled: disabled_systems.append("Nameplates")
	if not health_bars_enabled: disabled_systems.append("HealthBars")
	if not pillars_pits_enabled: disabled_systems.append("Pillars/Pits")
	if not lighting_enabled: disabled_systems.append("Lighting")
	if not shadows_enabled: disabled_systems.append("Shadows")
	if not particles_enabled: disabled_systems.append("Particles")
	if not animations_enabled: disabled_systems.append("Animations")
	if not player_collision_enabled: disabled_systems.append("PlayerCol")
	if not mob_to_mob_collision_enabled: disabled_systems.append("MobCol")
	if not mob_movement_enabled: disabled_systems.append("Movement")
	if not mob_ai_enabled: disabled_systems.append("AI")
	if not pathfinding_enabled: disabled_systems.append("Pathfinding")
	if not flocking_enabled: disabled_systems.append("Flocking")
	if not sfx_enabled: disabled_systems.append("SFX")
	if not ability_system_enabled: disabled_systems.append("Abilities")
	if not weapon_system_enabled: disabled_systems.append("Weapons")
	if not spawning_enabled: disabled_systems.append("Spawning")
	
	if disabled_systems.is_empty():
		return "All systems enabled"
	else:
		return "DISABLED: " + ", ".join(disabled_systems)

## Quick preset configurations
func set_minimal_mode():
	# Turn off everything except core gameplay
	nameplates_enabled = false
	health_bars_enabled = false
	pillars_pits_enabled = false
	lighting_enabled = false
	shadows_enabled = false
	particles_enabled = false
	animations_enabled = false
	visual_effects_enabled = false
	sfx_enabled = false
	music_enabled = false
	voice_lines_enabled = false
	post_processing_enabled = false
	screen_effects_enabled = false
	damage_numbers_enabled = false
	apply_settings()  # Save changes

func set_no_visuals_mode():
	# Keep gameplay but remove all visual extras
	nameplates_enabled = false
	health_bars_enabled = false
	lighting_enabled = false
	shadows_enabled = false
	particles_enabled = false
	visual_effects_enabled = false
	post_processing_enabled = false
	screen_effects_enabled = false
	damage_numbers_enabled = false
	apply_settings()  # Save changes

func set_no_ai_mode():
	# Disable all AI/movement for static testing
	mob_movement_enabled = false
	mob_ai_enabled = false
	pathfinding_enabled = false
	flocking_enabled = false
	ability_system_enabled = false
	apply_settings()  # Save changes

func reset_to_defaults():
	nameplates_enabled = true
	health_bars_enabled = true
	pillars_pits_enabled = true
	lighting_enabled = true
	shadows_enabled = true
	particles_enabled = true
	animations_enabled = true
	visual_effects_enabled = true
	player_collision_enabled = true
	mob_to_mob_collision_enabled = true
	projectile_collision_enabled = true
	mob_movement_enabled = true
	mob_ai_enabled = true
	pathfinding_enabled = true
	flocking_enabled = true
	sfx_enabled = true
	music_enabled = true
	voice_lines_enabled = true
	ability_system_enabled = true
	weapon_system_enabled = true
	spawning_enabled = true
	xp_drops_enabled = true
	damage_numbers_enabled = true
	physics_interpolation_enabled = true
	# vsync handled by SettingsManager
	post_processing_enabled = true
	screen_effects_enabled = true
	# Apply and save after reset
	apply_settings()

func save_settings():
	var config = ConfigFile.new()
	
	# Visual settings
	config.set_value("visual", "nameplates_enabled", nameplates_enabled)
	config.set_value("visual", "health_bars_enabled", health_bars_enabled)
	config.set_value("visual", "pillars_pits_enabled", pillars_pits_enabled)
	config.set_value("visual", "lighting_enabled", lighting_enabled)
	config.set_value("visual", "shadows_enabled", shadows_enabled)
	config.set_value("visual", "particles_enabled", particles_enabled)
	config.set_value("visual", "animations_enabled", animations_enabled)
	config.set_value("visual", "visual_effects_enabled", visual_effects_enabled)
	config.set_value("visual", "damage_numbers_enabled", damage_numbers_enabled)
	
	# Collision settings
	config.set_value("collision", "player_collision_enabled", player_collision_enabled)
	config.set_value("collision", "mob_to_mob_collision_enabled", mob_to_mob_collision_enabled)
	config.set_value("collision", "projectile_collision_enabled", projectile_collision_enabled)
	
	# AI/Movement settings
	config.set_value("ai", "mob_movement_enabled", mob_movement_enabled)
	config.set_value("ai", "mob_ai_enabled", mob_ai_enabled)
	config.set_value("ai", "pathfinding_enabled", pathfinding_enabled)
	config.set_value("ai", "flocking_enabled", flocking_enabled)
	
	# Audio settings
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("audio", "music_enabled", music_enabled)
	config.set_value("audio", "voice_lines_enabled", voice_lines_enabled)
	
	# System settings
	config.set_value("system", "ability_system_enabled", ability_system_enabled)
	config.set_value("system", "weapon_system_enabled", weapon_system_enabled)
	config.set_value("system", "spawning_enabled", spawning_enabled)
	config.set_value("system", "xp_drops_enabled", xp_drops_enabled)
	
	# Physics/Rendering
	config.set_value("rendering", "physics_interpolation_enabled", physics_interpolation_enabled)
	# vsync removed - handled by SettingsManager
	config.set_value("rendering", "post_processing_enabled", post_processing_enabled)
	config.set_value("rendering", "screen_effects_enabled", screen_effects_enabled)
	
	config.save(SAVE_PATH)

func load_settings():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # No saved settings, use defaults
	
	# Visual settings
	nameplates_enabled = config.get_value("visual", "nameplates_enabled", true)
	health_bars_enabled = config.get_value("visual", "health_bars_enabled", true)
	pillars_pits_enabled = config.get_value("visual", "pillars_pits_enabled", true)
	lighting_enabled = config.get_value("visual", "lighting_enabled", true)
	shadows_enabled = config.get_value("visual", "shadows_enabled", true)
	particles_enabled = config.get_value("visual", "particles_enabled", true)
	animations_enabled = config.get_value("visual", "animations_enabled", true)
	visual_effects_enabled = config.get_value("visual", "visual_effects_enabled", true)
	damage_numbers_enabled = config.get_value("visual", "damage_numbers_enabled", true)
	
	# Collision settings
	player_collision_enabled = config.get_value("collision", "player_collision_enabled", true)
	mob_to_mob_collision_enabled = config.get_value("collision", "mob_to_mob_collision_enabled", true)
	projectile_collision_enabled = config.get_value("collision", "projectile_collision_enabled", true)
	
	# AI/Movement settings
	mob_movement_enabled = config.get_value("ai", "mob_movement_enabled", true)
	mob_ai_enabled = config.get_value("ai", "mob_ai_enabled", true)
	pathfinding_enabled = config.get_value("ai", "pathfinding_enabled", true)
	flocking_enabled = config.get_value("ai", "flocking_enabled", true)
	
	# Audio settings
	sfx_enabled = config.get_value("audio", "sfx_enabled", true)
	music_enabled = config.get_value("audio", "music_enabled", true)
	voice_lines_enabled = config.get_value("audio", "voice_lines_enabled", true)
	
	# System settings
	ability_system_enabled = config.get_value("system", "ability_system_enabled", true)
	weapon_system_enabled = config.get_value("system", "weapon_system_enabled", true)
	spawning_enabled = config.get_value("system", "spawning_enabled", true)
	xp_drops_enabled = config.get_value("system", "xp_drops_enabled", true)
	
	# Physics/Rendering
	physics_interpolation_enabled = config.get_value("rendering", "physics_interpolation_enabled", true)
	# vsync removed - handled by SettingsManager
	post_processing_enabled = config.get_value("rendering", "post_processing_enabled", true)
	screen_effects_enabled = config.get_value("rendering", "screen_effects_enabled", true)
	
	# Apply loaded settings
	apply_settings()

## Get all debug property names dynamically
func get_all_property_names() -> Array[String]:
	# Use reflection to get all boolean properties instead of hardcoding
	var properties: Array[String] = []
	var property_list = get_property_list()
	
	for property in property_list:
		var property_name = property["name"]
		var property_type = property["type"]
		
		# Only include boolean properties that end with "_enabled" 
		if property_type == TYPE_BOOL and property_name.ends_with("_enabled"):
			properties.append(property_name)
	
	return properties

## Refresh all debug panel UI elements to match current settings
func refresh_ui():
	# Update all checkboxes in the debug_toggles group
	var checkboxes = get_tree().get_nodes_in_group("debug_toggles")
	for cb in checkboxes:
		if cb is CheckBox and cb.has_meta("property_name"):
			var property_name = cb.get_meta("property_name")
			cb.set_pressed_no_signal(get(property_name))
