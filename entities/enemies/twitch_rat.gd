extends BaseCreature
class_name TwitchRat

# Twitch chat spawned rat creature

# Boost system
var is_boosting: bool = false
var boost_timer: float = 0.0

# Abilities
var explosion_ability: ExplosionAbility
var fart_ability: FartAbility
var boost_ability: BoostAbility

# Boss buff modifiers
var boss_speed_multiplier: float = 1.0


func _entity_ready():
	super._entity_ready()
	_setup_twitch_rat()
	
	# Add to twitch_rats group for boss buff application
	add_to_group("twitch_rats")
	
	# AI always targets player now - no configuration needed
	
	# Set up abilities
	call_deferred("_setup_abilities")
	_show_spawn_effect()

func _setup_twitch_rat():
	# Set creature type
	creature_type = "Rat"
	base_scale = 0.8
	abilities = ["explode", "fart", "boost"]
	
	# Set rat-specific stats
	max_health = 10
	current_health = max_health
	damage = 1
	move_speed = 120
	attack_range = 60  # Increased from 30 to ensure contact damage
	attack_cooldown = 1.0
	attack_type = AttackType.MELEE  # Rats are melee attackers
	
	# No mana for rats
	has_mana = false
	
	# Add tags
	if taggable:
		taggable.add_tag("Lesser")  # All twitch rats are lesser mobs
		taggable.add_tag("TwitchMob")
		taggable.add_tag("Rat")
		taggable.add_tag("Melee")  # Mark as melee attacker
	
	# Set collision layers - same as other enemies
	collision_layer = 2  # Enemies layer
	collision_mask = 3   # Detect Player and Weapons
	

# Set up abilities
func _setup_abilities():
	await get_tree().create_timer(0.1).timeout
	
	AbilitySetupHelper.setup_abilities(self, [])
	
	# Add abilities directly to ability_manager
	if ability_manager:
		# Explosion ability
		explosion_ability = ExplosionAbility.new()
		explosion_ability.base_cooldown = 2.0
		add_ability(explosion_ability)
		
		# Fart ability
		fart_ability = FartAbility.new()
		fart_ability.base_cooldown = 100.0
		add_ability(fart_ability)
		
		# Boost ability
		boost_ability = BoostAbility.new()
		boost_ability.base_cooldown = 20.0
		add_ability(boost_ability)
	
	# Registration now handled by TicketSpawnManager
	if has_meta("pending_username"):
		remove_meta("pending_username")

func _entity_physics_process(_delta: float):
	# Update boost timer
	if is_boosting:
		boost_timer -= _delta
		if boost_timer <= 0:
			_end_boost()
	
	# Let base enemy handle all AI and movement
	super._entity_physics_process(_delta)
	
	# Apply speed boost if active
	var ai_controller = get_node_or_null("AIMovementController")
	if ai_controller and ai_controller.has_method("set_max_speed_factor"):
		if is_boosting:
			ai_controller.max_speed_factor = 3.0
		else:
			ai_controller.max_speed_factor = 1.0
	
	# Face movement direction (flip sprite)
	_face_movement_direction()

# Visual feedback on spawn (no more aggro state)
func _show_spawn_effect():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _face_movement_direction():
	if not sprite:
		return
		
	# Face based on movement direction
	if movement_velocity.x != 0:
		# Use flip_h to avoid scale conflicts with MXP buffs
		sprite.flip_h = movement_velocity.x < 0  # Flip when moving left

func trigger_explode():
	if not is_alive:
		return
	
	# Use ability system - abilities expect the holder component, not the entity
	if explosion_ability and ability_holder and explosion_ability.can_execute(ability_holder, {}):
		execute_ability("explosion")

func trigger_fart():
	if not is_alive:
		return
	
	# Use ability system - abilities expect the holder component, not the entity  
	if fart_ability and ability_holder and fart_ability.can_execute(ability_holder, {}):
		execute_ability("fart")

func trigger_boost():
	if not is_alive:
		return
	
	# Use ability system
	if boost_ability and ability_holder and boost_ability.can_execute(ability_holder, {}):
		execute_ability("boost")







func _end_boost():
	is_boosting = false
	
	# Remove particles
	var particles = get_node_or_null("BoostParticles")
	if particles:
		particles.emitting = false
		particles.queue_free()
	
	# Remove glow
	if sprite:
		sprite.modulate = Color.WHITE

# Override attack
func _perform_attack():
	super._perform_attack()

# Note: Rats cannot collect pickups because they are "lesser" mobs
# This is handled by the pickup system checking tags

## Update visual scale for upgrades
func update_visual_scale(new_multiplier: float):
	scale_multiplier = new_multiplier
	_update_visual_scale()

# Death message
func die():
	
	# Check for ZZran auto-explode buff
	if BossBuffManager.instance and BossBuffManager.instance.should_auto_explode_on_death():
		# Use ability system for explosion - abilities expect the holder component
		if explosion_ability and ability_holder and explosion_ability.can_execute(ability_holder, {}):
			execute_ability("explosion")
	
	super.die()  # This will drop XP orbs

func get_twitch_username() -> String:
	return chatter_username

func set_boss_speed_multiplier(multiplier: float):
	boss_speed_multiplier = multiplier

# Override to apply boss speed multiplier
func get_effective_move_speed() -> float:
	return move_speed * boss_speed_multiplier

## Override execute_ability for chat commands
func execute_ability(ability_name: String, target_data = null) -> bool:
	if not is_alive:
		return false
	
	match ability_name:
		"explode":
			# Use the ability system for explosion
			if explosion_ability:
				return super.execute_ability(ability_name, target_data)
			return false
		"fart":
			# Use the ability system for fart
			if fart_ability:
				return super.execute_ability(ability_name, target_data)
			return false
		"boost":
			# Use the ability system for boost
			if boost_ability:
				return super.execute_ability(ability_name, target_data)
			return false
		_:
			return super.execute_ability(ability_name, target_data)
