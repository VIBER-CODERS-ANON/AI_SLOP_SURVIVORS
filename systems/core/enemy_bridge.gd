extends Node
class_name EnemyBridge

## ENEMY V2 INTEGRATION BRIDGE
## Connects the data-oriented EnemyManager with existing gameplay systems
## Handles abilities, effects, AI behaviors, and visual systems for V2 enemies

static var instance: EnemyBridge

# Ability execution now handled by AbilityExecutor system

# System references
var enemy_manager: EnemyManager
var config_manager: EnemyConfigManager
var lighting_manager: LightingManager
var ability_executor: AbilityExecutor  # New reference to AbilityExecutor

# V2 Enemy ability tracking
var enemy_abilities: Dictionary = {}  # enemy_id -> Array[ActiveAbility]
var ability_cooldowns: Dictionary = {}  # enemy_id -> Dictionary[ability_id -> float]

# Active effects and timers
var active_effects: Dictionary = {}  # enemy_id -> Array[ActiveEffect]

# Ability execution tracking
var last_ability_update: float = 0.0
const ABILITY_UPDATE_INTERVAL: float = 0.1  # Update abilities 10 times per second

func _ready():
	instance = self
	
	# Wait for other systems to initialize
	call_deferred("_connect_to_systems")
	
	print("🌉 EnemyBridge initialized")

func _connect_to_systems():
	enemy_manager = EnemyManager.instance
	config_manager = EnemyConfigManager.instance
	ability_executor = AbilityExecutor.instance
	
	# Find other systems
	lighting_manager = get_node("../LightingManager") if get_node_or_null("../LightingManager") else null
	
	if enemy_manager:
		print("✅ EnemyBridge connected to EnemyManager")
	else:
		print("❌ EnemyBridge: EnemyManager not found!")
	
	if config_manager:
		print("✅ EnemyBridge connected to EnemyConfigManager")
	else:
		print("❌ EnemyBridge: EnemyConfigManager not found!")
	
	if ability_executor:
		print("✅ EnemyBridge connected to AbilityExecutor")
	else:
		print("⚠️ EnemyBridge: AbilityExecutor not found (using legacy system)")

func _process(delta: float):
	if not enemy_manager or not config_manager:
		return
	
	last_ability_update += delta
	if last_ability_update >= ABILITY_UPDATE_INTERVAL:
		_update_enemy_abilities(delta)
		_update_active_effects(delta)
		last_ability_update = 0.0

# Called when a new enemy is spawned via EnemyManager
func on_enemy_spawned(enemy_id: int, enemy_type_str: String, resource: EnemyResource = null):
	# If we have a resource with abilities, register them with AbilityExecutor
	if resource and resource.abilities.size() > 0 and ability_executor:
		print("🎯 Registering %d abilities for %s (id:%d)" % [resource.abilities.size(), enemy_type_str, enemy_id])
		ability_executor.register_entity_abilities(enemy_id, resource.abilities)
	else:
		# Fall back to legacy system
		print("⚠️ Using legacy abilities for %s (id:%d)" % [enemy_type_str, enemy_id])
		_setup_enemy_abilities(enemy_id, enemy_type_str)
	
	_setup_enemy_effects(enemy_id, enemy_type_str)
	_setup_enemy_lighting(enemy_id, enemy_type_str)

func evolve_enemy(enemy_id: int, enemy_type_str: String):
	# Rebuild abilities/effects/lighting for the new type
	_setup_enemy_abilities(enemy_id, enemy_type_str)
	_setup_enemy_effects(enemy_id, enemy_type_str)
	_setup_enemy_lighting(enemy_id, enemy_type_str)

# Called when an enemy dies or is despawned
func on_enemy_despawned(enemy_id: int):
	# Clean up from AbilityExecutor if it exists
	if ability_executor:
		ability_executor.cleanup_entity(enemy_id)
	
	_cleanup_enemy_data(enemy_id)

