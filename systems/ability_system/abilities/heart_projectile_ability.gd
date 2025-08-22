class_name HeartProjectileAbility
extends BaseAbility

## Heart projectile ability for ranged enemies (primarily Succubus)
## Shoots a heart-shaped projectile towards the target

# Projectile properties
@export var projectile_damage: float = 10.0
@export var projectile_speed: float = 300.0
@export var projectile_lifetime: float = 3.0
@export var projectile_scene_path: String = "res://entities/enemies/abilities/heart_projectile.tscn"

# Visual/Audio
@export var shoot_sound_path: String = "res://audio/sfx_quick_20250814_104353.mp3"
@export var kiss_sound_path: String = "res://BespokeAssetSources/Succubus/succAudioLoop.mp3"
@export var windup_duration: float = 1.0  # 1 second stand still before firing

# Cached resources
var projectile_scene: PackedScene
var shoot_sound: AudioStream
var kiss_sound: AudioStream

# Animation state
var is_winding_up: bool = false
var original_sprite_scale: Vector2 = Vector2.ONE  # Store original scale
var casting_entity: Node = null  # Track entity during cast

# Movement state for getting to max range
signal request_move_to_range(target: Node, desired_range: float)

func _init() -> void:
	# Set base properties
	ability_id = "heart_projectile"
	ability_name = "Heart Projectile"
	ability_description = "Shoots a heart-shaped projectile that damages enemies"
	ability_tags = ["Projectile", "Ranged", "Magic"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = 1.0  # 1 second cooldown
	resource_costs = {}  # No resource cost
	
	# Targeting - requires a target enemy
	targeting_type = 1  # TARGET_ENEMY (shoots at target)
	base_range = 400.0  # Max shooting range

func on_added(holder) -> void:
	super.on_added(holder)
	
	# Preload resources
	if projectile_scene_path != "":
		projectile_scene = load(projectile_scene_path)
	if shoot_sound_path != "":
		shoot_sound = load(shoot_sound_path)
	if kiss_sound_path != "":
		kiss_sound = load(kiss_sound_path)
	
	# Store original sprite scale
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if entity:
		var sprite = entity.get_node_or_null("Sprite")
		if sprite:
			original_sprite_scale = sprite.scale
	
	# HeartProjectileAbility added

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# Cannot execute while winding up
	if is_winding_up:
		return false
	
	# Need a valid target
	if not target_data or not target_data.has("target_enemy"):
		return false
	
	var target = target_data.target_enemy
	if not is_instance_valid(target):
		return false
	
	# Don't check range here - we'll move into range if needed
	# Range check moved to the actual execution
	
	return true

func _execute_ability(holder, target_data) -> void:
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if not entity:
		return
	
	var target = target_data.target_enemy
	if not is_instance_valid(target):
		return
	
	# Check if we're in range
	var distance = entity.global_position.distance_to(target.global_position)
	if distance > base_range:
		# Request move to MAX range (not 90% like SUCC)
		# We want to attack from maximum distance
		request_move_to_range.emit(target, base_range * 0.95)  # 95% to ensure we're safely in range
		# DO NOT start cooldown when requesting movement
		
		# Clear casting flag for V2 enemies since we're not actually casting
		if holder.has_method("get_meta") and holder.get_meta("is_v2_proxy", false):
			var proxy = holder
			if proxy.enemy_manager and proxy.enemy_id >= 0 and proxy.enemy_id < proxy.enemy_manager.ability_casting_flags.size():
				proxy.enemy_manager.ability_casting_flags[proxy.enemy_id] = 0
			# Free the proxy since we're not using it
			proxy.queue_free()
		return
	
	# We're in range, proceed with attack
	# Start cooldown IMMEDIATELY to prevent spam
	_start_cooldown(holder)
	
	# Start windup animation
	_start_windup_animation(entity, holder, target_data)

func _start_windup_animation(entity: Node, holder, target_data) -> void:
	is_winding_up = true
	casting_entity = entity
	
	# Stop entity movement during cast
	if "velocity" in entity:
		entity.velocity = Vector2.ZERO
	if "movement_velocity" in entity:
		entity.movement_velocity = Vector2.ZERO
	
	# Play kiss sound immediately
	if kiss_sound and AudioManager.instance:
		AudioManager.instance.play_sfx_on_node(
			kiss_sound,
			entity,
			-8.0,  # Quieter than main sound
			1.0
		)
	
	# Get sprite for animation - stand still for 1 second with visual indicator
	var sprite = entity.get_node_or_null("Sprite")
	if sprite:
		# Reset to original scale
		sprite.scale = original_sprite_scale
		
		# Simple charging animation over 1 second
		var tween = entity.create_tween()
		
		# Gradual stretch horizontally over 0.8 seconds (charging up)
		tween.tween_property(sprite, "scale:x", original_sprite_scale.x * 1.3, windup_duration * 0.8)
		# Quick release animation in last 0.2 seconds
		tween.tween_property(sprite, "scale:x", original_sprite_scale.x * 1.5, windup_duration * 0.1)
		tween.tween_property(sprite, "scale:x", original_sprite_scale.x, windup_duration * 0.1)
	
	# Wait for full 1 second windup duration then fire projectile
	await entity.get_tree().create_timer(windup_duration).timeout
	
	# Fire the actual projectile
	_fire_projectile(entity, holder, target_data)

func update(delta: float, holder) -> void:
	super.update(delta, holder)
	
	# FORCE entity to be completely still during windup
	if is_winding_up and casting_entity and is_instance_valid(casting_entity):
		# Stop ALL movement
		casting_entity.velocity = Vector2.ZERO
		if "movement_velocity" in casting_entity:
			casting_entity.movement_velocity = Vector2.ZERO
		# Ensure entity doesn't move
		casting_entity.set_physics_process(false)

func _fire_projectile(entity: Node, holder, target_data) -> void:
	is_winding_up = false
	
	# Re-enable physics on the entity
	if casting_entity and is_instance_valid(casting_entity):
		casting_entity.set_physics_process(true)
	
	casting_entity = null
	
	# Clear casting flag for V2 enemies
	if holder.has_method("get_meta") and holder.get_meta("is_v2_proxy", false):
		var proxy = holder
		if proxy.enemy_manager and proxy.enemy_id >= 0 and proxy.enemy_id < proxy.enemy_manager.ability_casting_flags.size():
			proxy.enemy_manager.ability_casting_flags[proxy.enemy_id] = 0
	
	var target = target_data.target_enemy
	if not is_instance_valid(target):
		return
	
	# Play shoot sound
	if shoot_sound and AudioManager.instance:
		AudioManager.instance.play_sfx_on_node(
			shoot_sound,
			entity,
			0.0,
			1.0
		)
	
	# Create projectile
	if projectile_scene:
		var projectile = projectile_scene.instantiate()
		entity.get_tree().current_scene.add_child(projectile)
		projectile.global_position = entity.global_position
		
		# Set projectile properties
		var direction = (target.global_position - entity.global_position).normalized()
		if projectile.has_method("setup"):
			# Calculate damage with modifiers
			var final_damage = get_modified_value(projectile_damage, "spell_power", holder)
			projectile.setup(direction, projectile_speed, final_damage, entity)
		
		# Set lifetime if projectile has it
		if "lifetime" in projectile:
			projectile.lifetime = projectile_lifetime
	
	# Notify holder
	holder.on_ability_executed(self)
	executed.emit(target_data)
	
	# For V2 proxy, free it after projectile is fired (non-channeled ability)
	if holder.has_method("get_meta") and holder.get_meta("is_v2_proxy", false):
		holder.queue_free()

## Helper to create target data for this ability
static func create_target_data(enemy: Node) -> Dictionary:
	return {
		"target_enemy": enemy,
		"target_position": enemy.global_position if enemy else Vector2.ZERO
	}
