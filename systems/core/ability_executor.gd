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

func _update_cooldowns(delta: float):
	for entity_id in entity_cooldowns:
		var cooldowns = entity_cooldowns[entity_id]
		for ability_id in cooldowns:
			if cooldowns[ability_id] > 0:
				cooldowns[ability_id] -= delta

# Register abilities for an entity from resources
func register_entity_abilities(entity_id: int, abilities: Array):
	if not active_abilities.has(entity_id):
		active_abilities[entity_id] = []
		entity_cooldowns[entity_id] = {}
	
	for ability in abilities:
		if ability is AbilityResource:
			active_abilities[entity_id].append(ability)
			entity_cooldowns[entity_id][ability.ability_id] = 0.0

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

func _execute_instant(entity_id: int, ability: AbilityResource, pos: Vector2, _target_data: Dictionary) -> bool:
	# Spawn effect if configured
	if ability.effect_scene:
		var effect = ability.effect_scene.instantiate()
		effect.global_position = pos
		
		# Apply scaling modifiers
		var aoe_scale = _get_entity_aoe_scale(entity_id)
		if aoe_scale > 1.0:
			effect.scale *= aoe_scale
		
		# Set damage if the effect has it
		if effect.has_property("damage"):
			var damage_mult = _get_entity_damage_mult(entity_id)
			effect.damage = ability.damage * damage_mult
		
		# Set source for proper attribution
		var username = _get_entity_username(entity_id)
		if username != "" and effect.has_property("source_name"):
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
	if not ability.effect_scene:
		return false
	
	var projectile = ability.effect_scene.instantiate()
	projectile.global_position = pos
	
	# Set projectile properties
	if projectile.has_property("damage"):
		var damage_mult = _get_entity_damage_mult(entity_id)
		projectile.damage = ability.damage * damage_mult
	
	if projectile.has_property("speed"):
		projectile.speed = ability.projectile_speed
	
	# Set direction toward target
	var target_pos = target_data.get("target_position", Vector2.ZERO)
	if target_pos == Vector2.ZERO and game_controller and game_controller.player:
		target_pos = game_controller.player.global_position
	
	if projectile.has_method("set_direction"):
		var direction = (target_pos - pos).normalized()
		projectile.set_direction(direction)
	
	# Set source
	var username = _get_entity_username(entity_id)
	if username != "" and projectile.has_property("source_name"):
		projectile.source_name = username
	
	if game_controller:
		game_controller.add_child(projectile)
	else:
		get_tree().current_scene.add_child(projectile)
	
	return true

func _execute_channeled(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
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
		if effect.has_property("duration"):
			effect.duration = ability.duration if ability.duration > 0 else ability.cast_time
		
		# Set damage
		if effect.has_property("damage"):
			var damage_mult = _get_entity_damage_mult(entity_id)
			effect.damage = ability.damage * damage_mult
		
		# Set source
		var username = _get_entity_username(entity_id)
		if username != "" and effect.has_property("source_name"):
			effect.source_name = username
		
		if game_controller:
			game_controller.add_child(effect)
		else:
			get_tree().current_scene.add_child(effect)
	
	return true

func _execute_area(entity_id: int, ability: AbilityResource, pos: Vector2, _target_data: Dictionary) -> bool:
	# Create area effect
	if ability.effect_scene:
		var area = ability.effect_scene.instantiate()
		area.global_position = pos
		
		# Set area properties
		if area.has_property("radius"):
			var aoe_scale = _get_entity_aoe_scale(entity_id)
			area.radius = ability.range * aoe_scale
		
		if area.has_property("damage"):
			var damage_mult = _get_entity_damage_mult(entity_id)
			area.damage = ability.damage * damage_mult
		
		if area.has_property("duration"):
			area.duration = ability.duration
		
		# Set source
		var username = _get_entity_username(entity_id)
		if username != "" and area.has_property("source_name"):
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
	if AudioManager.instance and AudioManager.instance.has_method("play_sound_at"):
		AudioManager.instance.play_sound_at(sound, position)
	else:
		# Fallback: create a simple audio player
		var player = AudioStreamPlayer2D.new()
		player.stream = sound
		player.global_position = position
		player.autoplay = true
		player.finished.connect(player.queue_free)
		if game_controller:
			game_controller.add_child(player)
		else:
			get_tree().current_scene.add_child(player)

# Cleanup when entity is removed
func cleanup_entity(entity_id: int):
	if active_abilities.has(entity_id):
		active_abilities.erase(entity_id)
	if entity_cooldowns.has(entity_id):
		entity_cooldowns.erase(entity_id)