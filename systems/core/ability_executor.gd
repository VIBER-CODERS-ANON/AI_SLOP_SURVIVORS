extends Node
class_name AbilityExecutor

## MODULAR ABILITY EXECUTION SYSTEM
## Executes abilities from AbilityResource definitions
## Works with both multimesh enemies (data-oriented) and node-based bosses

static var instance: AbilityExecutor

signal ability_executed(entity_id: int, ability_id: String)
signal ability_failed(entity_id: int, ability_id: String, reason: String)

# Ability cooldowns per entity
var entity_cooldowns: Dictionary = {}  # entity_id -> Dictionary[ability_id -> float]

# Active abilities tracking
var active_abilities: Dictionary = {}  # entity_id -> Array[AbilityResource]

# References to other systems
var enemy_manager: EnemyManager
var game_controller: Node

func _ready():
	instance = self
	call_deferred("_connect_to_systems")
	print("⚡ AbilityExecutor initialized")

func _connect_to_systems():
	enemy_manager = EnemyManager.instance
	game_controller = GameController.instance
	
	if enemy_manager:
		print("✅ AbilityExecutor connected to EnemyManager")
	else:
		print("⚠️ AbilityExecutor: EnemyManager not found")

func _process(delta: float):
	_update_cooldowns(delta)
	_update_ability_ai(delta)

func _update_cooldowns(delta: float):
	for entity_id in entity_cooldowns:
		var cooldowns = entity_cooldowns[entity_id]
		for ability_id in cooldowns:
			if cooldowns[ability_id] > 0:
				cooldowns[ability_id] -= delta

# AI system for ability execution
func _update_ability_ai(delta: float):
	if not enemy_manager or not game_controller or not game_controller.player:
		return
	
	# Debug: Show how many entities have abilities (use member var instead of static)
	if not has_meta("debug_timer"):
		set_meta("debug_timer", 0.0)
	var debug_timer = get_meta("debug_timer") + delta
	set_meta("debug_timer", debug_timer)
	if active_abilities.size() > 0 and debug_timer > 2.0:
		set_meta("debug_timer", 0.0)
		print("🔍 AbilityExecutor tracking %d entities with abilities" % active_abilities.size())
	
	# Process each entity with registered abilities
	for entity_id in active_abilities:
		# Skip dead entities
		if entity_id >= enemy_manager.alive_flags.size() or enemy_manager.alive_flags[entity_id] == 0:
			continue
		
		# Skip entities currently casting
		if entity_id < enemy_manager.ability_casting_flags.size() and enemy_manager.ability_casting_flags[entity_id] > 0:
			continue
		
		# Get entity position
		var entity_pos = _get_entity_position(entity_id)
		if entity_pos == Vector2.INF:
			continue
		
		var player_pos = game_controller.player.global_position
		var distance_to_player = entity_pos.distance_to(player_pos)
		
		# Try abilities in order (priority based on array order)
		var abilities = active_abilities[entity_id]
		for ability_res in abilities:
			if not ability_res is AbilityResource:
				continue
			
			# Skip passive abilities
			if ability_res.trigger_type == "passive":
				continue
			
			# Skip command-only abilities
			var is_command_only = ability_res.additional_parameters.get("command_only", false)
			if is_command_only:
				continue
			
			# Check cooldown - if on cooldown, skip to next ability
			if not _check_cooldown(entity_id, ability_res.ability_id):
				continue
			
			# IMPORTANT: If we reach here, the ability is OFF cooldown
			# This means we MUST try to use it and NOT fall through to other abilities
			# The only exception is if we're out of range - then we wait
			
			# Check if we're in range for this ability
			var range_buffer = 0.95 if ability_res.trigger_type == "channeled" else 1.0
			if distance_to_player > ability_res.ability_range * range_buffer:
				# Out of range for our highest priority ability that's off cooldown
				# DON'T try other abilities - just wait to get in range
				break
			
			# We're in range and off cooldown - prepare to execute
			var target_data = _prepare_target_data(ability_res, entity_pos, player_pos)
			
			print("🎮 Entity %d attempting ability: %s (range: %.0f, distance: %.0f)" % [entity_id, ability_res.ability_id, ability_res.ability_range, distance_to_player])
			
			# Try to execute ability
			if execute_ability(entity_id, ability_res, target_data):
				print("  ✅ Ability executed successfully!")
			else:
				print("  ❌ Ability execution failed!")
			
			# Whether it succeeded or failed, we tried our highest priority ability
			# Don't fall through to lower priority abilities
			break


