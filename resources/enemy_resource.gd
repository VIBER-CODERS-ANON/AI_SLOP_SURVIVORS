extends Resource
class_name EnemyResource

@export var enemy_id: String = ""
@export var display_name: String = ""
@export_enum("minion", "boss") var enemy_category: String = "minion"

# Base Stats
@export_group("Base Stats")
@export var base_health: float = 10.0
@export var base_speed: float = 50.0
@export var base_damage: float = 5.0
@export var base_scale: float = 1.0
@export var xp_value: int = 1
@export var mxp_value: int = 1

# Visual Configuration
@export_group("Visual Configuration")
@export var sprite_texture: Texture2D
@export var sprite_frames: SpriteFrames  # For animated enemies
@export var multimesh_scene: PackedScene  # For minions
@export var node_scene: PackedScene       # For bosses

# Behavior Configuration
@export_group("Behavior Configuration")
@export_enum("basic_chase", "ranged", "complex") var ai_type: String = "basic_chase"
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.0

# Abilities
@export_group("Abilities")
@export var abilities: Array[Resource] = []  # Array of AbilityResource
@export var passive_abilities: Array[String] = []

# Special Properties
@export_group("Special Properties")
@export var can_evolve: bool = false
@export var evolution_targets: Array[String] = []
@export var spawn_weight: int = 100  # For ticket system

# Additional boss-specific properties
@export_group("Boss Properties")
@export var boss_tier: int = 1
@export var boss_music: AudioStream
@export var death_dialogue: Array[String] = []