extends BasePrimaryWeapon
class_name ArcingSwordWeapon

## Sword weapon that spawns sword sprites that arc towards the cursor
## Alternates between left and right spawns

@export_group("Arc Settings")
@export var arc_duration: float = 0.5  # Time for sword to complete its arc
@export var arc_radius: float = 100.0  # Distance from player where sword spawns
@export var arc_angle_degrees: float = 45.0  # Arc angle in degrees (default semicircle)
@export var sword_sprite_path: String = "res://BespokeAssetSources/sword/base_sword_attack_sprite.png"  # Path to sword sprite
@export var sword_scale: float = 1.0  # Default to 1:1 pixel scale
@export var arc_speed_multiplier: float = 1.5  # 1.5x faster swipe (not attack rate)

# Arc shape controls (wider/further arc)
@export var arc_start_offset_deg: float = 120.0  # Angle offset from mouse dir for spawn side
@export var arc_end_offset_deg: float = 120.0    # Angle offset to opposite side for end
@export var arc_curve_factor: float = 1.8        # How far the mid point bulges towards cursor
@export var arc_center_offset: float = 0.0       # Circle center at player (0). Increase to push center toward cursor

# Spawn/Despawn FX
@export var spawn_fx_duration: float = 0.08
@export var despawn_fx_duration: float = 0.12
@export var spawn_scale_factor: float = 0.85
@export var despawn_scale_factor: float = 1.12

# Sprite orientation fix: if your sword texture points UP by default, use -PI/2.
# If it points RIGHT by default, set to 0.
# Add PI to flip 180 degrees
@export var sprite_forward_angle_offset: float = -PI / 2.0 + PI

# Trail streak settings
@export_group("Trail Effects")
@export var enable_trail: bool = true
@export var trail_color: Color = Color(1.0, 0.2, 0.15, 0.7)  # RED streak with heat!
@export var trail_length: int = 12  # More ghost copies for denser trail
@export var trail_fade_power: float = 1.5  # Slower fade for longer visibility
@export var trail_update_rate: float = 0.01  # Even more frequent updates for solid trail

# Alternation state
var spawn_left: bool = true  # Alternates between left/right spawns

# Active sword instances
var active_swords: Array[Node2D] = []

# Extra strikes feature (stackable Twin Slash)
var extra_strikes: int = 0  # Number of EXTRA strikes (0 = 1 sword, 1 = 2 swords, etc.)
var current_strike_index: int = 0  # Which strike we're on (0-based)

func _on_weapon_ready():
	# Set weapon type and tags
	weapon_tags = ["Melee", "Primary", "AoE", "AttackSpeed", "Sword"]
	
	# Validate and fix critical properties
	if arc_duration <= 0:
		push_warning("Invalid arc_duration, setting to 0.5")
		arc_duration = 0.5
	if arc_radius <= 0:
		push_warning("Invalid arc_radius, setting to 80.0")
		arc_radius = 80.0
	if sword_scale <= 0:
		push_warning("Invalid sword_scale, setting to 1.0")
		sword_scale = 1.0
	if arc_speed_multiplier <= 0:
		push_warning("Invalid arc_speed_multiplier, setting to 1.0")
		arc_speed_multiplier = 1.0
	if arc_center_offset < 0:
		arc_center_offset = 0.0
	if arc_start_offset_deg <= 0:
		arc_start_offset_deg = 120.0
	if arc_end_offset_deg <= 0:
		arc_end_offset_deg = 120.0
	if arc_curve_factor <= 0:
		arc_curve_factor = 1.5
	
	print("⚔️ ArcingSwordWeapon ready! Attack speed: ", base_attack_speed)
	print("   Arc duration: ", arc_duration, " Arc radius: ", arc_radius)
	
	# Enable visual updates
	set_process(true)

func get_weapon_type() -> String:
	return "arcing_sword"

