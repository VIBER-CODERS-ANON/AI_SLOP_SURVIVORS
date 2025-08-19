extends Resource
class_name BossConfig

## Configuration resource for boss definitions

@export var id: String = ""
@export var name: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

# Visual assets
@export var sprite_texture: Texture2D
@export var sprite_frames: SpriteFrames
@export var icon_texture: Texture2D

# Basic stats
@export_group("Stats")
@export var base_health: float = 100.0
@export var base_damage: float = 10.0
@export var move_speed: float = 50.0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 2.0
@export var collision_radius: float = 25.0

# Spawn settings
@export_group("Spawn Settings")
@export var rarity: String = "common"
@export var spawn_weight: float = 1.0
@export var max_spawns_per_session: int = 1
@export var required_mxp_threshold: int = 0
@export var min_player_level: int = 1

# Visual effects
@export_group("Visual Effects")
@export var scale_multiplier: float = 1.0
@export var color_tint: Color = Color.WHITE
@export var glow_effect: bool = false
@export var particle_effect: String = ""
@export var spawn_effect_color: Color = Color.WHITE

# Audio
@export_group("Audio")
@export var spawn_sound: AudioStream
@export var death_sound: AudioStream
@export var attack_sound: AudioStream
@export var hurt_sound: AudioStream

# AI Behavior
@export_group("AI Behavior")
@export var ai_type: String = "aggressive"
@export var charge_distance: float = 200.0
@export var retreat_distance: float = 50.0
@export var aggro_range: float = 300.0
@export var special_behavior: String = ""

# Rewards
@export_group("Rewards")
@export var xp_multiplier: float = 2.0
@export var mxp_bonus: int = 5
@export var special_drops: Array[String] = []

# Abilities (will be expanded)
@export_group("Abilities")
@export var ability_configs: Array[BossAbilityConfig] = []

# Tags for categorization
@export var tags: Array[String] = []

func get_spawn_position_near_player(player_position: Vector2, min_distance: float = 200.0, max_distance: float = 400.0) -> Vector2:
	var angle = randf() * TAU
	var distance = randf_range(min_distance, max_distance)
	return player_position + Vector2(cos(angle), sin(angle)) * distance

func get_rarity_color() -> Color:
	match rarity.to_lower():
		"common": return Color.GRAY
		"uncommon": return Color.GREEN
		"rare": return Color.BLUE
		"epic": return Color.PURPLE
		"legendary": return Color.GOLD
		"unique": return Color.RED
		_: return Color.WHITE

func is_spawn_allowed(current_session_spawns: int, player_level: int, available_mxp: int) -> bool:
	if current_session_spawns >= max_spawns_per_session:
		return false
	if player_level < min_player_level:
		return false
	if available_mxp < required_mxp_threshold:
		return false
	return true