func _setup_enemy_abilities(enemy_id: int, enemy_type_str: String):
	if not config_manager:
		return
	
	var config = config_manager.get_enemy_config(enemy_type_str)
	if config.is_empty():
		return
	
	var abilities = config.get("abilities", [])
	if abilities.is_empty():
		return
	
	enemy_abilities[enemy_id] = []
	ability_cooldowns[enemy_id] = {}
	
	for ability_data in abilities:
		var ability_id = ability_data.get("id", "")
		if ability_id.is_empty():
			continue
		
		var ability_config = config_manager.get_ability_config(ability_id)
		if ability_config.is_empty():
			continue
		
		# Create active ability instance
		var active_ability = {
			"id": ability_id,
			"config": ability_config,
			"cooldown": ability_data.get("cooldown", 1.0),
			"last_used": 0.0
		}
		
		enemy_abilities[enemy_id].append(active_ability)
		ability_cooldowns[enemy_id][ability_id] = 0.0

func _setup_enemy_effects(enemy_id: int, enemy_type_str: String):
	active_effects[enemy_id] = []
	
	# Add type-specific effects
	match enemy_type_str:
		"twitch_rat":
			# Rats can have boost effects
			pass
		"succubus":
			# Succubus flying effect
			_add_effect(enemy_id, "flying", -1.0)  # Permanent effect
		"ugandan_warrior":
			# Auto-yell on spawn
			_trigger_yell_effect(enemy_id)

func _setup_enemy_lighting(enemy_id: int, enemy_type_str: String):
	if not lighting_manager or not enemy_manager:
		return
	
	var config = config_manager.get_enemy_config(enemy_type_str)
	if config.is_empty():
		return
	
	var visuals = config.get("visuals", {})
	if visuals.get("light_enabled", false):
		var enemy_pos = enemy_manager.positions[enemy_id]
		_create_enemy_light(enemy_id, enemy_pos, enemy_type_str)

func _update_enemy_abilities(_delta: float):
	var current_time = Time.get_ticks_msec() / 1000.0
	
	for enemy_id in enemy_abilities.keys():
		# Skip if enemy is dead
		if enemy_id >= enemy_manager.alive_flags.size() or enemy_manager.alive_flags[enemy_id] == 0:
			continue
		
		# Skip if enemy is currently casting
		if enemy_id < enemy_manager.ability_casting_flags.size() and enemy_manager.ability_casting_flags[enemy_id] > 0:
			continue
		
		# All enemies use the same cooldown system now
		var abilities = enemy_abilities[enemy_id]
		for ability in abilities:
			# Check if ability is off cooldown
			if current_time - ability.last_used >= ability.cooldown:
				# Check if conditions are met to use ability
				if _should_use_ability(enemy_id, ability):
					_execute_ability(enemy_id, ability)
					ability.last_used = current_time

func _update_active_effects(delta: float):
	# Boost timers are now handled in enemy_manager's _physics_process
	
	# Update other timed effects
	for enemy_id in active_effects.keys():
		var effects = active_effects[enemy_id]
		for i in range(effects.size() - 1, -1, -1):
			var effect = effects[i]
			if effect.has("duration") and effect.duration > 0:
				effect.duration -= delta
				if effect.duration <= 0:
					_end_effect(enemy_id, effect)
					effects.remove_at(i)

func _should_use_ability(enemy_id: int, ability: Dictionary) -> bool:
	if not enemy_manager or not GameController.instance or not GameController.instance.player:
		return false
	
	var enemy_pos = enemy_manager.positions[enemy_id]
	var player_pos = GameController.instance.player.global_position
	var distance = enemy_pos.distance_to(player_pos)
	
	match ability.id:
		"boost":
			# Boosts should only happen via !boost command, not automatically
			return false
		"suicide_bomb":
			# Proximity trigger for ugandan warriors
			return distance < 120.0 and randf() < 0.15
	
	return false

func _execute_ability(enemy_id: int, ability: Dictionary):
	if not enemy_manager:
		return
	
	var enemy_pos = enemy_manager.positions[enemy_id]
	var _enemy_type_id = enemy_manager.entity_types[enemy_id]
	
	match ability.id:
		"boost":
			# Boost is now handled via execute_command_for_enemy
			execute_command_for_enemy(enemy_id, "boost")
		"heart_projectile":
			# Now handled by AbilityExecutor - should not reach here
			print("⚠️ Old heart projectile code reached - this shouldn't happen!")
			pass
		"suction":
			# Now handled by AbilityExecutor - should not reach here
			print("⚠️ Old suction code reached - this shouldn't happen!")
			pass



# Boost is now handled directly in execute_command_for_enemy with flat speed bonus
# Old multiplier-based boost functions removed










