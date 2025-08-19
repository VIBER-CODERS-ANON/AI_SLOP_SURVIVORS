@tool
class_name TileResource
extends Resource

## Represents a single tile's data and properties in our dark dungeon system
## This resource holds all the visual and gameplay data for a tile

enum TileType {
	FLOOR_STONE,
	FLOOR_BLOOD,
	FLOOR_GORE,
	WALL_STONE,
	WALL_CRACKED,
	PIT,
	LAVA,
	DEBRIS,
	SPECIAL
}

enum TileLayer {
	BASE = 0,
	OVERLAY = 1,
	EFFECTS = 2,
	PARTICLES = 3
}

@export var tile_id: String = ""
@export var tile_type: TileType = TileType.FLOOR_STONE
@export var tile_name: String = "Unknown Tile"
@export var texture: Texture2D
@export var collision_enabled: bool = false
@export var walkable: bool = true
@export var hazardous: bool = false
@export var damage_per_second: float = 0.0
@export var movement_speed_modifier: float = 1.0

## Visual properties for atmospheric effects
@export_group("Visual Properties")
@export var emission_color: Color = Color.BLACK
@export var emission_strength: float = 0.0
@export var particle_scene: PackedScene
@export var ambient_sound: AudioStream
@export var footstep_sound: AudioStream

## Procedural generation weights
@export_group("Generation Properties")
@export var generation_weight: float = 1.0
@export var min_cluster_size: int = 1
@export var max_cluster_size: int = 5
@export var allowed_neighbors: Array[TileType] = []
@export var forbidden_neighbors: Array[TileType] = []

## Gameplay modifiers
@export_group("Gameplay Modifiers")
@export var spawn_chance_modifier: float = 1.0
@export var loot_chance_modifier: float = 1.0
@export var visibility_modifier: float = 1.0

func _init(p_tile_id: String = "", p_type: TileType = TileType.FLOOR_STONE) -> void:
	tile_id = p_tile_id
	tile_type = p_type
	
	# Set default properties based on type
	match tile_type:
		TileType.FLOOR_BLOOD:
			tile_name = "Blood-Soaked Floor"
			hazardous = false
			movement_speed_modifier = 0.9
			emission_color = Color(0.3, 0.0, 0.0)
			emission_strength = 0.1
		TileType.FLOOR_GORE:
			tile_name = "Gore-Covered Floor"
			hazardous = true
			damage_per_second = 1.0
			movement_speed_modifier = 0.7
			emission_color = Color(0.5, 0.0, 0.0)
			emission_strength = 0.2
		TileType.WALL_STONE:
			tile_name = "Stone Wall"
			collision_enabled = true
			walkable = false
		TileType.PIT:
			tile_name = "Bottomless Pit"
			collision_enabled = false
			walkable = false
			hazardous = true
			damage_per_second = 999.0
		TileType.LAVA:
			tile_name = "Molten Lava"
			hazardous = true
			damage_per_second = 10.0
			movement_speed_modifier = 0.5
			emission_color = Color(1.0, 0.3, 0.0)
			emission_strength = 0.8

func get_full_tile_data() -> Dictionary:
	return {
		"id": tile_id,
		"type": tile_type,
		"name": tile_name,
		"walkable": walkable,
		"hazardous": hazardous,
		"damage": damage_per_second,
		"speed_mod": movement_speed_modifier,
		"visual": {
			"emission_color": emission_color,
			"emission_strength": emission_strength,
			"has_particles": particle_scene != null
		}
	}