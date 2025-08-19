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
	"twitch": {
		"channel_name": "quin69"
	}
}

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Load settings on startup
	load_settings()
	
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

## Apply loaded settings to the game
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

## Reset to default settings
func reset_to_defaults():
	_create_default_settings()
	save_settings()
	_apply_loaded_settings()
	print("⚙️ Settings reset to defaults!")
