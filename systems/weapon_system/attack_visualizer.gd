extends Node2D
class_name AttackVisualizer

## Draws a huge red "cheese slice" to show attack area

@export var enabled: bool = true
@export var wedge_radius: float = 150.0
@export var wedge_angle: float = 90.0  # Total angle of the wedge in degrees
@export var fade_time: float = 0.3
@export var hit_window_duration: float = 0.18

var current_alpha: float = 0.0
var target_alpha: float = 0.0
var attack_direction: float = 0.0  # Direction of attack in radians
var hit_window_timer: float = 0.0
var sword_weapon: Area2D
var weapon_wedge: CollisionPolygon2D

func _ready():
	z_index = 100  # Draw on top of everything
	set_process(true)
	set_physics_process(true)
	sword_weapon = get_node_or_null("SwordWeapon")
	if not sword_weapon:
		sword_weapon = get_node_or_null("../SwordWeapon")
	if sword_weapon:
		weapon_wedge = sword_weapon.get_node_or_null("HitWedge")

func show_attack(direction: float):
	if not enabled:
		return
	
	attack_direction = direction
	global_rotation = 0.0
	global_position = get_parent().global_position
	target_alpha = 0.8
	if weapon_wedge:
		_update_weapon_wedge()
	if sword_weapon and sword_weapon.has_method("set_active"):
		sword_weapon.position = Vector2.ZERO
		sword_weapon.rotation = attack_direction
		if sword_weapon.has_method("reset_hit_list"):
			sword_weapon.reset_hit_list()
		sword_weapon.set_active(true)
		hit_window_timer = hit_window_duration
		# First sweep immediately; subsequent sweeps happen in _physics_process
		if sword_weapon.has_method("sweep_overlap"):
			sword_weapon.sweep_overlap()
	queue_redraw()

func _process(_delta):
	# Fade animation
	if abs(current_alpha - target_alpha) > 0.01:
		current_alpha = lerp(current_alpha, target_alpha, _delta * 10.0)
		queue_redraw()
	elif target_alpha > 0:
		target_alpha = 0.0  # Start fading out
	
	# Hide when fully faded
	if current_alpha < 0.01:
		current_alpha = 0.0
		queue_redraw()

	# Timer handled in _physics_process to align with collision updates

func _draw():
	if current_alpha <= 0:
		return
	
	# Draw a wedge/pie slice shape
	var points = PackedVector2Array()
	var colors = PackedColorArray()
	
	# Add center point
	points.append(Vector2.ZERO)
	colors.append(Color(1.5, 0, 0, current_alpha))  # Bright red with current alpha
	
	# Calculate wedge points
	var half_angle = deg_to_rad(wedge_angle) / 2.0
	var segments = 20  # Number of segments for smooth curve
	
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = attack_direction - half_angle + (deg_to_rad(wedge_angle) * t)
		var point = Vector2(cos(angle), sin(angle)) * wedge_radius
		points.append(point)
		
		# Gradient effect - darker at edges
		var edge_alpha = current_alpha * (0.6 + 0.4 * (1.0 - abs(t - 0.5) * 2.0))
		colors.append(Color(1.5, 0.2, 0, edge_alpha))  # Bright red-orange gradient
	
	# Draw the filled wedge
	if points.size() > 2:
		# Create triangles from center to each edge segment
		for i in range(1, points.size() - 1):
			draw_polygon(PackedVector2Array([points[0], points[i], points[i + 1]]), 
						PackedColorArray([colors[0], colors[i], colors[i + 1]]))
		
		# Draw outline for clarity
		var outline_color = Color(1.5, 1, 0, current_alpha)  # Bright yellow outline
		for i in range(1, points.size()):
			draw_line(points[0], points[i], outline_color, 5.0)
		
		# Draw arc
		for i in range(1, points.size() - 1):
			draw_line(points[i], points[i + 1], outline_color, 5.0)
		
		# Draw "ATTACK!" text in the middle
		if current_alpha > 0.5:
			var font = ThemeDB.fallback_font
			var text = "SLICE!"
			var text_pos = Vector2(cos(attack_direction), sin(attack_direction)) * wedge_radius * 0.5
			draw_string(font, text_pos - Vector2(30, -10), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 24, Color(1, 1, 1, current_alpha))

func _update_weapon_wedge():
	if not weapon_wedge:
		return
	var half_angle = deg_to_rad(wedge_angle) / 2.0
	var segments = 20
	var pts = PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = -half_angle + (deg_to_rad(wedge_angle) * t)
		var point = Vector2(cos(angle), sin(angle)) * wedge_radius
		pts.append(point)
	weapon_wedge.polygon = pts

func _physics_process(_delta: float) -> void:
	if hit_window_timer > 0.0 and sword_weapon:
		# Sweep overlaps every physics frame to ensure damage even if enemies are already inside
		if sword_weapon.has_method("sweep_overlap"):
			sword_weapon.sweep_overlap()
		hit_window_timer -= _delta
		if hit_window_timer <= 0.0 and sword_weapon.has_method("set_active"):
			sword_weapon.set_active(false)
