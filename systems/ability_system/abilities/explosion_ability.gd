class_name ExplosionAbility
extends BaseAbility

## Explosion ability - creates a telegraphed explosion at the caster's location
## Used by enemies that can self-destruct (like TwitchRats)

# Explosion properties
@export var explosion_damage: float = 10.0
@export var explosion_radius: float = 120.0
@export var telegraph_time: float = 0.8
@export var explosion_scene_path: String = "res://entities/effects/explosion_effect.tscn"
@export var self_damage: float = 10.0  # Damage dealt to caster

# Whether caster takes damage from their own explosion
@export var damages_self: bool = true

# Cached resources
var explosion_scene: PackedScene

func _init() -> void:
	# Set base properties
	ability_id = "explosion"
	ability_name = "Explosion"
	ability_description = "Creates a damaging explosion at current location"
	ability_tags = ["AoE", "Fire", "SelfDestruct"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = 2.0
	resource_costs = {}  # No resource cost
	
	# Targeting - self-targeted AoE
	targeting_type = 5  # AREA_AROUND_SELF
	base_range = 0.0  # Cast at self location

func on_added(holder) -> void:
	super.on_added(holder)
	
	# Preload explosion scene
	if explosion_scene_path != "":
		explosion_scene = load(explosion_scene_path)
	
	# ExplosionAbility added

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# Check if entity is alive
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	
	if entity and entity.has_method("is_alive") and not entity.is_alive:
		return false
	
	return true

func _execute_ability(holder, target_data) -> void:
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if not entity:
		return
	
	# Report to action feed if this is a chatter
	if entity.has_method("get_chatter_username") and GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.chatter_exploded(entity.get_chatter_username())
	
	# Spawn explosion effect
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		explosion.source_entity = entity
		
		# Set source name for death messages
		if entity.has_method("get_display_name"):
			explosion.source_name = entity.get_display_name() + "'s Explosion"
		else:
			explosion.source_name = entity.name + "'s Explosion"
		
		# Apply AoE multiplier if entity has one
		if entity.has_method("get_aoe_multiplier"):
			explosion.applied_aoe_scale = entity.get_aoe_multiplier()
		
		# Override explosion properties
		explosion.damage = get_modified_value(explosion_damage, "spell_power", holder)
		explosion.explosion_radius = explosion_radius
		explosion.telegraph_time = telegraph_time
		
		# Add to scene
		entity.get_parent().add_child(explosion)
		explosion.global_position = entity.global_position
	
	# Self damage if enabled
	if damages_self and entity.has_method("take_damage"):
		entity.take_damage(self_damage, entity, ["AoE", "Fire"])
	
	# Start cooldown
	_start_cooldown(holder)
	
	# Notify holder
	holder.on_ability_executed(self)
	executed.emit(target_data)

## Override to provide AoE preview radius
func get_range() -> float:
	return explosion_radius
