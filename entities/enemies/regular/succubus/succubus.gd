extends BaseEvolvedCreature
class_name Succubus

## Succubus - An evolved Twitch chatter entity
## Flying enemy that shoots heart projectiles and has a channeled drain ability

# Abilities
var heart_projectile_ability: HeartProjectileAbility
var suction_ability: SuctionAbility

func _entity_ready():
	# Set evolution config before parent ready
	evolution_mxp_cost = 10
	evolution_name = "Succubus"
	
	super._entity_ready()
	_setup_evolution()
	
	# Disable the AI movement controller since we handle movement through abilities
	var ai_controller = get_node_or_null("AIMovementController")
	if ai_controller:
		ai_controller.set_physics_process(false)
		ai_controller.set_process(false)

func _setup_evolution():
	# Set creature type and properties
	creature_type = "Succubus"
	base_scale = 1.0
	abilities = ["shoot_hearts", "succ"]
	
	# Set succubus-specific tags
	if taggable:
		taggable.permanent_tags = ["Enemy", "Flying", "Evolved", "Succubus", "TwitchMob"]
		taggable.add_tag("Flying")
		taggable.add_tag("Evolved")
		taggable.add_tag("Succubus")
		taggable.add_tag("Ranged")  # Mark as ranged attacker
	
	# Set stats - stronger than a basic rat
	max_health = 50.0
	current_health = max_health
	move_speed = 180.0  # Faster than ground units
	damage = 0.0  # No contact damage - succubus only damages through abilities
	attack_range = 0.0  # Set to 0 to prevent BaseEnemy attack logic if it somehow runs
	attack_cooldown = 999.0  # Very long cooldown to prevent any base attacks
	
	# Configure as ranged attacker
	attack_type = AttackType.RANGED
	# No preferred_attack_distance - abilities handle their own positioning
	
	# Flying units have different collision
	collision_layer = 2  # Enemies layer
	collision_mask = 3   # Can be hit by player weapons
	
	# Audio for suction is handled inside SuctionAbility; no entity-level audio setup needed
	
	# Add to twitch_rats group for boss buff application
	add_to_group("twitch_rats")
	
	# Set up abilities using the modular system
	call_deferred("_setup_abilities")
	
	print("💋 Succubus spawned: %s" % chatter_username)
	_show_spawn_effect()
	

# Set up abilities with proper configuration
func _setup_abilities():
	await get_tree().create_timer(0.1).timeout
	
	AbilitySetupHelper.setup_abilities(self, [])
	
	if ability_manager:
		# Heart Projectile ability
		heart_projectile_ability = HeartProjectileAbility.new()
		heart_projectile_ability.request_move_to_range.connect(_on_heart_request_move)
		add_ability(heart_projectile_ability)
		
		# Suction ability
		suction_ability = SuctionAbility.new()
		# Connect signals for compatibility
		suction_ability.succ_started.connect(func(target): succ_started.emit(target))
		suction_ability.succ_ended.connect(func(): succ_ended.emit())
		suction_ability.request_move_to_target.connect(_on_suction_request_move)
		add_ability(suction_ability)

# Keep signal declarations for compatibility
signal succ_started(target: Node)
signal succ_ended()

# State for moving to ability range
var ability_move_target: Node = null
var ability_desired_range: float = 0.0
var ability_type: String = ""  # Track which ability requested movement

func _on_suction_request_move(target: Node, desired_range: float):
	# Set up movement towards target for succ ability
	ability_move_target = target
	ability_desired_range = desired_range
	ability_type = "suction"
	print("💋 Moving to SUCC range: ", desired_range)

func _on_heart_request_move(target: Node, desired_range: float):
	# Set up movement towards target for heart projectile ability
	ability_move_target = target
	ability_desired_range = desired_range
	ability_type = "heart"
	print("💋 Moving to heart projectile range: ", desired_range)

## Override to prevent BaseEnemy AI movement
func _update_ai_target_position(_ai_controller):
	# Do nothing - succubus handles its own movement through abilities
	pass

