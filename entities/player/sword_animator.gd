extends Node2D
class_name SwordAnimator

## Animates the sword with a better swinging pattern

@export var swing_speed: float = 10.0
@export var swing_arc: float = 240.0  # Much larger arc for better coverage
@export var sword_distance: float = 60.0  # Halved for smaller sword
@export var enabled: bool = true  # Enable animation

var time: float = 0.0
var sword_sprite: Sprite2D
var sword_hitbox: Area2D

func _ready():
	# Get the sword sprite - SwordAnimator is sibling to SpriteContainer
	sword_sprite = get_node_or_null("../SpriteContainer/Sword")
	if not sword_sprite:
	else:
	
	# Get the sword hitbox
	sword_hitbox = get_node_or_null("../SwordHitbox")
	if not sword_hitbox:
	else:

func _process(_delta):
	if not sword_sprite or not enabled:
		return

	time += _delta * swing_speed

	# Calculate swing progress using a sine wave for smoother motion
	var swing_cycle = fmod(time, TAU) / TAU  # 0 to 1
	var swing_progress = sin(swing_cycle * TAU)  # -1 to 1

	# Aim towards the mouse and swing around that aim direction
	var player_global_pos = get_parent().global_position
	var aim_angle = (get_global_mouse_position() - player_global_pos).angle()
	var angle_offset = swing_progress * deg_to_rad(swing_arc * 0.5)
	var current_angle = aim_angle + angle_offset

	# Add forward thrust motion
	var thrust_amount = abs(swing_progress) * 0.3 + 0.7  # 0.7 to 1.0
	var actual_distance = sword_distance * thrust_amount

	# Position sword with improved arc
	var x = cos(current_angle) * actual_distance
	var y = sin(current_angle) * actual_distance
	sword_sprite.position = Vector2(x, y)

	# Rotate sword to point outward from swing center
	sword_sprite.rotation = current_angle + deg_to_rad(90) + deg_to_rad(45)  # Added 45 degree clockwise rotation

	# Ensure positive scale so rotation/hitbox aren't mirrored
	sword_sprite.scale = Vector2(0.125, 0.125)  # Halved for smaller sword
	
	# Update sword hitbox to match sword rotation
	if sword_hitbox:
		sword_hitbox.rotation = current_angle
