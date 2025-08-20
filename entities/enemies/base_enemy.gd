extends BaseEntity
class_name BaseEnemy

## Base class for all enemy types
## Extends BaseEntity with enemy-specific functionality

signal attack_performed()

## Attack type determines movement behavior
enum AttackType {
	MELEE,    ## Enemy will zerg rush the player to get in melee range
	RANGED    ## Enemy will maintain optimal distance for ranged attacks
}

@onready var visual_scaler: VisualScalingComponent = VisualScalingComponent.new()

@export_group("Enemy Stats")
@export var damage: float = 10.0
@export var attack_range: float = 70.0
@export var attack_cooldown: float = 0.5
@export var attack_type: AttackType = AttackType.MELEE
@export var preferred_attack_distance: float = -1.0  ## If -1, uses attack_range for ranged, attack_range * 0.8 for melee

@export_group("Visual Effects")
@export var enemy_light_type: EnemyLight.EnemyLightType = EnemyLight.EnemyLightType.NONE
@export var is_elite: bool = false  ## Elite enemies get enhanced lighting

# State
var target_player: Player = null
var can_attack: bool = true
var attack_timer: float = 0.0
var is_fleeing: bool = false
var flee_target: Node2D = null

# Regeneration
var regeneration_rate: float = 0.0  # HP per second

func _entity_ready():
	super._entity_ready()
	
	# Make sure enemy pauses properly
	process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# DISABLE I-FRAMES FOR ENEMIES - allows multi-hitting
	invincibility_time = 0.0
	
	# Add enemy tag
	taggable.permanent_tags.append("Enemy")
	taggable.add_tag("Enemy")
	
	# Add to enemies group
	add_to_group("enemies")
	add_to_group("ai_controlled")  # For AI movement system
	
	# Find player immediately - no aggro needed
	_find_player()
	
	# Initialize visual scaling component
	add_child(visual_scaler)
	visual_scaler.initialize(self)
	
	# Create enemy light if specified
	if enemy_light_type != EnemyLight.EnemyLightType.NONE:
		var light = EnemyLight.create_for_enemy(self, enemy_light_type)
		if light and is_elite:
			light.enhance_for_elite()
	
	# Set up proper AI movement controller with pathfinding
	var ai_controller = ZombieMovementController.new()
	ai_controller.name = "AIMovementController"
	
	# Set arrival distance based on attack type
	if preferred_attack_distance > 0:
		ai_controller.arrival_distance = preferred_attack_distance
	else:
		match attack_type:
			AttackType.MELEE:
				# Melee enemies NEVER stop - they want to be INSIDE the player
				ai_controller.arrival_distance = 0.0
			AttackType.RANGED:
				# Ranged enemies maintain optimal distance (stay at max range)
				ai_controller.arrival_distance = attack_range * 0.9
	
	ai_controller.ray_length = 150.0  # Detect obstacles ahead
	ai_controller.avoidance_force = 2.0  # Stronger obstacle avoidance
	ai_controller.obstacle_mask = 1  # Assuming layer 1 for obstacles
	
	# Flocking is authoritative; local separation now handled by FlockingSystem
	# No need to set separation_force as it no longer exists in ZombieMovementController
	
	add_child(ai_controller)

func _entity_physics_process(delta):
	# Check if AI is disabled
	if DebugSettings.instance and not DebugSettings.instance.mob_ai_enabled:
		return
	
	# Process regeneration
	if regeneration_rate > 0 and current_health < max_health:
		current_health = min(current_health + regeneration_rate * delta, max_health)
	
	# Update attack cooldown
	if not can_attack:
		attack_timer -= delta
		if attack_timer <= 0:
			can_attack = true
	
	# Always target player if alive
	if not target_player or not is_instance_valid(target_player):
		_find_player()
	
	# Update AI movement target if we have a player
	if target_player and not is_fleeing:
		var ai_controller = get_node_or_null("AIMovementController")
		if ai_controller and ai_controller.has_method("set_target_position"):
			_update_ai_target_position(ai_controller)
	
	# Check if player is in range and attack
	if target_player and is_instance_valid(target_player):
		var distance = global_position.distance_to(target_player.global_position)
		
		# For melee enemies, if we're basically touching (within 40 pixels), attack immediately
		if attack_type == AttackType.MELEE and distance <= 40:
			if can_attack:
				_perform_attack()
		# Otherwise use normal attack range
		elif distance <= attack_range and can_attack:
			_perform_attack()

