extends Node
class_name SettingsManager

## Manages persistent game settings that save between sessions
## Currently handles audio volume settings

signal settings_loaded()
signal settings_saved()

static var instance: SettingsManager

const SETTINGS_FILE_PATH = "user://game_settings.cfg"

# Settings data
var settings_config: ConfigFile

# Default settings
const DEFAULT_SETTINGS = {
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.5,
		"sfx_volume": 1.0,
		"dialog_volume": 1.0
	},
	"display": {
		"fullscreen": false,
		"vsync": true,
		"resolution_width": 1920,
		"resolution_height": 1080
	},
	"twitch": {
		"channel_name": "quin69"
	}
}

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load settings on startup
	load_settings()
	
	# Delay applying display settings to ensure they override project settings
	await get_tree().create_timer(0.1).timeout
	
	# Force apply display settings to override project.godot
	_force_apply_display_settings()
	
	print("⚙️ Settings Manager initialized!")

## Load settings from file
func load_settings():
	settings_config = ConfigFile.new()
	var err = settings_config.load(SETTINGS_FILE_PATH)
	
	if err != OK:
		print("⚙️ No settings file found, creating defaults...")
		_create_default_settings()
		save_settings()
	else:
		print("⚙️ Settings loaded successfully!")
		_apply_loaded_settings()
	
	settings_loaded.emit()

## Save current settings to file
func save_settings():
	# Get current audio bus volumes
	var master_idx = AudioServer.get_bus_index("Master")
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	var dialog_idx = AudioServer.get_bus_index("Dialog")
	
	# Convert from db to linear (0-1)
	settings_config.set_value("audio", "master_volume", db_to_linear(AudioServer.get_bus_volume_db(master_idx)))
	settings_config.set_value("audio", "music_volume", db_to_linear(AudioServer.get_bus_volume_db(music_idx)))
	settings_config.set_value("audio", "sfx_volume", db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)))
	settings_config.set_value("audio", "dialog_volume", db_to_linear(AudioServer.get_bus_volume_db(dialog_idx)))
	
	# Display settings are already saved when changed via set_fullscreen, set_resolution, etc.
	
	# Save to file
	var err = settings_config.save(SETTINGS_FILE_PATH)
	if err == OK:
		print("⚙️ Settings saved!")
		settings_saved.emit()
	else:
		print("⚠️ Failed to save settings!")

## Get a setting value
func get_setting(section: String, key: String, default_value = null):
	return settings_config.get_value(section, key, default_value)

## Set a setting value
func set_setting(section: String, key: String, value):
	settings_config.set_value(section, key, value)

## Apply display settings (called after load)
func _apply_display_settings():
	var fullscreen = settings_config.get_value("display", "fullscreen", DEFAULT_SETTINGS.display.fullscreen)
	var vsync = settings_config.get_value("display", "vsync", DEFAULT_SETTINGS.display.vsync)
	var res_width = settings_config.get_value("display", "resolution_width", DEFAULT_SETTINGS.display.resolution_width)
	var res_height = settings_config.get_value("display", "resolution_height", DEFAULT_SETTINGS.display.resolution_height)
	
	# Set vsync first
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# Set window mode and size
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		# First switch to windowed mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		# Then set the size
		await get_tree().process_frame
		DisplayServer.window_set_size(Vector2i(res_width, res_height))
		# Center the window
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - Vector2i(res_width, res_height)) / 2
		DisplayServer.window_set_position(window_pos)
	
	print("⚙️ Applied display settings - Fullscreen: %s, Resolution: %dx%d, VSync: %s" % [
		"On" if fullscreen else "Off", res_width, res_height, "On" if vsync else "Off"
	])

## Force apply display settings to override project.godot
func _force_apply_display_settings():
	var fullscreen = settings_config.get_value("display", "fullscreen", DEFAULT_SETTINGS.display.fullscreen)
	var vsync = settings_config.get_value("display", "vsync", DEFAULT_SETTINGS.display.vsync)
	var res_width = settings_config.get_value("display", "resolution_width", DEFAULT_SETTINGS.display.resolution_width)
	var res_height = settings_config.get_value("display", "resolution_height", DEFAULT_SETTINGS.display.resolution_height)
	
	var current_mode = DisplayServer.window_get_mode()
	print("⚙️ Current window mode: %d, forcing display settings override..." % current_mode)
	
	# Force vsync setting
	if vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	
	# IMPORTANT: Handle maximized window state
	if current_mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		# Must exit maximized before we can change size
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().process_frame
	
	# Force window mode - always start from windowed to ensure proper sizing
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	await get_tree().process_frame
	
	# Set the saved resolution
	DisplayServer.window_set_size(Vector2i(res_width, res_height))
	
	# Center window
	var screen_size = DisplayServer.screen_get_size()
	var window_pos = (screen_size - Vector2i(res_width, res_height)) / 2
	DisplayServer.window_set_position(window_pos)
	
	await get_tree().process_frame
	
	# Now apply the actual window mode
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		print("⚙️ Forced to borderless fullscreen mode")
	else:
		# Ensure we stay in windowed mode (not maximized)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("⚙️ Forced to windowed mode: %dx%d" % [res_width, res_height])

