extends Resource
class_name BossAbilityConfig

## Configuration for individual boss abilities

@export var ability_id: String = ""
@export var ability_name: String = ""
@export_multiline var description: String = ""

@export_group("Timing")
@export var cooldown: float = 5.0
@export var cast_time: float = 0.0
@export var duration: float = 0.0

@export_group("Damage & Effects")
@export var damage_multiplier: float = 1.0
@export var base_damage: float = 0.0
@export var damage_type: String = "physical"
@export var status_effects: Array[String] = []

@export_group("Area & Range")
@export var range: float = 100.0
@export var aoe_radius: float = 0.0
@export var projectile_speed: float = 0.0
@export var projectile_count: int = 1

@export_group("Behavior")
@export var target_type: String = "player"  # player, nearest_enemy, area, self
@export var trigger_condition: String = "cooldown"  # cooldown, health_threshold, distance
@export var trigger_value: float = 0.0

@export_group("Visual & Audio")
@export var cast_effect: String = ""
@export var impact_effect: String = ""
@export var cast_sound: AudioStream
@export var impact_sound: AudioStream
@export var effect_color: Color = Color.WHITE

# Special ability parameters (flexible key-value pairs)
@export var custom_parameters: Dictionary = {}

func get_parameter(key: String, default_value = null):
	return custom_parameters.get(key, default_value)

func set_parameter(key: String, value):
	custom_parameters[key] = value