## Find the player in the scene
func _find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target_player = players[0]
		return target_player
	return null

## Perform an attack on the player
func _perform_attack():
	if not target_player or not target_player.is_alive:
		return
	
	# Deal damage to player
	target_player.take_damage(damage, self)
	
	# Set attack cooldown
	can_attack = false
	attack_timer = attack_cooldown
	
	# Emit signal
	attack_performed.emit()
	
	# Visual feedback
	_on_attack_performed()

## Virtual function - called when attack is performed
func _on_attack_performed():
	pass  # Override in subclasses for attack animations

## Update AI target position based on attack type
func _update_ai_target_position(ai_controller):
	var distance_to_player = global_position.distance_to(target_player.global_position)
	
	match attack_type:
		AttackType.MELEE:
			# Melee enemies always target player's exact position
			ai_controller.set_target_position(target_player.global_position)
			
		AttackType.RANGED:
			var desired_distance = preferred_attack_distance if preferred_attack_distance > 0 else attack_range * 0.9
			
			# If we're too close, move away
			if distance_to_player < desired_distance * 0.8:
				var direction_away = (global_position - target_player.global_position).normalized()
				var retreat_position = target_player.global_position + direction_away * desired_distance
				ai_controller.set_target_position(retreat_position)
			
			# If we're too far, move closer
			elif distance_to_player > desired_distance * 1.1:
				var direction_to_player = (target_player.global_position - global_position).normalized()
				var approach_position = target_player.global_position - direction_to_player * desired_distance
				ai_controller.set_target_position(approach_position)
			
			# If we're at good distance, maintain position (circle strafe could be added here)
			else:
				# Stay in place by setting target to current position
				ai_controller.set_target_position(global_position)

## Die - Drop XP orbs and clean up
func die():
	# Drop XP orbs before dying
	_drop_xp_orbs()
	
	# Notify player if they killed this enemy
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("on_enemy_killed"):
		player.on_enemy_killed(self)
	
	# Call parent die function
	super.die()

## Drop XP orbs on death
func _drop_xp_orbs():
	# Check if XP drops are disabled
	if DebugSettings.instance and not DebugSettings.instance.xp_drops_enabled:
		return
	
	# Base XP value
	var xp_to_drop = 1
	if TagSystem.has_tag(self, "Unique"):
		xp_to_drop = 10
	
	# Scale XP based on MXP buffs the entity has used
	if has_method("get_twitch_username"):
		var username = call("get_twitch_username")
		if username and ChatterEntityManager.instance:
			var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
			var total_mxp_spent = chatter_data.get("total_upgrades", 0)
			
			# Each MXP spent increases XP drop by 1
			xp_to_drop += total_mxp_spent
			
			# XP scaled based on MXP spent
	
	# Create XP orb(s) with proper positioning
	var parent_node = get_parent()
	var death_position = global_position
	
	for i in range(xp_to_drop):
		# Create a wrapper function to spawn the orb at the correct position
		call_deferred("_spawn_xp_orb_at_position", parent_node, death_position, i, xp_to_drop)

func _spawn_xp_orb_at_position(parent_node: Node, death_pos: Vector2, index: int, total: int):
	var xp_orb = preload("res://entities/pickups/xp_orb.tscn").instantiate()
	
	# Set position before adding to scene tree
	var spread_radius = 20.0 if total > 1 else 0.0
	var angle = (TAU / total) * index
	var offset = Vector2(cos(angle), sin(angle)) * spread_radius
	xp_orb.global_position = death_pos + offset
	
	# Add to scene
	parent_node.add_child(xp_orb)
	
	# Set XP value (1 per orb)
	xp_orb.xp_value = 1

## Check if enemy is in aggro state (always true now)
func is_aggro() -> bool:
	return target_player != null

## Check if enemy is currently attacking
func is_attacking() -> bool:
	return attack_timer > 0.0 and target_player != null

## Check if enemy is dying (for light fade out)
func is_dying() -> bool:
	return current_health <= 0

## Get attack name for death attribution
func get_attack_name() -> String:
	return "bite"  # Default attack name for basic enemies

## Set regeneration rate
func set_regeneration(rate: float):
	regeneration_rate = rate
