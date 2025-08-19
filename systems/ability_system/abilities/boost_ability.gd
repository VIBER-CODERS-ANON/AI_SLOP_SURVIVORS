class_name BoostAbility
extends BaseAbility

## Boost ability - temporary speed increase for movement
## Used by TwitchRats and potentially other entities

# Boost properties
@export var boost_duration: float = 2.0
@export var speed_multiplier: float = 3.0
@export var boost_color: Color = Color(1.5, 2, 2, 1)  # Cyan glow

func _init() -> void:
	# Set base properties
	ability_id = "boost"
	ability_name = "Boost"
	ability_description = "Temporarily increases movement speed"
	ability_tags = ["Buff", "Movement", "Speed"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = 20.0
	resource_costs = {}  # No resource cost
	
	# Targeting - self-targeted
	targeting_type = 0  # SELF
	base_range = 0.0

func on_added(holder) -> void:
	super.on_added(holder)
	
	# BoostAbility added

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# Check if entity is alive
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	
	if entity and entity.has_method("is_alive") and not entity.is_alive:
		return false
	
	# Check if already boosting
	if entity and "is_boosting" in entity and entity.is_boosting:
		return false
	
	return true

func _execute_ability(holder, target_data) -> void:
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if not entity:
		return
	
	# Set boost state
	if "is_boosting" in entity:
		entity.is_boosting = true
	if "boost_timer" in entity:
		entity.boost_timer = boost_duration
	
	# Report to action feed if this is a chatter
	if entity.has_method("get_chatter_username") and GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.add_message("💨 " + entity.get_chatter_username() + " used BOOST!", Color(0.5, 1, 1))
	
	# Create visual effects
	_create_boost_effects(entity)
	
	# Start cooldown
	_start_cooldown(holder)
	
	# Notify holder
	holder.on_ability_executed(self)
	executed.emit(target_data)

func _create_boost_effects(entity: Node) -> void:
	# Speed trail particles
	var particles = CPUParticles2D.new()
	particles.amount = 50
	particles.lifetime = 0.5
	particles.preprocess = 0.0
	particles.emitting = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	particles.spread = 20.0
	particles.initial_velocity_min = -100.0
	particles.initial_velocity_max = -200.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.5
	particles.color = Color(0.5, 1, 1, 0.8)  # Cyan speed effect
	entity.add_child(particles)
	particles.name = "BoostParticles"
	
	# Glow effect on sprite
	var sprite = entity.get_node_or_null("sprite")
	if not sprite:
		sprite = entity.get_node_or_null("SpriteContainer/Sprite")
	if sprite:
		sprite.modulate = boost_color
