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
	
	# AI always targets player now - no configuration needed

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
	attack_range = 300.0  # Ability range for heart projectiles
	attack_cooldown = 1.0
	
	# Configure as ranged attacker
	attack_type = AttackType.RANGED
	preferred_attack_distance = 280.0  # Stay at comfortable shooting distance (doubled)
	
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

# State for moving to succ range
var succ_move_target: Node = null
var succ_desired_range: float = 0.0

func _on_suction_request_move(target: Node, desired_range: float):
	# Set up movement towards target for succ ability
	succ_move_target = target
	succ_desired_range = desired_range
	print("💋 Moving to SUCC range: ", desired_range)

func _entity_physics_process(delta):
	# No need to check channeling here - ability handles movement stop internally
	
	# Handle moving to succ range if requested
	if succ_move_target and is_instance_valid(succ_move_target):
		var distance = global_position.distance_to(succ_move_target.global_position)
		
		# Check if we're in range now
		if distance <= succ_desired_range:
			# Try to execute succ ability
			if suction_ability and suction_ability.can_execute(self, SuctionAbility.create_target_data(succ_move_target)):
				execute_ability("suction", SuctionAbility.create_target_data(succ_move_target))
			# Clear movement request
			succ_move_target = null
			succ_desired_range = 0.0
		else:
			# Move towards target
			var direction = (succ_move_target.global_position - global_position).normalized()
			movement_velocity = direction * move_speed
			# Let base handle the actual movement
			super._entity_physics_process(delta)
			return
	
	# Let base enemy handle AI and movement
	super._entity_physics_process(delta)
	
	# Check if we should attack (always when player exists)
	if target_player and is_instance_valid(target_player):
		var distance = global_position.distance_to(target_player.global_position)
		
		# Try to use Succ ability - will request movement if out of range
		if suction_ability and suction_ability.can_execute(self, SuctionAbility.create_target_data(target_player)):
			execute_ability("suction", SuctionAbility.create_target_data(target_player))
		# Otherwise shoot projectiles
		elif heart_projectile_ability and heart_projectile_ability.can_execute(self, HeartProjectileAbility.create_target_data(target_player)):
			if distance <= heart_projectile_ability.base_range:
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