func _execute_attack():
	last_attack_time = Time.get_ticks_msec() / 1000.0
	
	# Create a new sword instance
	var sword = _create_sword_instance()
	if not sword:
		print("❌ Failed to create sword instance!")
		is_attacking = false
		return
		
	# Add to active swords
	active_swords.append(sword)
	
	# Start the arc animation
	_start_sword_arc(sword)
	
	# Alternate spawn side for next strike (even mid-attack for cross pattern)
	spawn_left = !spawn_left
	
	# If extra strikes are enabled, queue them up
	if extra_strikes > 0 and current_strike_index == 0:
		# We're on the first strike, queue up all extra strikes
		for i in range(extra_strikes):
			current_strike_index = i + 1
			_execute_extra_strike(i + 1)  # Pass strike number (1-based)
		current_strike_index = 0  # Reset for next attack
	
	# Attack is considered complete immediately (sword handles its own lifetime)
	is_attacking = false
	
	# Force a redraw to show attack happened
	queue_redraw()

func _create_sword_instance() -> Node2D:
	
	# Create sword directly instead of using packed scene
	var sword = Node2D.new()
	sword.name = "SwordProjectile"
	sword.z_index = 10
	sword.visible = true
	sword.modulate = Color(1, 1, 1, 1)  # Full opacity
	
	# Add sprite
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	if ResourceLoader.exists(sword_sprite_path):
		sprite.texture = load(sword_sprite_path)
		# Use 1:1 pixel scale by default; allow override via sword_scale
		sprite.scale = Vector2(sword_scale, sword_scale)
	else:
		var image = Image.create(200, 40, false, Image.FORMAT_RGBA8)
		image.fill(Color(1.0, 0.2, 0.2, 1.0))  # Bright red for debugging
		var texture = ImageTexture.create_from_image(image)
		sprite.texture = texture
		sprite.scale = Vector2(0.5, 0.5)  # Still visible but not too huge
	sword.add_child(sprite)
	
	# Add motion blur trail for that STREAK effect
	if enable_trail:
		# Create a container for ghost trails
		var trail_container = Node2D.new()
		trail_container.name = "TrailContainer"
		trail_container.z_index = -1  # Behind the main sword
		sword.add_child(trail_container)
		
		# Store trail data on sword
		sword.set_meta("trail_container", trail_container)
		sword.set_meta("last_trail_update", 0.0)
	
	# Add hitbox
	var hitbox = Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	sword.add_child(hitbox)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = RectangleShape2D.new()
	# Match collision size to the sprite's texture dimensions at current scale
	var tex_size := Vector2(100, 40)
	if sprite.texture:
		tex_size = sprite.texture.get_size() * sprite.scale
	shape.size = tex_size
	collision.shape = shape
	hitbox.add_child(collision)
	
	# Set up collision detection
	hitbox.set_meta("enemies_hit", [])
	hitbox.set_meta("weapon_ref", self)
	# Add unique identifier to ensure independent hit tracking for double strike
	hitbox.set_meta("sword_id", sword.get_instance_id())
	hitbox.body_entered.connect(_on_sword_body_entered.bind(hitbox))
	hitbox.area_entered.connect(_on_sword_area_entered.bind(hitbox))
	
	add_child(sword)
	
	# Set initial position based on spawn side using local-space perfect circle
	# Compute mouse bearing in local space so arc is stable regardless of global rotation
	var mouse_angle_local = (get_global_mouse_position() - global_position).angle() - global_rotation
	
	# Get angular offset if this is a 3rd+ sword
	var angle_offset_rad = 0.0
	if sword.has_meta("angle_offset_degrees"):
		angle_offset_rad = deg_to_rad(sword.get_meta("angle_offset_degrees"))
		# Apply offset outward from center (away from mouse direction)
		if spawn_left:
			angle_offset_rad = -angle_offset_rad  # Left side gets negative offset
	
	# Flip side so arc appears on the cursor-facing side
	var spawn_angle = mouse_angle_local + (PI / 2.0 if spawn_left else -PI / 2.0) + angle_offset_rad
	var center_dir_local = Vector2.RIGHT.rotated(mouse_angle_local)
	var circle_center = center_dir_local * arc_center_offset
	var spawn_offset = circle_center + Vector2(cos(spawn_angle), sin(spawn_angle)) * arc_radius
	sword.position = spawn_offset
	
	# Set initial rotation based on spawn side
	# If spawning on left, face right (towards where it will arc)
	# If spawning on right, face left
	# Set initial facing so tip is outward at spawn
	sword.rotation = spawn_angle + sprite_forward_angle_offset

	# Spawn FX: quick fade/scale in
	sword.modulate.a = 0.0
	sword.scale = Vector2(spawn_scale_factor, spawn_scale_factor)
	var spawn_fx = sword.create_tween()
	spawn_fx.set_trans(Tween.TRANS_QUAD)
	spawn_fx.set_ease(Tween.EASE_OUT)
	
	# Store tween reference for cleanup
	sword.set_meta("spawn_tween", spawn_fx)
	
	spawn_fx.tween_property(sword, "modulate:a", 1.0, spawn_fx_duration)
	spawn_fx.parallel().tween_property(sword, "scale", Vector2(1, 1), spawn_fx_duration)
	
	# Store circle center for arc updates
	sword.set_meta("circle_center", circle_center)
	# Store which side this sword was spawned on (for offset calculations)
	sword.set_meta("spawned_left", spawn_left)
	return sword

