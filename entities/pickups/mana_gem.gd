extends Area2D
class_name ManaGem

## Mana gem pickup that restores 10 mana and 10 HP

@export var mana_restore_amount: float = 10.0
@export var health_restore_amount: float = 10.0
@export var float_amplitude: float = 5.0
@export var float_speed: float = 2.0
@export var rotation_speed: float = 2.0

var time: float = 0.0
var initial_position: Vector2

func _ready():
	# Ensure pickup pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Set up collision
	collision_layer = 8  # Pickup layer (layer 4)
	collision_mask = 3   # Detect player and enemies (layers 1 and 2)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	
	# Add to groups
	add_to_group("pickups")
	add_to_group("mana_gems")
	
	# Store initial position for floating animation
	initial_position = position
	
	# Make sure gem is visible above background
	z_index = 5
	
	# Add visual effect (slight blue tint)
	modulate = Color(1.0, 1.0, 1.0, 1.0)  # Keep original colors
	
	print("💎 Mana gem spawned at ", global_position)

func _physics_process(_delta):
	time += _delta
	
	# Floating animation
	position.y = initial_position.y + sin(time * float_speed) * float_amplitude
	
	# Rotation animation
	rotation += rotation_speed * _delta

func _on_body_entered(body: Node2D):
	# Check if it's a valid entity that can collect gems
	if body.has_method("add_mana") or body.has_method("heal"):
		# Check if entity has the "Lesser" tag - lesser mobs cannot collect pickups
		if TagSystem.has_tag(body, "Lesser"):
			return  # Lesser mobs cannot collect pickups
		
		collect(body)

func collect(entity: Node2D):
	print("💎 Collection triggered by ", entity.name)
	
	# Restore mana if entity has mana
	if entity.has_method("add_mana"):
		entity.add_mana(mana_restore_amount)
		print("💎 %s collected mana gem! +%d mana" % [entity.name, int(mana_restore_amount)])
	
	# Restore health
	if entity.has_method("heal"):
		entity.heal(health_restore_amount)
		print("💎 %s collected mana gem! +%d HP" % [entity.name, int(health_restore_amount)])
	
	# Visual effect
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Kill tween when gem is freed
	tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
	
	# Remove from groups immediately
	remove_from_group("pickups")
	remove_from_group("mana_gems")
	
	# Disable collision
	set_deferred("monitoring", false)
