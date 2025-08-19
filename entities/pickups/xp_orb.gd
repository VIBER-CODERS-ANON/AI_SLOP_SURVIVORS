extends Area2D
class_name XPOrb

## XP orb pickup that grants experience to the player

@export var xp_value: int = 1
@export var float_amplitude: float = 3.0
@export var float_speed: float = 3.0
@export var rotation_speed: float = 4.0

# Magnetic attraction
@export var attraction_radius: float = 150.0
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
	
	# Set scale based on XP value
	var base_scale = 0.8  # Slightly smaller than before
	if xp_value >= 10:
		scale = Vector2.ONE * base_scale * 1.5  # Bigger for unique drops
		modulate = Color(1, 0.9, 0.2)  # Bright gold color
	else:
		scale = Vector2.ONE * base_scale
		modulate = Color(1, 0.6, 0.2)  # Orange color
	
	# XP orb spawned

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
		if global_position.distance_to(player.global_position) <= attraction_radius:
			is_attracted = true
			target_player = player

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