func _get_spawn_angle() -> float:
	# Start at half the arc angle offset from cursor direction
	var center_angle = (get_global_mouse_position() - global_position).angle()
	var arc_angle_rad = deg_to_rad(arc_angle_degrees)
	var side_offset = -arc_angle_rad / 2.0 if spawn_left else arc_angle_rad / 2.0
	return center_angle + side_offset

func _start_sword_arc(sword: Node2D):
	# Safety check for arc duration
	if arc_duration <= 0:
		push_error("Arc duration is 0 or negative! Setting to default 0.5")
		arc_duration = 0.5
		
	# Compute arc angles based on arc_angle_degrees
	var center_angle_local = (get_global_mouse_position() - global_position).angle() - global_rotation
	var arc_angle_rad = deg_to_rad(arc_angle_degrees)
	
	# Get angular offset for 3rd+ swords
	var angle_offset_rad = 0.0
	if sword.has_meta("angle_offset_degrees"):
		angle_offset_rad = deg_to_rad(sword.get_meta("angle_offset_degrees"))
		# Get the spawn side from the sword's metadata (we need to know which side it was spawned on)
		var sword_spawn_left = sword.get_meta("spawned_left", spawn_left)
		if sword_spawn_left:
			angle_offset_rad = -angle_offset_rad  # Left side gets negative offset
	
	# Flip side to ensure the arc is on the cursor-facing side
	var start_angle = center_angle_local + (arc_angle_rad / 2.0 if spawn_left else -arc_angle_rad / 2.0) + angle_offset_rad
	var end_angle = center_angle_local + (-arc_angle_rad / 2.0 if spawn_left else arc_angle_rad / 2.0) + angle_offset_rad
	
	# Recompute circle center for this swipe (in case mouse moved), in local space
	var center_dir_local = Vector2.RIGHT.rotated(center_angle_local)
	var circle_center = center_dir_local * arc_center_offset
	
	# Store arc data
	sword.set_meta("start_angle", start_angle)
	sword.set_meta("end_angle", end_angle)
	sword.set_meta("circle_center", circle_center)
	sword.set_meta("last_rotation_check", 0)  # For multi-hit on 360°+ arcs
	
	# Create the arc tween on the sword itself
	var tween = sword.create_tween()
	tween.set_parallel(false)
	tween.set_loops(1)  # Explicitly set to run only once
	
	# Store tween reference for cleanup
	sword.set_meta("arc_tween", tween)
	
	# Kill tween when sword is freed
	sword.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	# Arc movement (circular)
	# Scale duration based on arc angle to maintain consistent angular velocity
	var angle_factor = arc_angle_degrees / 180.0  # 180° is our base
	var adjusted_duration = (arc_duration * angle_factor) / arc_speed_multiplier
	
	# Safety check for duration
	if adjusted_duration <= 0:
		push_error("Adjusted duration is 0 or negative! Using 0.5")
		adjusted_duration = 0.5
	
	tween.tween_method(
		func(t: float): 
			if is_instance_valid(sword):
				_update_sword_arc(sword, t),
		0.0, 1.0, adjusted_duration
	)
	
	# Cleanup after arc completes
	tween.tween_callback(func(): 
		if is_instance_valid(sword):
			_on_sword_arc_complete(sword)
	)