func _cleanup_node(node: Node):
	if is_instance_valid(node):
		node.queue_free()

func _create_enemy_light(enemy_id: int, pos: Vector2, enemy_type_str: String):
	# Create light for bosses and special enemies
	if enemy_type_str.contains("boss") or enemy_type_str == "woodland_joe":
		var light = PointLight2D.new()
		light.position = pos
		light.energy = 1.5
		light.texture_scale = 2.0
		light.color = _get_enemy_light_color(enemy_type_str)
		GameController.instance.add_child(light)
		
		# Store reference for cleanup
		if not has_meta("enemy_lights"):
			set_meta("enemy_lights", {})
		get_meta("enemy_lights")[enemy_id] = light

func _get_enemy_light_color(enemy_type_str: String) -> Color:
	match enemy_type_str:
		"zzran_boss":
			return Color.MAGENTA
		"thor_enemy":
			return Color.CYAN
		"mika_boss":
			return Color.ORANGE
		"forsen_boss":
			return Color.PURPLE
		"woodland_joe":
			return Color.GREEN
		_:
			return Color.WHITE

func _trigger_yell_effect(enemy_id: int):
	if not enemy_manager:
		return
	
	var username = enemy_manager.chatter_usernames[enemy_id]
	var feed = GameController.instance.get_action_feed()
	if feed:
		feed.add_message("%s: GWA GWA GWA GWA!" % username, Color.YELLOW)

func _add_effect(enemy_id: int, effect_id: String, duration: float):
	if not active_effects.has(enemy_id):
		active_effects[enemy_id] = []
	
	var effect = {
		"id": effect_id,
		"duration": duration
	}
	active_effects[enemy_id].append(effect)


func _end_effect(_enemy_id: int, effect: Dictionary):
	# Effect cleanup logic can be added here if needed
	pass

func _cleanup_enemy_data(enemy_id: int):
	enemy_abilities.erase(enemy_id)
	ability_cooldowns.erase(enemy_id)
	active_effects.erase(enemy_id)
	
	# Clean up lights
	if has_meta("enemy_lights"):
		var lights = get_meta("enemy_lights")
		if lights.has(enemy_id):
			var light = lights[enemy_id]
			if is_instance_valid(light):
				light.queue_free()
			lights.erase(enemy_id)

func _get_type_string(type_id: int) -> String:
	match type_id:
		0: return "twitch_rat"
		1: return "succubus"
		2: return "woodland_joe"
		3: return "ugandan_warrior"
		4: return "horse_enemy"
		5: return "thor_enemy"
		6: return "mika_boss"
		7: return "zzran_boss"
		8: return "forsen_boss"
		_: return "unknown"


# Public API for V2 enemy commands
func execute_command_for_enemy(enemy_id: int, command: String):
	if not enemy_manager or enemy_id >= enemy_manager.alive_flags.size() or enemy_manager.alive_flags[enemy_id] == 0:
		return
	
	if not ability_executor:
		print("⚠️ AbilityExecutor not available for command: %s" % command)
		return
	
	# Use AbilityExecutor with existing .tres resources for all commands
	match command:
		"explode":
			var explosion_resource = load("res://resources/abilities/explosion.tres")
			if explosion_resource:
				ability_executor.execute_ability(enemy_id, explosion_resource)
			else:
				print("❌ Could not load explosion.tres resource")
		
		"fart":
			var fart_resource = load("res://resources/abilities/fart.tres")  
			if fart_resource:
				ability_executor.execute_ability(enemy_id, fart_resource)
			else:
				print("❌ Could not load fart.tres resource")
		
		"boost":
			var boost_resource = load("res://resources/abilities/boost.tres")
			if boost_resource:
				ability_executor.execute_ability(enemy_id, boost_resource)
			else:
				print("❌ Could not load boost.tres resource")
		
		"grow":
			# Simple visual/stat modification (not an ability effect)
			enemy_manager.scales[enemy_id] *= 1.25
			enemy_manager.max_healths[enemy_id] *= 1.1
			enemy_manager.healths[enemy_id] = min(enemy_manager.healths[enemy_id], enemy_manager.max_healths[enemy_id])
			print("📈 Enemy %d grew larger!" % enemy_id)
		
		_:
			print("⚠️ Unknown command: %s" % command)