# Prepare target data based on ability type
func _prepare_target_data(ability: AbilityResource, entity_pos: Vector2, player_pos: Vector2) -> Dictionary:
	var target_data = {
		"target_position": player_pos,
		"target_enemy": game_controller.player if game_controller.player else null,
		"direction": (player_pos - entity_pos).normalized()
	}
	
	# That's it! Simple and generic
	# Each ability handler will use what it needs from the target_data
	
	return target_data

# Register abilities for an entity from resources
func register_entity_abilities(entity_id: int, abilities: Array):
	if not active_abilities.has(entity_id):
		active_abilities[entity_id] = []
		entity_cooldowns[entity_id] = {}
	
	for ability in abilities:
		if ability is AbilityResource:
			active_abilities[entity_id].append(ability)
			entity_cooldowns[entity_id][ability.ability_id] = 0.0
			print("  ✅ Registered ability: %s for entity %d" % [ability.ability_id, entity_id])
		else:
			print("  ❌ Invalid ability resource in array")
	
	print("  📊 Entity %d now has %d abilities" % [entity_id, active_abilities[entity_id].size()])

# Execute ability from resource
func execute_ability(entity_id: int, ability_res: AbilityResource, target_data: Dictionary = {}):
	if not ability_res:
		ability_failed.emit(entity_id, "unknown", "Invalid ability resource")
		return false
	
	# Check cooldown
	if not _check_cooldown(entity_id, ability_res.ability_id):
		ability_failed.emit(entity_id, ability_res.ability_id, "On cooldown")
		return false
	
	# Get entity position (works for both multimesh and node entities)
	var entity_pos = _get_entity_position(entity_id)
	if entity_pos == Vector2.INF:
		ability_failed.emit(entity_id, ability_res.ability_id, "Invalid entity position")
		return false
	
	# Execute based on trigger type
	var success = false
	match ability_res.trigger_type:
		"instant":
			success = _execute_instant(entity_id, ability_res, entity_pos, target_data)
		"projectile":
			success = _execute_projectile(entity_id, ability_res, entity_pos, target_data)
		"channeled":
			success = _execute_channeled(entity_id, ability_res, entity_pos, target_data)
		"area":
			success = _execute_area(entity_id, ability_res, entity_pos, target_data)
		"passive":
			# Passive abilities don't execute actively
			return true
		_:
			ability_failed.emit(entity_id, ability_res.ability_id, "Unknown trigger type")
			return false
	
	if success:
		# Set cooldown
		_set_cooldown(entity_id, ability_res.ability_id, ability_res.cooldown)
		ability_executed.emit(entity_id, ability_res.ability_id)
	
	return success

# Execute ability by ID (convenience method)
func execute_ability_by_id(entity_id: int, ability_id: String, target_data: Dictionary = {}):
	if not active_abilities.has(entity_id):
		ability_failed.emit(entity_id, ability_id, "Entity has no abilities")
		return false
	
	for ability in active_abilities[entity_id]:
		if ability.ability_id == ability_id:
			return execute_ability(entity_id, ability, target_data)
	
	ability_failed.emit(entity_id, ability_id, "Ability not found")
	return false

