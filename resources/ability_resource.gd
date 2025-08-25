extends Resource
class_name AbilityResource

@export var ability_id: String = ""
@export var display_name: String = ""
@export var description: String = ""

# Ability Configuration
@export_group("Ability Configuration")
@export var cooldown: float = 5.0
@export var damage: float = 20.0
@export var ability_range: float = 100.0
@export var duration: float = 0.0  # Duration of ability effect (buffs: effect duration, projectiles: projectile lifetime, channeled: channel duration)

# Trigger Configuration
@export_group("Trigger Configuration")
@export_enum("instant", "channeled", "projectile", "area", "passive") var trigger_type: String = "instant"
@export var cast_time: float = 0.0  # For channeled abilities
@export var windup_duration: float = 0.0  # Delay before ability takes effect (projectiles: windup before firing, channeled: cast time)

# Projectile Configuration (only used when trigger_type = "projectile")
@export_group("Projectile Configuration")
@export var projectile_speed: float = 300.0
@export var projectile_texture: Texture2D  # Simple sprite-based projectiles (alternative to effect_scene)
@export var projectile_collision_radius: float = 5.0  # Collision size for sprite projectiles
@export var projectile_scale: Vector2 = Vector2.ONE  # Scale for sprite projectiles

# Visual Effects
@export_group("Visual Effects")
@export var effect_scene: PackedScene
@export var impact_scene: PackedScene
@export var cast_animation: String = ""
@export var sound_effect: AudioStream

# Advanced Configuration
@export_group("Advanced Configuration")
@export var custom_script: Script  # For complex abilities requiring custom logic
@export var additional_parameters: Dictionary = {}  # For storing ability-specific data
