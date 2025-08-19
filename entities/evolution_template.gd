extends BaseEvolvedCreature
#class_name MyEvolution  # Uncomment and rename

## Template for creating new evolved creatures
## Copy this file and rename it for your new evolution (e.g., bunny.gd)
## This ensures consistent behavior across all evolved forms

signal ability_used(ability_name: String)

# Evolution-specific projectiles/abilities
#@export var projectile_scene: PackedScene
#@export var ability_damage: float = 10.0
#@export var ability_cooldown: float = 2.0
#var can_use_ability: bool = true
#var ability_timer: float = 0.0

# Aggro system (standard for all evolutions)
@export var aggro_radius: float = 400.0
var is_aggroed: bool = false
var wander_timer: float = 0.0
var wander_change_interval: float = 2.0

func _ready():
	# Set evolution config before parent ready
	evolution_mxp_cost = 10  # Change this for your evolution
	evolution_name = "MyEvolution"  # Change this
	
	super._ready()
	_setup_evolution()

func _setup_evolution():
	# Set creature type and properties
	creature_type = "MyEvolution"  # Change this
	base_scale = 1.0  # Adjust visual scale
	abilities = ["ability1", "ability2"]  # List your abilities
	
	# Set evolution-specific tags
	if taggable:
		# Add your specific tags here
		taggable.add_tag("MyTag")
	
	# Set stats - adjust for your evolution
	max_health = 50.0
	current_health = max_health
	move_speed = 150.0
	damage = 5.0
	attack_range = 100.0
	detection_range = 400.0
	attack_cooldown = 1.0
	
	# Set collision layers
	collision_layer = 2  # Enemies layer
	collision_mask = 3   # Can be hit by player weapons
	
	# Load ability resources
	#if not projectile_scene:
	#	projectile_scene = preload("res://entities/enemies/abilities/my_projectile.tscn")
	
	print("🎮 %s spawned: %s" % [evolution_name, chatter_username])
	
	# Set initial wander target
	call_deferred("_randomize_wander_target")

func _entity_physics_process(delta):
	# Update ability cooldowns
	#if not can_use_ability:
	#	ability_timer -= delta
	#	if ability_timer <= 0:
	#		can_use_ability = true
	
	# Update aggro state
	_check_aggro_range()
	
	# Update AI controller based on state
	var ai_controller = get_node_or_null("AIMovementController")
	if ai_controller:
		if is_aggroed:
			# Let base enemy handle player targeting
			super._entity_physics_process(delta)
			
			# Check if we should use abilities
			if target_player and is_instance_valid(target_player):
				var distance = global_position.distance_to(target_player.global_position)
				
				# Use your abilities here
				#if can_use_ability and distance <= attack_range:
				#	_use_ability()
		else:
			# Wander behavior when not aggroed
			_handle_wandering(delta)
	
	# Face movement direction (flip sprite)
	_face_movement_direction()

## Standard wandering behavior
func _handle_wandering(delta: float):
	wander_timer += delta
	if wander_timer >= wander_change_interval:
		_randomize_wander_target()
		wander_timer = 0.0

func _randomize_wander_target():
	var ai_controller = get_node_or_null("AIMovementController")
	if not ai_controller:
		return
	
	if randf() < 0.3:
		ai_controller.set_target_position(global_position)  # Stay in place
	else:
		var wander_range = 200.0
		var angle = randf() * TAU
		var offset = Vector2(cos(angle), sin(angle)) * randf_range(50, wander_range)
		var target = global_position + offset
		ai_controller.set_target_position(target)

## Standard aggro behavior
func _check_aggro_range():
	var player = _find_player()
	if not player:
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	
	if not is_aggroed and distance_to_player <= aggro_radius:
		is_aggroed = true
		print("🎯 %s aggroed on player!" % chatter_username)
		
		# Visual feedback for aggro
		if sprite:
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

## Standard sprite flipping
func _face_movement_direction():
	if not sprite:
		return
		
	if movement_velocity.x != 0:
		if movement_velocity.x > 0:
			sprite.scale.x = abs(sprite.scale.x) * base_scale
		else:
			sprite.scale.x = -abs(sprite.scale.x) * base_scale

## Implement your ability here
#func _use_ability():
#	if not target_player or not can_use_ability:
#		return
#	
#	can_use_ability = false
#	ability_timer = ability_cooldown
#	
#	# Your ability logic here
#	ability_used.emit("ability_name")