func _entity_physics_process(delta):
	# DO NOT call super - we handle everything ourselves to avoid BaseEnemy AI
	
	# Find player if needed (from BaseEnemy)
	if not target_player or not is_instance_valid(target_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			target_player = players[0]
	
	# Update ability cooldowns
	if suction_ability:
		suction_ability.update(delta, self)
	if heart_projectile_ability:
		heart_projectile_ability.update(delta, self)
	
	# Check if any ability is casting/channeling - if so, don't move or attack
	var is_casting = (suction_ability and suction_ability.is_channeling) or (heart_projectile_ability and heart_projectile_ability.is_winding_up)
	if is_casting:
		movement_velocity = Vector2.ZERO
		velocity = movement_velocity + knockback_velocity
		move_and_slide()
		return  # Don't process movement or attacks while casting
	
	# Handle moving to ability range if requested
	if ability_move_target and is_instance_valid(ability_move_target):
		var distance = global_position.distance_to(ability_move_target.global_position)
		
		# Check if we're in range now
		if distance <= ability_desired_range:
			# Try to execute the appropriate ability
			match ability_type:
				"suction":
					if suction_ability and suction_ability.can_execute(self, SuctionAbility.create_target_data(ability_move_target)):
						execute_ability("suction", SuctionAbility.create_target_data(ability_move_target))
				"heart":
					if heart_projectile_ability and heart_projectile_ability.can_execute(self, HeartProjectileAbility.create_target_data(ability_move_target)):
						execute_ability("heart_projectile", HeartProjectileAbility.create_target_data(ability_move_target))
			
			# Clear movement request
			ability_move_target = null
			ability_desired_range = 0.0
			ability_type = ""
		else:
			# Move towards target for ability
			var direction = (ability_move_target.global_position - global_position).normalized()
			movement_velocity = direction * move_speed
	else:
		# NO MOVEMENT when not moving for abilities - succubus is ranged only
		movement_velocity = Vector2.ZERO
	
	# Process knockback (from BaseEntity)
	if knockback_velocity.length() > 0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 500 * delta)
	
	# Handle physics manually - NEVER call super to avoid base enemy chase behavior
	velocity = movement_velocity + knockback_velocity
	move_and_slide()
	_face_movement_direction()
	
	# Check if we should attack (always when player exists)
	# Only check when not already moving for an ability
	if not ability_move_target and target_player and is_instance_valid(target_player):
		# Try to use Succ ability first (higher priority) - will request movement if out of range
		if suction_ability and suction_ability.can_execute(self, SuctionAbility.create_target_data(target_player)):
			execute_ability("suction", SuctionAbility.create_target_data(target_player))
		# Otherwise try heart projectiles - will request movement if out of range
		elif heart_projectile_ability and heart_projectile_ability.can_execute(self, HeartProjectileAbility.create_target_data(target_player)):
			execute_ability("heart_projectile", HeartProjectileAbility.create_target_data(target_player))
	

# Visual feedback on spawn (no more aggro state)
func _show_spawn_effect():
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.2, 0.5, 1), 0.1)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

func _face_movement_direction():
	if not sprite:
		return
	
	if velocity.x != 0:
		# IMPORTANT: Calculate actual scale including MXP buffs
		var actual_scale = base_scale * scale_multiplier
		# Sprite faces RIGHT by default
		if velocity.x > 0:
			sprite.scale.x = actual_scale
		else:
			sprite.scale.x = -actual_scale

# Flying movement is already handled by the AI controller and BaseEntity
# The AI controller sets movement_velocity on the entity
# No need to override movement for flying units

## Override die to clean up
func die():
	# End succ if active (through ability system)
	if suction_ability and suction_ability.is_channeling:
		suction_ability._end_channel()
	
	# Force stop any lingering audio IMMEDIATELY
	var audio_player = get_node_or_null("SuccAudioPlayer")
	if audio_player:
		audio_player.stop()
		audio_player.playing = false
		audio_player.stream_paused = true
		audio_player.stream = null
	
	# Call parent die
	super.die()

# Override attack to prevent any contact damage
func _perform_attack():
	# Succubus doesn't do contact damage - only abilities
	pass

# Override attack name for death messages (in case something goes wrong)
func get_attack_name() -> String:
	return "magic"

# BaseCreature already handles get_display_name, set_chatter_data, etc.
# No need to override these methods

## Override execute_ability for proper ability names
func execute_ability(ability_name: String, target_data = null) -> bool:
	# Map old names to new ability IDs for compatibility
	match ability_name:
		"shoot_hearts":
			return execute_ability("heart_projectile", target_data)
		"succ":
			return execute_ability("suction", target_data)
		_:
			return super.execute_ability(ability_name, target_data)
