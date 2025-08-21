class_name BoostBuffAbility
extends BaseAbility

## Boost buff ability - temporary flat speed increase
## First proper "Buff" in the game with Duration tag
## Triggered by !boost command (no MXP cost)

# Boost properties
const BOOST_FLAT_BONUS: float = 500.0  # +500 flat speed
const BOOST_DURATION: float = 1.0  # 1 second duration  
const BOOST_COOLDOWN: float = 60.0  # 1 minute cooldown per entity

@export var boost_color: Color = Color(1.5, 2, 1.5, 1)  # Yellow-green glow

func _init() -> void:
	# Set base properties
	ability_id = "boost_buff"
	ability_name = "Speed Boost"
	ability_description = "Temporary flat speed increase (+500 speed for 1 second)"
	ability_tags = ["Buff", "Duration", "Movement", "Speed", "Temporary", "Command"]
	ability_type = 0  # ACTIVE
	
	# Ability costs and cooldown
	base_cooldown = BOOST_COOLDOWN  # 60 second cooldown per entity
	resource_costs = {}  # No resource cost (free command)
	
	# Targeting - self-targeted
	targeting_type = 0  # SELF
	base_range = 0.0

func on_added(holder) -> void:
	super.on_added(holder)
	# BoostBuffAbility added to entity

func can_execute(holder, target_data) -> bool:
	if not super.can_execute(holder, target_data):
		return false
	
	# For V2 enemies, cooldown is tracked in enemy_manager
	# This ability class is mainly for documentation/structure
	return true

func _execute_ability(holder, target_data) -> void:
	# For V2 enemies, execution is handled by EnemyBridge
	# This function would be used for node-based enemies if needed
	
	var entity = holder
	if holder.has_method("get_entity_node"):
		entity = holder.get_entity_node()
	if not entity:
		return
	
	# Report to action feed if this is a chatter
	if entity.has_method("get_chatter_username") and GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.add_message("⚡ " + entity.get_chatter_username() + " used BOOST! (+500 speed)", Color(1, 1, 0.5))
	
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
	particles.amount = 30
	particles.lifetime = 0.3
	particles.preprocess = 0.0
	particles.emitting = true
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINT
	particles.spread = 15.0
	particles.initial_velocity_min = -50.0
	particles.initial_velocity_max = -100.0
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.0
	particles.color = Color(1, 1, 0.5, 0.8)  # Yellow speed effect
	entity.add_child(particles)
	particles.name = "BoostParticles"
	
	# Auto-remove particles after duration
	var timer = Timer.new()
	timer.wait_time = BOOST_DURATION
	timer.one_shot = true
	timer.timeout.connect(func(): particles.queue_free())
	entity.add_child(timer)
	timer.start()
	
	# Glow effect on sprite
	var sprite = entity.get_node_or_null("sprite")
	if not sprite:
		sprite = entity.get_node_or_null("SpriteContainer/Sprite")
	if sprite:
		sprite.modulate = boost_color
		# Reset color after duration
		timer.timeout.connect(func(): 
			if is_instance_valid(sprite):
				sprite.modulate = Color.WHITE
		)
