class_name SuicideBombAbility
extends BaseAbility

## Suicide Bomb - Explosive self-destruct ability
## Used by Ugandan Warriors to deal massive area damage

# Explosion properties
@export var explosion_damage_percent: float = 1.0  # 100% of entity's HP as damage
@export var explosion_radius: float = 150.0
@export var telegraph_time: float = 1.0  # 1 second telegraph
@export var explosion_scene_path: String = "res://entities/effects/explosion_effect.tscn"

# Proximity activation (for AI use)
@export var activation_range: float = 120.0  # Distance to activate (increased for earlier detonation)
@export var activation_chance_per_frame: float = 0.15  # Max 15% chance when very close
@export var auto_activate_on_proximity: bool = true  # Whether AI should auto-use when near target

# Visual properties
@export var telegraph_color: Color = Color(1, 0.2, 0.2, 0.5)  # Red telegraph
@export var grow_scale: float = 1.5  # Entity grows before exploding

# Cached resources
var explosion_scene: PackedScene

func _init() -> void:
	# Set base properties
	ability_id = "suicide_bomb"
	ability_name = "Suicide Bomb"
	ability_description = "Telegraphed self-destruct dealing damage based on max HP"
	ability_tags = ["AoE", "Fire", "SelfDestruct", "Channeled"]
	ability_type = 0  # ACTIVE
	
	# No cooldown - one time use
	base_cooldown = 0.0
	resource_costs = {}  # No resource cost
	
	# Targeting - self-targeted AoE
	targeting_type = 5  # AREA_AROUND_SELF
	base_range = 0.0  # Cast at self location

func on_added(holder) -> void:
	super.on_added(holder)
	
	# Preload explosion scene
	if explosion_scene_path != "":
		explosion_scene = load(explosion_scene_path)
	
	# Suicide Bomb ability added

func on_update(holder, _delta: float) -> void:
	# Handle proximity-based auto-activation for AI entities
	if not auto_activate_on_proximity:
		return
	
	var entity = _get_entity(holder)
	if not entity:
		return
	
	# Check if entity is AI controlled
	if not entity.is_in_group("ai_controlled"):
		return
	
	# Check if already exploding
	if entity.has_meta("is_exploding") and entity.get_meta("is_exploding"):
		return
	
	# Check if ability is on cooldown
	if not can_execute(holder, {}):
		return
	
	# Find target (usually player)
	var target = null
	if entity.has("target_player") and entity.target_player:
		target = entity.target_player
	elif entity.has_method("_find_player"):
		target = entity._find_player()
	
	if not target:
		return
	
	# Check distance and randomly activate based on proximity
	var distance = entity.global_position.distance_to(target.global_position)
	if distance <= activation_range:
		# Calculate activation chance based on proximity (closer = higher chance)
		var proximity_factor = (activation_range - distance) / activation_range  # 0 to 1
		var activation_chance = proximity_factor * activation_chance_per_frame
		
		if randf() < activation_chance:
			# Execute the ability
			execute(holder, {"position": entity.global_position})

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	var entity = _get_entity(holder)
	if not entity:
		return false
	
	# Check if entity is alive
	if entity.has_method("is_alive") and not entity.is_alive:
		return false
	
	# Cannot use if already exploding
	if entity.has_meta("is_exploding") and entity.get_meta("is_exploding"):
		return false
	
	return true

func _execute_ability(holder, target_data) -> void:
	var entity = _get_entity(holder)
	if not entity:
		return
	
	# Mark as exploding
	entity.set_meta("is_exploding", true)
	
	# Report to action feed
	_report_to_action_feed(entity)
	
	# Start telegraph sequence
	_start_telegraph_sequence(entity, holder)
	
	# Notify systems
	holder.on_ability_executed(self)
	executed.emit(target_data)

func _start_telegraph_sequence(entity, holder) -> void:
	# Create telegraph area
	var telegraph = _create_telegraph(entity)
	
	# Visual changes to entity
	_apply_explosion_visuals(entity)
	
	# Wait for telegraph time
	await entity.get_tree().create_timer(telegraph_time).timeout
	
	# Clean up telegraph
	if telegraph and is_instance_valid(telegraph):
		telegraph.queue_free()
	
	# Explode!
	_perform_explosion(entity, holder)

