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
@export var windup_duration: float = 0.3  # 300ms telegraph

# Cached resources
var projectile_scene: PackedScene
var shoot_sound: AudioStream
var kiss_sound: AudioStream

# Animation state
var is_winding_up: bool = false
var original_sprite_scale: Vector2 = Vector2.ONE  # Store original scale

func _init() -> void:
	# Set base properties
	ability_id = "heart_projectile"
	ability_name = "Heart Projectile"
	ability_description = "Shoots a heart-shaped projectile that damages enemies"
	ability_tags = ["Projectile", "Ranged", "Magic"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = 2.0
	resource_costs = {}  # No resource cost
	
	# Targeting - requires a target enemy
	targeting_type = 1  # TARGET_ENEMY (shoots at target)
	base_range = 300.0  # Max shooting range (doubled for more aggressive ranged attacks)

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
	
	# Check range
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	
	if entity:
		var distance = entity.global_position.distance_to(target.global_position)
		if distance > base_range:
			return false
	
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
	
	# Start windup animation
	_start_windup_animation(entity, holder, target_data)

func _start_windup_animation(entity: Node, holder, target_data) -> void:
	is_winding_up = true
	
	# Play kiss sound immediately
	if kiss_sound and AudioManager.instance:
		AudioManager.instance.play_sfx_on_node(
			kiss_sound,
			entity,
			-8.0,  # Quieter than main sound
			1.0
		)
	
	# Get sprite for animation
	var sprite = entity.get_node_or_null("Sprite")
	if sprite:
		# Ensure we reset to original scale first to prevent compounding
		sprite.scale = original_sprite_scale
		sprite.modulate = Color.WHITE
		
		# Create pronounced kiss animation - stretch only, pink only at the end
		var tween = entity.create_tween()
		
		# Dramatic stretch animation - like blowing a kiss (using stored original scale)
		# First stretch horizontally (pucker up)
		tween.tween_property(sprite, "scale", Vector2(original_sprite_scale.x * 0.8, original_sprite_scale.y * 1.3), windup_duration * 0.4)
		# Then stretch vertically (kiss)
		tween.tween_property(sprite, "scale", Vector2(original_sprite_scale.x * 1.4, original_sprite_scale.y * 0.9), windup_duration * 0.4)
		
		# Brief pink flash only at the very end (right before projectile fires)
		tween.tween_property(sprite, "scale", original_sprite_scale, windup_duration * 0.15)
		tween.parallel().tween_property(sprite, "modulate", Color(1.6, 0.4, 1.2), windup_duration * 0.05)  # Quick pink flash
		tween.parallel().tween_property(sprite, "modulate", Color.WHITE, windup_duration * 0.1)  # Quick fade back
	
	# Wait for windup duration then fire projectile
	await entity.get_tree().create_timer(windup_duration).timeout
	
	# Fire the actual projectile
	_fire_projectile(entity, holder, target_data)

func _fire_projectile(entity: Node, holder, target_data) -> void:
	is_winding_up = false
	
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
	
	# Start cooldown
	_start_cooldown(holder)
	
	# Notify holder
	holder.on_ability_executed(self)
	executed.emit(target_data)

## Helper to create target data for this ability
static func create_target_data(enemy: Node) -> Dictionary:
	return {
		"target_enemy": enemy,
		"target_position": enemy.global_position if enemy else Vector2.ZERO
	}
