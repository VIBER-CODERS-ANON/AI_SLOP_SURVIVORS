extends Area2D
class_name XPOrb

## XP orb pickup that grants experience to the player

@export var xp_value: int = 1
@export var float_amplitude: float = 3.0
@export var float_speed: float = 3.0
@export var rotation_speed: float = 4.0

# Magnetic attraction
@export var attraction_speed: float = 400.0
var is_attracted: bool = false
var target_player: Node2D = null

var time: float = 0.0
var initial_position: Vector2

func _ready():
	# Ensure pickup pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Set up collision
	collision_layer = 8  # Pickup layer (layer 4)
	collision_mask = 1   # Only detect player (layer 1)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Add to groups
	add_to_group("pickups")
	add_to_group("xp_orbs")
	
	# Store initial position for floating animation
	# Use global position to preserve the spawn location
	initial_position = global_position
	
	# Set visual properties
	z_index = 4
	
	# Set scale and color based on XP value (1-10 scale with distinct colors)
	var base_scale = 0.8
	_apply_value_visuals(base_scale)
	
	# XP orb spawned

func _apply_value_visuals(base_scale: float):
	# Color scale based on value (up to 100 XP with tier system)
	# No size scaling - all orbs are the same size
	
	# Determine color based on value ranges
	if xp_value <= 5:  # 1-5: Gray to Brown
		var t = (xp_value - 1) / 4.0
		modulate = Color(0.7, 0.7, 0.7).lerp(Color(0.5, 0.3, 0.1), t)
	elif xp_value <= 10:  # 6-10: Red to Orange
		var t = (xp_value - 6) / 4.0
		modulate = Color(0.8, 0.4, 0.4).lerp(Color(1.0, 0.6, 0.2), t)
	elif xp_value <= 20:  # 11-20: Orange to Yellow
		var t = (xp_value - 11) / 9.0
		modulate = Color(1.0, 0.6, 0.2).lerp(Color(1.0, 1.0, 0.3), t)
	elif xp_value <= 30:  # 21-30: Yellow to Green
		var t = (xp_value - 21) / 9.0
		modulate = Color(1.0, 1.0, 0.3).lerp(Color(0.4, 1.0, 0.4), t)
	elif xp_value <= 40:  # 31-40: Green to Cyan
		var t = (xp_value - 31) / 9.0
		modulate = Color(0.4, 1.0, 0.4).lerp(Color(0.3, 0.8, 1.0), t)
	elif xp_value <= 50:  # 41-50: Cyan to Blue
		var t = (xp_value - 41) / 9.0
		modulate = Color(0.3, 0.8, 1.0).lerp(Color(0.4, 0.4, 1.0), t)
	elif xp_value <= 60:  # 51-60: Blue to Purple
		var t = (xp_value - 51) / 9.0
		modulate = Color(0.4, 0.4, 1.0).lerp(Color(0.8, 0.3, 1.0), t)
	elif xp_value <= 70:  # 61-70: Purple to Pink
		var t = (xp_value - 61) / 9.0
		modulate = Color(0.8, 0.3, 1.0).lerp(Color(1.0, 0.3, 0.7), t)
	elif xp_value <= 80:  # 71-80: Pink to Gold
		var t = (xp_value - 71) / 9.0
		modulate = Color(1.0, 0.3, 0.7).lerp(Color(1.0, 0.9, 0.0), t)
	elif xp_value <= 90:  # 81-90: Gold to White
		var t = (xp_value - 81) / 9.0
		modulate = Color(1.0, 0.9, 0.0).lerp(Color(1.0, 1.0, 1.0), t)
	else:  # 91-100+: Rainbow/Prismatic effect
		# Cycle through rainbow colors based on time for epic orbs
		var hue = fmod(Time.get_ticks_msec() / 1000.0, 1.0)
		modulate = Color.from_hsv(hue, 0.8, 1.0)
	
	# Apply fixed size (no scaling based on value)
	scale = Vector2.ONE * base_scale
	
	# Add glow effect for higher values
	if xp_value >= 20:
		modulate *= 1.2  # Slight glow
	if xp_value >= 50:
		modulate *= 1.3  # More glow
	if xp_value >= 80:
		modulate *= 1.4  # Strong glow

func _physics_process(_delta):
	time += _delta
	
	# Check for nearby player for magnetic attraction
	if not is_attracted:
		_check_attraction()
	
	if is_attracted and target_player and is_instance_valid(target_player):
		# Move towards player
		var direction = global_position.direction_to(target_player.global_position)
		global_position += direction * attraction_speed * _delta
		
		# Add some spiraling motion
		var perpendicular = Vector2(-direction.y, direction.x)
		global_position += perpendicular * sin(time * 8) * 20 * _delta
	else:
		# Floating animation when not attracted
		global_position.y = initial_position.y + sin(time * float_speed) * float_amplitude
	
	# Rotation animation
	rotation += rotation_speed * _delta

func _check_attraction():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		# Direct access to player's pickup_range - no property checking
		if global_position.distance_to(player.global_position) <= player.pickup_range:
			is_attracted = true
			target_player = player

func can_be_picked_up() -> bool:
	return not is_attracted  # Can be picked up if not already attracted

func _on_body_entered(body: Node2D):
	# Check if it's the player
	if body.is_in_group("player"):
		collect(body)

func collect(player: Node2D):
	print("✨ Player collected XP orb! +%d XP" % xp_value)
	
	# Grant XP to player
	if player.has_method("add_xp"):
		player.add_xp(xp_value)
	
	# Play badass pickup sound through AudioManager
	if AudioManager.instance:
		AudioManager.instance.play_sfx(
			preload("res://audio/sfx_Badas_20250811_105457.mp3"),
			global_position,
			-10.0,  # Same volume as before
			randf_range(0.9, 1.1)
		)
	
	# Visual effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Kill tween when orb is freed
	tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(self, "scale", scale * 2.0, 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
	
	# Remove from groups immediately
	remove_from_group("pickups")
	remove_from_group("xp_orbs")
	
	# Disable collision
	set_deferred("monitoring", false)
