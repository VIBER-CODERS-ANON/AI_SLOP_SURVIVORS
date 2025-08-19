extends LightSource

class_name PlayerLight

## Special light source attached to the player character
## Features dynamic effects based on player state and actions

@export_group("Player Light Settings")
@export var base_radius: float = 1200.0
@export var combat_radius_multiplier: float = 1.2
@export var sprint_radius_multiplier: float = 0.8
@export var low_health_pulse_speed: float = 2.0
@export var damage_flash_intensity: float = 2.5

@export_group("Movement Effects")
@export var enable_movement_sway: bool = true
@export var sway_intensity: float = 0.05
@export var sway_speed: float = 2.0
@export var bob_intensity: float = 0.02
@export var bob_speed: float = 4.0

@export_group("Color Settings")
@export var normal_color: Color = Color(1.0, 0.95, 0.8, 1.0)  # Warm yellow-white
@export var combat_color: Color = Color(1.0, 0.8, 0.7, 1.0)   # Reddish tint
@export var low_health_color: Color = Color(1.0, 0.5, 0.5, 1.0) # Red warning

# State tracking
var player_node: CharacterBody2D = null
var is_in_combat: bool = false
var is_sprinting: bool = false
var player_velocity: Vector2 = Vector2.ZERO
var health_percentage: float = 1.0
var movement_offset: Vector2 = Vector2.ZERO

# Effect timers
var damage_flash_timer: float = 0.0
var combat_transition_timer: float = 0.0

func _ready() -> void:
	# Set base properties
	base_energy = 1.2
	base_color = normal_color
	base_scale = base_radius / 256.0  # Assuming 256px base texture size
	range_scale = 1.0
	
	# Shadow settings for player
	cast_shadows = true
	shadow_color = Color(0, 0, 0, 0.7)
	
	super._ready()
	
	# Find player node
	player_node = get_parent() as CharacterBody2D

func _apply_effects(delta: float) -> void:
	if not player_node:
		return
	
	# Update player state
	_update_player_state()
	
	# Apply movement effects
	if enable_movement_sway and player_velocity.length() > 10:
		_apply_movement_effects()
	
	# Apply combat effects
	if is_in_combat:
		_apply_combat_effects(delta)
	
	# Apply health-based effects
	# DISABLED: Low health lighting effects
	# if health_percentage < 0.3:
	# 	_apply_low_health_effects()
	
	# Handle damage flash
	# DISABLED: Damage flash lighting effects
	# if damage_flash_timer > 0:
	# 	damage_flash_timer -= delta
	# 	var flash_intensity = (damage_flash_timer / 0.3) * damage_flash_intensity
	# 	current_energy = base_energy * (1.0 + flash_intensity)
	
	# Smooth color transitions
	_update_light_color(delta)

func _update_player_state() -> void:
	if not player_node:
		return
	
	# Get velocity
	player_velocity = player_node.velocity
	
	# Check if player has a health component
	if player_node.has_method("get_health_percentage"):
		health_percentage = player_node.get_health_percentage()
	
	# Check combat state (you'll need to implement this in player.gd)
	if player_node.has_method("is_in_combat"):
		is_in_combat = player_node.is_in_combat()
	
	# Check sprint state
	if player_node.has_method("is_sprinting"):
		is_sprinting = player_node.is_sprinting()

func _apply_movement_effects() -> void:
	# Calculate sway based on horizontal movement
	var sway_offset = sin(effect_time * sway_speed) * sway_intensity * sign(player_velocity.x)
	
	# Calculate bob based on movement speed
	var bob_offset = sin(effect_time * bob_speed) * bob_intensity * player_velocity.length() / 200.0
	
	# Apply offsets
	movement_offset.x = sway_offset * 20.0
	movement_offset.y = bob_offset * 10.0
	
	if light_node:
		light_node.position = movement_offset

func _apply_combat_effects(delta: float) -> void:
	# DISABLED: Combat pulse effect
	# pulse(1.5, 0.1)
	
	# Increase radius
	var target_scale = (base_radius * combat_radius_multiplier) / 256.0
	current_scale = lerp(current_scale, target_scale, delta * 2.0)

func _apply_low_health_effects() -> void:
	# DISABLED: Low health pulse effects
	# var pulse_speed = low_health_pulse_speed * (1.0 + (1.0 - health_percentage))
	# pulse(pulse_speed, 0.3)
	pass

func _update_light_color(delta: float) -> void:
	var target_color = normal_color
	
	# DISABLED: Low health color change
	# if health_percentage < 0.3:
	# 	target_color = low_health_color
	if is_in_combat:
		target_color = combat_color
	
	current_color = current_color.lerp(target_color, delta * 3.0)

func trigger_damage_flash() -> void:
	# DISABLED: Damage flash effects
	# damage_flash_timer = 0.3
	# flash(damage_flash_intensity, 0.1)
	pass

func set_combat_mode(enabled: bool) -> void:
	is_in_combat = enabled
	combat_transition_timer = 1.0

func update_from_player_stats(stats: Dictionary) -> void:
	# Update light based on player stats/equipment
	if "light_radius_bonus" in stats:
		range_scale = 1.0 + stats.light_radius_bonus
	
	if "light_intensity_bonus" in stats:
		base_energy = 1.2 + stats.light_intensity_bonus
	
	_update_light()

# Special ability effects
func activate_light_burst(radius_multiplier: float = 2.0, duration: float = 0.5) -> void:
	var original_scale = current_scale
	var tween = create_tween()
	tween.tween_property(self, "current_scale", original_scale * radius_multiplier, duration * 0.2)
	tween.tween_property(self, "current_scale", original_scale, duration * 0.8)
	
	# Also flash energy
	flash(1.5, duration)

func dim_for_stealth(dim_factor: float = 0.3, duration: float = 0.5) -> void:
	fade_to(base_energy * dim_factor, duration)