func _update_sword_arc(sword: Node2D, t: float):
	if not is_instance_valid(sword):
		return

	# Get arc data
	var start_angle: float = sword.get_meta("start_angle", 0.0)
	var end_angle: float = sword.get_meta("end_angle", PI)
	var circle_center: Vector2 = sword.get_meta("circle_center", Vector2.ZERO)
	
	# Calculate angle difference, handling multiple rotations
	var angle_diff = end_angle - start_angle
	# If arc spans more than a circle, we need to interpolate through the full range
	var theta = start_angle + angle_diff * t
	
	# Check if we've completed a half rotation (180°) to reset hit list
	# This allows multi-hitting on wide arcs and full circles
	var last_rotation_check = sword.get_meta("last_rotation_check", 0.0)
	var rotations_completed = (theta - start_angle) / PI  # Every PI radians (180°)
	var current_half_rotation = int(rotations_completed)
	if current_half_rotation > last_rotation_check:
		# Reset enemies hit list for multi-hitting
		var hitbox = sword.get_node_or_null("Hitbox")
		if hitbox:
			hitbox.set_meta("enemies_hit", [])

		sword.set_meta("last_rotation_check", current_half_rotation)
	
	# Position sword on the arc
	var pos = circle_center + Vector2(cos(theta), sin(theta)) * arc_radius
	sword.position = pos

	# Tip points outward (radially)
	sword.rotation = theta + sprite_forward_angle_offset
	
	# Update trail effect
	if enable_trail:
		_update_sword_trail(sword)

func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func _update_sword_trail(sword: Node2D):
	var trail_container = sword.get_meta("trail_container", null)
	if not trail_container:
		return
		
	# Get current time to check update rate
	var last_update = sword.get_meta("last_trail_update", 0.0)
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_update < trail_update_rate:
		return
	sword.set_meta("last_trail_update", current_time)
	
	# Get sword sprite for copying
	var original_sprite = sword.get_node_or_null("Sprite")
	if not original_sprite or not original_sprite.texture:
		return
	
	# Create ghost copy
	var ghost = Sprite2D.new()
	ghost.texture = original_sprite.texture
	ghost.scale = original_sprite.scale
	# Convert sword's global position to local position relative to weapon
	ghost.position = sword.position
	ghost.rotation = sword.rotation
	ghost.modulate = trail_color
	ghost.z_index = -2  # Even further back
	ghost.show_behind_parent = true
	
	# Add to scene at weapon level (not as child of sword)
	add_child(ghost)
	
	# Fade out the ghost with power curve
	var fade_duration = trail_length * trail_update_rate
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)  # Quadratic fade for smoother trail
	tween.set_ease(Tween.EASE_OUT)
	
	# Kill tween when ghost is freed
	ghost.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(ghost, "modulate:a", 0.0, fade_duration)
	# Also fade scale slightly for better streak effect
	tween.parallel().tween_property(ghost, "scale", original_sprite.scale * 0.7, fade_duration)
	tween.tween_callback(func(): if is_instance_valid(ghost): ghost.queue_free())
	
	# Clean up old ghosts if too many
	var ghosts = []
	for child in get_children():
		if child is Sprite2D and child != sword and child.name != "Sprite":
			ghosts.append(child)
	
	# Keep only the most recent trail_length ghosts
	if ghosts.size() > trail_length:
		for i in range(ghosts.size() - trail_length):
			if is_instance_valid(ghosts[i]):
				ghosts[i].queue_free()