## Apply loaded settings to the game (audio only, display handled separately)
func _apply_loaded_settings():
	# Apply audio settings
	var master_volume = settings_config.get_value("audio", "master_volume", DEFAULT_SETTINGS.audio.master_volume)
	var music_volume = settings_config.get_value("audio", "music_volume", DEFAULT_SETTINGS.audio.music_volume)
	var sfx_volume = settings_config.get_value("audio", "sfx_volume", DEFAULT_SETTINGS.audio.sfx_volume)
	var dialog_volume = settings_config.get_value("audio", "dialog_volume", DEFAULT_SETTINGS.audio.dialog_volume)
	
	# Set audio bus volumes
	var master_idx = AudioServer.get_bus_index("Master")
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	var dialog_idx = AudioServer.get_bus_index("Dialog")
	
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_volume))
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))
	if dialog_idx >= 0:
		AudioServer.set_bus_volume_db(dialog_idx, linear_to_db(dialog_volume))
	
	print("⚙️ Applied audio settings - Master: %.0f%%, Music: %.0f%%, SFX: %.0f%%, Dialog: %.0f%%" % [
		master_volume * 100, music_volume * 100, sfx_volume * 100, dialog_volume * 100
	])
	
	# Display settings are now handled in _ready() with force apply

## Create default settings
func _create_default_settings():
	for section in DEFAULT_SETTINGS:
		for key in DEFAULT_SETTINGS[section]:
			settings_config.set_value(section, key, DEFAULT_SETTINGS[section][key])

## Save audio settings specifically
func save_audio_settings():
	save_settings()  # For now just save all settings

## Get Twitch channel name
func get_twitch_channel() -> String:
	return settings_config.get_value("twitch", "channel_name", DEFAULT_SETTINGS.twitch.channel_name)

## Set Twitch channel name and save
func set_twitch_channel(channel_name: String):
	settings_config.set_value("twitch", "channel_name", channel_name)
	save_settings()
	print("⚙️ Twitch channel saved: %s" % channel_name)

## Set display settings
func set_fullscreen(enabled: bool):
	settings_config.set_value("display", "fullscreen", enabled)
	save_settings()
	
	var current_mode = DisplayServer.window_get_mode()
	
	# Exit maximized if needed
	if current_mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().process_frame
	
	if enabled:
		# Use exclusive fullscreen (borderless window)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		print("⚙️ Switched to borderless fullscreen mode")
	else:
		# Switch to windowed mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().process_frame
		
		# Apply the saved resolution
		var res_width = settings_config.get_value("display", "resolution_width", DEFAULT_SETTINGS.display.resolution_width)
		var res_height = settings_config.get_value("display", "resolution_height", DEFAULT_SETTINGS.display.resolution_height)
		DisplayServer.window_set_size(Vector2i(res_width, res_height))
		
		# Center the window
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - Vector2i(res_width, res_height)) / 2
		DisplayServer.window_set_position(window_pos)
		print("⚙️ Switched to windowed mode: %dx%d" % [res_width, res_height])

func set_resolution(width: int, height: int):
	settings_config.set_value("display", "resolution_width", width)
	settings_config.set_value("display", "resolution_height", height)
	save_settings()
	
	# Check current window mode
	var current_mode = DisplayServer.window_get_mode()
	
	# Always handle maximized state first
	if current_mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().process_frame
		current_mode = DisplayServer.WINDOW_MODE_WINDOWED
	
	if current_mode == DisplayServer.WINDOW_MODE_WINDOWED:
		# Apply resolution in windowed mode
		DisplayServer.window_set_size(Vector2i(width, height))
		# Center the window
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - Vector2i(width, height)) / 2
		DisplayServer.window_set_position(window_pos)
		print("⚙️ Resolution changed to: %dx%d" % [width, height])
	elif current_mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN or current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		# In fullscreen/borderless, temporarily switch to windowed to apply resolution
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		await get_tree().process_frame
		DisplayServer.window_set_size(Vector2i(width, height))
		# Center before going back to fullscreen
		var screen_size = DisplayServer.screen_get_size()
		var window_pos = (screen_size - Vector2i(width, height)) / 2
		DisplayServer.window_set_position(window_pos)
		await get_tree().process_frame
		# Switch back to borderless
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		print("⚙️ Resolution changed to: %dx%d (borderless)" % [width, height])
	else:
		print("⚙️ Resolution saved: %dx%d" % [width, height])

func set_vsync(enabled: bool):
	settings_config.set_value("display", "vsync", enabled)
	save_settings()
	
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
		print("⚙️ VSync enabled")
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		print("⚙️ VSync disabled")

## Reset to default settings
func reset_to_defaults():
	_create_default_settings()
	save_settings()
	_apply_loaded_settings()
	print("⚙️ Settings reset to defaults!")