func _execute_instant(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Check for custom script first (most modular approach)
	if ability.custom_script:
		return _execute_custom_script(entity_id, ability, pos, target_data)
	
	# Fallback to generic effect spawning
	if ability.effect_scene:
		var effect = ability.effect_scene.instantiate()
		effect.global_position = pos
		
		# Apply scaling modifiers
		var aoe_scale = _get_entity_aoe_scale(entity_id)
		if aoe_scale > 1.0:
			effect.scale *= aoe_scale
		
		# Set damage if the effect has it
		if "damage" in effect:
			var damage_mult = _get_entity_damage_mult(entity_id)
			effect.damage = ability.damage * damage_mult
		
		# Set source for proper attribution
		var username = _get_entity_username(entity_id)
		if username != "" and "source_name" in effect:
			effect.source_name = username
		
		if game_controller:
			game_controller.add_child(effect)
		else:
			get_tree().current_scene.add_child(effect)
	
	# Play sound if configured
	if ability.sound_effect:
		_play_sound_at(ability.sound_effect, pos)
	
	return true

func _execute_projectile(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Get target position for validation
	if ability.custom_script:
		return _execute_custom_script(entity_id, ability, pos, target_data)
	var target_pos = target_data.get("target_position", Vector2.ZERO)
	if target_pos == Vector2.ZERO and game_controller and game_controller.player:
		target_pos = game_controller.player.global_position
	
	# Check range
	var distance = pos.distance_to(target_pos)
	if distance > ability.ability_range:
		return false
	
	# Handle windup if configured
	if ability.windup_duration > 0:
		# Mark entity as casting
		if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
			enemy_manager.ability_casting_flags[entity_id] = 1
			
			# Create windup timer
			var timer = Timer.new()
			timer.wait_time = ability.windup_duration
			timer.one_shot = true
			timer.timeout.connect(_fire_projectile_after_windup.bind(entity_id, ability, pos, target_pos))
			add_child(timer)
			timer.start()
		
		return true
	else:
		# Fire immediately
		return _fire_projectile(entity_id, ability, pos, target_pos)

func _fire_projectile_after_windup(entity_id: int, ability: AbilityResource, pos: Vector2, target_pos: Vector2):
	# Clear casting flag
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 0
	
	# Fire projectile
	_fire_projectile(entity_id, ability, pos, target_pos)

func _fire_projectile(entity_id: int, ability: AbilityResource, pos: Vector2, target_pos: Vector2) -> bool:
	# Play sound when projectile fires
	if ability.sound_effect:
		_play_sound_at(ability.sound_effect, pos)
	
	var projectile = null
	
	# Create projectile based on available configuration
	if ability.projectile_texture:
		# Use generic sprite projectile
		projectile = GenericProjectile.new()
		projectile.global_position = pos
		
	elif ability.effect_scene:
		# Use custom scene projectile
		projectile = ability.effect_scene.instantiate()
		projectile.global_position = pos
	else:
		return false  # No projectile configuration
	
	# Set projectile lifetime from duration
	if "lifetime" in projectile and ability.duration > 0:
		projectile.lifetime = ability.duration
	
	# Set projectile properties
	if "damage" in projectile:
		var damage_mult = _get_entity_damage_mult(entity_id)
		projectile.damage = ability.damage * damage_mult
	
	if "speed" in projectile:
		projectile.speed = ability.projectile_speed
	
	# Setup projectile with direction and attribution
	var direction = (target_pos - pos).normalized()
	
	if projectile.has_method("setup"):
		var damage_mult = _get_entity_damage_mult(entity_id)
		var final_damage = ability.damage * damage_mult
		
		# Create proxy entity for attribution
		var proxy = Node2D.new()
		proxy.global_position = pos
		proxy.set_meta("entity_id", entity_id)
		
		projectile.setup(direction, ability.projectile_speed, final_damage, proxy)
		proxy.queue_free()
	elif projectile.has_method("set_direction"):
		projectile.set_direction(direction)
	
	# Set source for attribution
	var username = _get_entity_username(entity_id)
	if username != "" and "source_name" in projectile:
		projectile.source_name = username
	
	# Add to scene
	if game_controller:
		game_controller.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)
	
	# Configure visual for generic projectiles after adding to scene
	if ability.projectile_texture and projectile.has_method("configure_visual"):
		projectile.configure_visual(ability.projectile_texture, ability.projectile_collision_radius, ability.projectile_scale)
	
	return true

func _execute_channeled(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Check for custom script first (self-contained abilities)
	if ability.custom_script:
		return _execute_custom_script(entity_id, ability, pos, target_data)
	
	# Generic channeled handling for effect_scene based abilities
	# Mark entity as casting (stops movement)
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 1
		
		# Create timer to end channel
		var timer = Timer.new()
		timer.wait_time = ability.duration if ability.duration > 0 else ability.cast_time
		timer.one_shot = true
		timer.timeout.connect(_end_channel.bind(entity_id))
		add_child(timer)
		timer.start()
	
	# Create channeling effect
	if ability.effect_scene:
		var effect = ability.effect_scene.instantiate()
		effect.global_position = pos
		
		# Apply scaling
		var aoe_scale = _get_entity_aoe_scale(entity_id)
		if aoe_scale > 1.0:
			effect.scale *= aoe_scale
		
		# Set channel duration
		if "duration" in effect:
			effect.duration = ability.duration if ability.duration > 0 else ability.cast_time
		
		# Set damage
		if "damage" in effect:
			var damage_mult = _get_entity_damage_mult(entity_id)
			effect.damage = ability.damage * damage_mult
		
		# Set source
		var username = _get_entity_username(entity_id)
		if username != "" and "source_name" in effect:
			effect.source_name = username
		
		if game_controller:
			game_controller.add_child(effect)
		else:
			get_tree().current_scene.add_child(effect)
	
	return true

func _execute_area(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	# Create area effect
	if ability.custom_script:
		return _execute_custom_script(entity_id, ability, pos, target_data)
	if ability.effect_scene:
		var area = ability.effect_scene.instantiate()
		area.global_position = pos
		
		# Set area properties
		if "radius" in area:
			var aoe_scale = _get_entity_aoe_scale(entity_id)
			area.radius = ability.ability_range * aoe_scale
		
		if "damage" in area:
			var damage_mult = _get_entity_damage_mult(entity_id)
			area.damage = ability.damage * damage_mult
		
		if "duration" in area:
			area.duration = ability.duration
		
		# Set source
		var username = _get_entity_username(entity_id)
		if username != "" and "source_name" in area:
			area.source_name = username
		
		if game_controller:
			game_controller.add_child(area)
		else:
			get_tree().current_scene.add_child(area)
	
	return true

func _end_channel(entity_id: int):
	if enemy_manager and entity_id < enemy_manager.ability_casting_flags.size():
		enemy_manager.ability_casting_flags[entity_id] = 0

# Cooldown management
func _check_cooldown(entity_id: int, ability_id: String) -> bool:
	if not entity_cooldowns.has(entity_id):
		return true
	
	var cooldowns = entity_cooldowns[entity_id]
	if not cooldowns.has(ability_id):
		return true
	
	return cooldowns[ability_id] <= 0

func _set_cooldown(entity_id: int, ability_id: String, cooldown: float):
	if not entity_cooldowns.has(entity_id):
		entity_cooldowns[entity_id] = {}
	
	entity_cooldowns[entity_id][ability_id] = cooldown

# Helper functions
func _get_entity_position(entity_id: int) -> Vector2:
	# Check for player entity (negative ID -1)
	if entity_id == -1 and game_controller and game_controller.player:
		return game_controller.player.global_position
	
	# Check if it's a multimesh enemy
	if enemy_manager and entity_id >= 0 and entity_id < enemy_manager.positions.size():
		if enemy_manager.alive_flags[entity_id] > 0:
			return enemy_manager.positions[entity_id]
	
	# Check if it's a node-based entity (boss)
	# Bosses use negative IDs or are tracked separately
	# This would need to be implemented based on your boss tracking system
	
	return Vector2.INF

func _get_entity_username(entity_id: int) -> String:
	if enemy_manager and entity_id >= 0 and entity_id < enemy_manager.chatter_usernames.size():
		return enemy_manager.chatter_usernames[entity_id]
	return ""

func _get_entity_aoe_scale(entity_id: int) -> float:
	var username = _get_entity_username(entity_id)
	if username != "" and ChatterEntityManager.instance:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		if chatter_data and chatter_data.upgrades.has("bonus_aoe"):
			var bonus_aoe = chatter_data.upgrades.bonus_aoe
			var rarity_mult = chatter_data.upgrades.get("rarity_multiplier", 1.0)
			return (1.0 + bonus_aoe) * rarity_mult
	return 1.0

func _get_entity_damage_mult(entity_id: int) -> float:
	var username = _get_entity_username(entity_id)
	if username != "" and ChatterEntityManager.instance:
		var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
		if chatter_data and chatter_data.upgrades.has("bonus_damage"):
			var bonus_damage = chatter_data.upgrades.bonus_damage
			var rarity_mult = chatter_data.upgrades.get("rarity_multiplier", 1.0)
			return (1.0 + bonus_damage) * rarity_mult
	return 1.0

func _play_sound_at(sound: AudioStream, position: Vector2):
	if AudioManager.instance:
		AudioManager.instance.play_sfx_at_position(sound, position)

# Cleanup when entity is removed
func cleanup_entity(entity_id: int):
	if active_abilities.has(entity_id):
		active_abilities.erase(entity_id)
	if entity_cooldowns.has(entity_id):
		entity_cooldowns.erase(entity_id)

# Custom script execution
func _execute_custom_script(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	"""Execute ability using custom script behavior"""
	if not ability.custom_script:
		print("❌ No custom script provided for ability: %s" % ability.ability_id)
		return false
	
	# Instantiate the custom behavior script
	var behavior: BaseAbilityBehavior = ability.custom_script.new()
	if not behavior:
		print("❌ Failed to instantiate behavior script for ability: %s" % ability.ability_id)
		return false
	
	# Execute the custom behavior
	var success = behavior.execute(entity_id, ability, pos, target_data)
	
	if success:
		print("✅ Custom script executed successfully for ability: %s" % ability.ability_id)
	else:
		print("❌ Custom script execution failed for ability: %s" % ability.ability_id)
	
	return success
