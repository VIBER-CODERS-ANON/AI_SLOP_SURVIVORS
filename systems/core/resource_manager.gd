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

# Common resource paths
const SCENES = {
	"xp_orb": "res://entities/pickups/xp_orb.tscn",
	"health_orb": "res://entities/pickups/health_orb.tscn",
	"damage_number": "res://ui/damage_number.tscn",
	# Legacy rat scene kept for tools only; spawning is handled by EnemyManager
	# "twitch_rat": "res://entities/enemies/twitch_rat.tscn",
	"succubus": "res://entities/enemies/succubus.tscn",
	"thor": "res://entities/enemies/thor.tscn",
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

## Spawn multiple entities efficiently
static func spawn_entities_batch(scene_key: String, parent: Node, positions: Array) -> Array:
	var entities = []
	var scene = load_scene(SCENES.get(scene_key, scene_key))
	
	if not scene:
		return entities
	
	for pos in positions:
		var entity = scene.instantiate()
		entity.global_position = pos
		parent.add_child(entity)
		entities.append(entity)
	
	return entities

## Clear specific cache
static func clear_cache(cache_type: String = "all") -> void:
	if not instance:
		return
	
	match cache_type:
		"scenes":
			instance._scene_cache.clear()
		"textures":
			instance._texture_cache.clear()
		"audio":
			instance._audio_cache.clear()
		"shaders":
			instance._shader_cache.clear()
		"all":
			instance._scene_cache.clear()
			instance._texture_cache.clear()
			instance._audio_cache.clear()
			instance._shader_cache.clear()

## Get cache size info
static func get_cache_info() -> Dictionary:
	if not instance:
		return {}
	
	return {
		"scenes": instance._scene_cache.size(),
		"textures": instance._texture_cache.size(),
		"audio": instance._audio_cache.size(),
		"shaders": instance._shader_cache.size()
	}

## Preload resources for a specific game state
static func preload_for_state(state: String) -> void:
	if not instance:
		return
	
	match state:
		"combat":
			# Preload combat resources
			load_scene(SCENES["damage_number"])
			load_scene(SCENES["explosion_effect"])
		"boss_fight":
			# Preload boss resources
			load_scene(SCENES["thor"])
			load_scene(SCENES["succubus"])
		"wave":
			# Preload wave resources
			load_scene(SCENES["twitch_rat"])
			load_scene(SCENES["xp_orb"])
