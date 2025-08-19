extends Area2D
class_name Weapon

## Base weapon class that can deal damage to enemies

signal hit_enemy(enemy: Node)

@export var damage: float = 10.0
@export var weapon_tags: Array[String] = ["Melee"]
@export var knockback_force: float = 200.0
@export var active_by_default: bool = false

var owner_entity: BaseEntity
var enemies_hit_this_swing: Array = []
var show_attack_debug: bool = false
var attack_debug_timer: float = 0.0

func _ready():
	# Set up collision
	collision_layer = 4  # Weapon layer (layer 3 = bit 2 = value 4)
	collision_mask = 2   # Only detect enemies (layer 2 = bit 1 = value 2)
	
	# Connect area signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Add to weapons group
	add_to_group("weapons")
	
	# Enable drawing for debug
	if show_attack_debug:
		set_process(true)

	# Weapons are usually active only during attack windows
	_set_active_internal(active_by_default)

func _on_area_entered(area: Area2D):
	# Check if it's an enemy
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage") and parent.is_in_group("enemies"):
			_hit_enemy(parent)

func _on_body_entered(body: Node2D):
	# Check if it's an enemy
	if body.has_method("take_damage") and body.is_in_group("enemies"):
			_hit_enemy(body)

func _hit_enemy(enemy: Node):
	# Check if weapon system is disabled
	if DebugSettings.instance and not DebugSettings.instance.weapon_system_enabled:
		return
	
	# Check if we already hit this enemy this swing
	if enemy in enemies_hit_this_swing:
		return
	
	# Mark as hit
	enemies_hit_this_swing.append(enemy)
	
	# Deal damage
	enemy.take_damage(damage, owner_entity, weapon_tags)
	
	# Apply knockback
	if enemy.has_method("apply_knockback"):
		var direction = enemy.global_position - global_position
		enemy.apply_knockback(direction, knockback_force)
	
	# Emit signal
	hit_enemy.emit(enemy)

func reset_hit_list():
	# Call this at the start of each swing
	enemies_hit_this_swing.clear()
	
	# Trigger debug visualization
	if show_attack_debug:
		queue_redraw()

func set_active(active: bool):
	# Public method to toggle weapon collision during attack windows
	_set_active_internal(active)

func _set_active_internal(active: bool):
	monitoring = active
	monitorable = active
	set_deferred("monitoring", active)
	set_deferred("monitorable", active)

func sweep_overlap():
	# Manually damage anything currently inside the weapon area
	var bodies := get_overlapping_bodies()
	for b in bodies:
		if b and b.is_in_group("enemies"):
			_hit_enemy(b)
	var areas := get_overlapping_areas()
	for a in areas:
		var parent = a.get_parent()
		if parent and parent.is_in_group("enemies"):
			_hit_enemy(parent)

func _process(_delta):
	if attack_debug_timer > 0:
			queue_redraw()

func _draw():
	if true:
		return
	
	# Get collision shape to visualize attack area
	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return
	
	# Draw the collision shape
	if collision_shape.shape is RectangleShape2D:
		var rect_shape = collision_shape.shape as RectangleShape2D
		var size = rect_shape.size
		var pos = collision_shape.position
		
		# Draw filled rectangle with transparency
		var color = Color.RED
		color.a = 0.3 + (attack_debug_timer * 0.5)  # Fade out effect
		draw_rect(Rect2(pos - size/2.0, size), color)
		
		# Draw outline
		var outline_color = Color.YELLOW
		outline_color.a = 0.8
		draw_rect(Rect2(pos - size/2.0, size), outline_color, false, 2.0)
		
		# Draw attack direction indicator
		draw_line(pos, pos + Vector2(0, -30), Color.WHITE, 2.0)

func get_tags() -> Array:
	return weapon_tags
