class_name ResourceManager
extends Node

## Centralized resource loading and caching system
## Singleton that manages game resources efficiently

static var instance: ResourceManager

# Resource caches
var _scene_cache: Dictionary = {}
var _texture_cache: Dictionary = {}
var _audio_cache: Dictionary = {}
var _shader_cache: Dictionary = {}

# Background music player
var background_music_player: AudioStreamPlayer

# Common resource paths
const SCENES = {
	"xp_orb": "res://entities/pickups/xp_orb.tscn",
	"health_orb": "res://entities/pickups/health_orb.tscn",
	"damage_number": "res://ui/damage_number.tscn",
	# Legacy rat scene kept for tools only; spawning is handled by EnemyManager
	# "twitch_rat": "res://entities/enemies/twitch_rat.tscn",
	"succubus": "res://entities/enemies/succubus.tscn",
	"thor": "res://entities/enemies/bosses/thor/thor_enemy.tscn",
	"explosion_effect": "res://entities/effects/explosion.tscn",
	"poison_cloud": "res://entities/effects/poison_cloud.tscn",
	"projectile": "res://entities/projectiles/projectile.tscn"
}

func _ready() -> void:
	if instance:
		queue_free()
		return
	instance = self
	
	# Preload common resources
	_preload_common_resources()

func _preload_common_resources() -> void:
	# Preload frequently used scenes
	for key in ["xp_orb", "health_orb", "damage_number"]:
		if SCENES.has(key):
			load_scene(SCENES[key])

## Load a scene with caching
static func load_scene(path: String) -> PackedScene:
	if not instance:
		push_error("ResourceManager: Instance not initialized")
		return null
	
	if instance._scene_cache.has(path):
		return instance._scene_cache[path]
	
	var scene = load(path) as PackedScene
	if scene:
		instance._scene_cache[path] = scene
	else:
		push_error("ResourceManager: Failed to load scene: " + path)
	
	return scene

## Load a texture with caching
static func load_texture(path: String) -> Texture2D:
	if not instance:
		push_error("ResourceManager: Instance not initialized")
		return null
	
	if instance._texture_cache.has(path):
		return instance._texture_cache[path]
	
	var texture = load(path) as Texture2D
	if texture:
		instance._texture_cache[path] = texture
	else:
		push_error("ResourceManager: Failed to load texture: " + path)
	
	return texture

## Load audio with caching
static func load_audio(path: String) -> AudioStream:
	if not instance:
		push_error("ResourceManager: Instance not initialized")
		return null
	
	if instance._audio_cache.has(path):
		return instance._audio_cache[path]
	
	var audio = load(path) as AudioStream
	if audio:
		instance._audio_cache[path] = audio
	else:
		push_error("ResourceManager: Failed to load audio: " + path)
	
	return audio

## Load shader with caching
static func load_shader(path: String) -> Shader:
	if not instance:
		push_error("ResourceManager: Instance not initialized")
		return null
	
	if instance._shader_cache.has(path):
		return instance._shader_cache[path]
	
	var shader = load(path) as Shader
	if shader:
		instance._shader_cache[path] = shader
	else:
		push_error("ResourceManager: Failed to load shader: " + path)
	
	return shader

## Instantiate a scene from cache or load it
static func instantiate_scene(scene_key: String) -> Node:
	if not instance:
		push_error("ResourceManager: Instance not initialized")
		return null
	
	var path = SCENES.get(scene_key, scene_key)
	var scene = load_scene(path)
	
	if scene:
		return scene.instantiate()
	
	return null

## Spawn an entity at position
static func spawn_entity(scene_key: String, parent: Node, position: Vector2) -> Node:
	var entity = instantiate_scene(scene_key)
	if entity:
		entity.global_position = position
		parent.add_child(entity)
	return entity





## Setup background music
static func setup_background_music(parent: Node) -> AudioStreamPlayer:
	if not instance:
		push_error("ResourceManager: Instance not initialized")
		return null
	
	if instance.background_music_player:
		push_warning("ResourceManager: Background music already setup")
		return instance.background_music_player
	
	instance.background_music_player = AudioStreamPlayer.new()
	instance.background_music_player.name = "BackgroundMusic"
	instance.background_music_player.volume_db = -6.0
	instance.background_music_player.bus = "Music"
	instance.background_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(instance.background_music_player)
	
	var music_stream = preload("res://music/Rats_in_the_Rain_Deaux.mp3")
	instance.background_music_player.stream = music_stream
	
	if music_stream is AudioStreamMP3:
		music_stream.loop = true
	
	instance.background_music_player.play()
	print("🎵 Background music started")
	return instance.background_music_player

## Get background music player
static func get_background_music_player() -> AudioStreamPlayer:
	if not instance:
		return null
	return instance.background_music_player

## Control background music
static func set_music_volume(volume_db: float):
	if instance and instance.background_music_player:
		instance.background_music_player.volume_db = volume_db

static func pause_music():
	if instance and instance.background_music_player:
		instance.background_music_player.stream_paused = true

static func resume_music():
	if instance and instance.background_music_player:
		instance.background_music_player.stream_paused = false

static func stop_music():
	if instance and instance.background_music_player:
		instance.background_music_player.stop()