func _on_sword_arc_complete(sword: Node2D):
	# Remove from active swords
	active_swords.erase(sword)
	
	if not is_instance_valid(sword):
		print("❌ Sword already freed before arc complete!")
		return
	
	# Despawn FX: subtle fade + scale out, then free
	var fx = sword.create_tween()
	
	# Store tween reference for cleanup
	sword.set_meta("despawn_tween", fx)
	
	# Kill any existing tweens on this sword
	for meta_key in ["spawn_tween", "arc_tween"]:
		if sword.has_meta(meta_key):
			var old_tween = sword.get_meta(meta_key)
			if old_tween and old_tween.is_valid():
				old_tween.kill()
	
	fx.tween_property(sword, "modulate:a", 0.0, despawn_fx_duration)
	fx.parallel().tween_property(sword, "scale", Vector2(despawn_scale_factor, despawn_scale_factor), despawn_fx_duration)
	fx.tween_callback(func(): if is_instance_valid(sword): sword.queue_free())



func _on_sword_body_entered(body: Node, hitbox: Area2D):
	if body.is_in_group("enemies"):
		var enemies_hit = hitbox.get_meta("enemies_hit", [])
		if not body in enemies_hit:
			enemies_hit.append(body)
			hitbox.set_meta("enemies_hit", enemies_hit)
			deal_damage_to_enemy(body)


func _on_sword_area_entered(area: Area2D, hitbox: Area2D):
	var parent = area.get_parent()
	if parent and parent.is_in_group("enemies"):
		var enemies_hit = hitbox.get_meta("enemies_hit", [])
		if not parent in enemies_hit:
			enemies_hit.append(parent)
			hitbox.set_meta("enemies_hit", enemies_hit)
			deal_damage_to_enemy(parent)


func _weapon_process(_delta: float):
	# Force redraw to update debug visuals
	if Time.get_ticks_msec() / 1000.0 - last_attack_time < 0.5:
		queue_redraw()

var last_attack_time: float = 0.0

## Add an extra strike (stackable)
func add_extra_strike():
	extra_strikes += 1
	print("⚔️ Extra strikes increased to %d! Total swords per attack: %d" % [extra_strikes, extra_strikes + 1])

## Add degrees to the arc angle
func add_arc_degrees(degrees: float):
	arc_angle_degrees += degrees
	print("⚔️ Arc angle increased by %.0f° to %.0f°!" % [degrees, arc_angle_degrees])
	if arc_angle_degrees >= 360:
		var full_circles = int(arc_angle_degrees / 360)
		print("🌀 Sword now performs %d full rotation(s) plus %.0f°!" % [full_circles, fmod(arc_angle_degrees, 360)])

## Execute an extra strike with optional angular offset
func _execute_extra_strike(strike_number: int):
	# Calculate angular offset for strikes 3+ (strikes 1-2 have no offset)
	var angle_offset_degrees = 0.0
	if strike_number >= 2:  # 3rd sword and beyond (0-based would be index 2+)
		# Each pair gets +20° offset
		angle_offset_degrees = floor(strike_number / 2.0) * 20.0
	
	# Create another sword (spawn side already alternated in main attack)
	var sword = _create_sword_instance()
	if not sword:
		return
	
	# Store the angular offset for this sword
	sword.set_meta("angle_offset_degrees", angle_offset_degrees)
		
	# Add to active swords
	active_swords.append(sword)
	
	# Start the arc animation
	_start_sword_arc(sword)
	
	# Alternate again for proper pattern continuation
	spawn_left = !spawn_left
	
	# Visual feedback
	queue_redraw()

# Debug visualization
func _draw():
	if Engine.is_editor_hint():
		# Draw arc preview in editor only
		draw_arc(Vector2.ZERO, arc_radius, 0, TAU, 32, Color(1, 1, 1, 0.2), 2.0)