func _create_telegraph(entity) -> Node2D:
	# Create circular telegraph area
	var telegraph = Node2D.new()
	telegraph.name = "SuicideBombTelegraph"
	entity.get_parent().add_child(telegraph)
	telegraph.global_position = entity.global_position
	
	# Add visual circle
	var circle = Line2D.new()
	circle.width = 3.0
	circle.default_color = telegraph_color
	circle.z_index = 49
	
	# Create circle points
	var points = 32
	for i in range(points + 1):
		var angle = (i / float(points)) * TAU
		var point = Vector2(cos(angle), sin(angle)) * explosion_radius
		circle.add_point(point)
	
	telegraph.add_child(circle)
	
	# Animate the telegraph
	var tween = telegraph.create_tween()
	tween.set_loops(int(telegraph_time * 2))  # Pulse twice per second
	
	# Kill tween when telegraph is freed
	telegraph.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(circle, "scale", Vector2(1.1, 1.1), 0.25)
	tween.tween_property(circle, "scale", Vector2(0.9, 0.9), 0.25)
	
	return telegraph

func _apply_explosion_visuals(entity) -> void:
	# Make entity grow and turn red
	if entity.has_node("Sprite") or entity.has_node("AnimatedSprite2D"):
		var sprite_node = entity.get_node_or_null("Sprite")
		if not sprite_node:
			sprite_node = entity.get_node_or_null("AnimatedSprite2D")
		
		if sprite_node:
			var tween = entity.create_tween()
			tween.set_parallel()
			
			# Store original values
			entity.set_meta("original_scale", sprite_node.scale)
			entity.set_meta("original_modulate", sprite_node.modulate)
			
			# Grow and redden
			tween.tween_property(sprite_node, "scale", sprite_node.scale * grow_scale, telegraph_time)
			tween.tween_property(sprite_node, "modulate", Color(2, 0.5, 0.5), telegraph_time)

func _perform_explosion(entity, _holder) -> void:
	if not entity or not is_instance_valid(entity):
		return
	
	# Calculate damage based on entity's max HP
	var explosion_damage = entity.max_health * explosion_damage_percent
	
	# Spawn explosion effect
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		
		# Set explosion properties
		explosion.source_entity = entity
		explosion.damage = explosion_damage
		explosion.explosion_radius = explosion_radius
		explosion.telegraph_time = 0.0  # No additional telegraph
		
		# Set source name for death attribution
		if entity.has_method("get_display_name"):
			explosion.source_name = entity.get_display_name() + "'s Explosion"
		elif entity.has_method("get_chatter_username"):
			explosion.source_name = entity.get_chatter_username() + "'s Explosion"
		else:
			explosion.source_name = entity.name + "'s Explosion"
		
		# Store reference for attribution
		explosion.set_meta("original_owner", entity)
		
		# Add ability tags
		for tag in ability_tags:
			if explosion.has_method("add_tag"):
				explosion.add_tag(tag)
		
		# Apply AoE multiplier if entity has one
		if entity.has_method("get_aoe_multiplier"):
			explosion.applied_aoe_scale = entity.get_aoe_multiplier()
		
		# Add to scene
		entity.get_parent().add_child(explosion)
		explosion.global_position = entity.global_position
	else:
		# Fallback: Manual explosion
		_manual_explosion(entity, explosion_damage)
	
	# Kill the entity
	if entity.has_method("die"):
		entity.die()

func _manual_explosion(entity, damage: float) -> void:
	# Get all enemies in radius
	var space_state = entity.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var circle = CircleShape2D.new()
	circle.radius = explosion_radius
	
	query.shape = circle
	query.transform = Transform2D(0, entity.global_position)
	query.collision_mask = 1  # Player layer
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var target = result.collider
		if target and target != entity and target.has_method("take_damage"):
			# Pass entity as damage source for proper attribution
			entity.set_meta("active_ability_name", "suicide explosion")
			target.take_damage(damage, entity, ability_tags)
			entity.remove_meta("active_ability_name")
	
	# Visual explosion effect
	_create_explosion_particles(entity)

func _create_explosion_particles(entity) -> void:
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 50
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 20.0
	particles.spread = 45.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(1, 0.5, 0.2, 1)  # Orange explosion
	
	particles.global_position = entity.global_position
	entity.get_tree().current_scene.add_child(particles)
	particles.emitting = true

func _report_to_action_feed(entity) -> void:
	if entity.has_method("get_chatter_username") and GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.add_message("💣 %s is about to explode!" % entity.get_chatter_username(), Color(1, 0.5, 0))

## Override to provide AoE preview radius
func get_range() -> float:
	return explosion_radius
