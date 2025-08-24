extends Node
class_name EnemyBridge

## ENEMY V2 INTEGRATION BRIDGE
## Connects the data-oriented EnemyManager with existing gameplay systems
## Handles abilities, effects, AI behaviors, and visual systems for V2 enemies

static var instance: EnemyBridge

# Preload classes for complex ability execution
const V2AbilityProxyClass = preload("res://systems/core/v2_ability_proxy.gd")
const SuctionAbilityClass = preload("res://systems/ability_system/abilities/suction_ability_v2.gd")

# System references
var enemy_manager: EnemyManager
var config_manager: EnemyConfigManager
var ability_manager: AbilityManager
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
	ability_manager = get_node("../AbilityManager") if get_node_or_null("../AbilityManager") else null
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
		ability_executor.register_entity_abilities(enemy_id, resource.abilities)
	else:
		# Fall back to legacy system
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
		
		# Special handling for succubus (entity_type 1) - use enemy_manager cooldown
		if enemy_id < enemy_manager.entity_types.size() and enemy_manager.entity_types[enemy_id] == 1:
			# Check shared cooldown in enemy_manager
			if enemy_manager.ability_cooldowns[enemy_id] > 0:
				continue  # Still on cooldown
			
			# Try abilities in priority order
			var abilities = enemy_abilities[enemy_id]
			for ability in abilities:
				if _should_use_ability(enemy_id, ability):
					_execute_ability(enemy_id, ability)
					break  # Only execute one ability
		else:
			# Regular enemies use the old system
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
		"explosion":
			# Explosions should only happen via !explode command, not automatically
			return false
		"fart":
			# Farts should only happen via !fart command, not automatically
			return false
		"boost":
			# Boosts should only happen via !boost command, not automatically
			return false
		"heart_projectile":
			# Use projectile when in range (must match ability's base_range of 400)
			return distance < 400.0 and distance > 50.0
		"suction":
			# Only attempt suction when actually in range
			var in_range = distance <= 200.0
			return in_range
		"suicide_bomb":
			# Proximity trigger for ugandan warriors
			return distance < 120.0 and randf() < 0.15
		"telegraph_charge":
			# Charge when in range
			return distance < 1000.0
	
	return false

func _execute_ability(enemy_id: int, ability: Dictionary):
	if not enemy_manager:
		return
	
	var enemy_pos = enemy_manager.positions[enemy_id]
	var _enemy_type_id = enemy_manager.entity_types[enemy_id]
	
	match ability.id:
		"explosion":
			_trigger_explosion(enemy_id, enemy_pos, ability.config)
		"fart":
			_trigger_fart_cloud(enemy_id, enemy_pos, ability.config)
		"boost":
			# Boost is now handled via execute_command_for_enemy
			execute_command_for_enemy(enemy_id, "boost")
		"heart_projectile":
			_fire_heart_projectile(enemy_id, enemy_pos, ability.config)
		"suction":
			_start_suction_ability(enemy_id, enemy_pos, ability.config)
		"suicide_bomb":
			_trigger_suicide_bomb(enemy_id, enemy_pos, ability.config)
		"telegraph_charge":
			_trigger_telegraph_charge(enemy_id, enemy_pos, ability.config)

func _trigger_explosion(enemy_id: int, pos: Vector2, config: Dictionary):
	# Get base values
	var _damage = config.get("damage", 20.0)
	var _radius = config.get("radius", 80.0)
	var aoe_scale = 1.0
	var username = ""
	
	# Apply chatter's AOE bonus if available
	if enemy_manager and enemy_id >= 0 and enemy_id < enemy_manager.chatter_usernames.size():
		username = enemy_manager.chatter_usernames[enemy_id]
		if username != "" and ChatterEntityManager.instance:
			var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
			if chatter_data and chatter_data.upgrades.has("bonus_aoe"):
				var bonus_aoe = chatter_data.upgrades.bonus_aoe
				var rarity_mult = chatter_data.upgrades.get("rarity_multiplier", 1.0)
				aoe_scale = (1.0 + bonus_aoe) * rarity_mult
	
	# Create explosion effect
	var explosion_scene_path = config.get("visuals", {}).get("effect_scene", "res://entities/effects/explosion_effect.tscn")
	if ResourceLoader.exists(explosion_scene_path):
		var explosion = load(explosion_scene_path).instantiate()
		explosion.global_position = pos
		explosion.applied_aoe_scale = aoe_scale
		
		# Set source name for proper death attribution
		if username != "":
			explosion.source_name = username
			explosion.set_meta("source_name", username)
		
		GameController.instance.add_child(explosion)
	
	print("💥 Enemy %d exploded at %s" % [enemy_id, pos])

func _trigger_fart_cloud(enemy_id: int, pos: Vector2, config: Dictionary):
	var username = ""
	var aoe_scale = 1.0
	
	# Get username and AOE scale
	if enemy_manager and enemy_id >= 0 and enemy_id < enemy_manager.chatter_usernames.size():
		username = enemy_manager.chatter_usernames[enemy_id]
		if username != "" and ChatterEntityManager.instance:
			var chatter_data = ChatterEntityManager.instance.get_chatter_data(username)
			if chatter_data and chatter_data.upgrades.has("bonus_aoe"):
				var bonus_aoe = chatter_data.upgrades.bonus_aoe
				var rarity_mult = chatter_data.upgrades.get("rarity_multiplier", 1.0)
				aoe_scale = (1.0 + bonus_aoe) * rarity_mult
	
	# Create poison cloud effect
	var cloud_scene_path = config.get("visuals", {}).get("effect_scene", "res://entities/effects/poison_cloud.tscn")
	if ResourceLoader.exists(cloud_scene_path):
		var cloud = load(cloud_scene_path).instantiate()
		cloud.global_position = pos
		cloud.applied_aoe_scale = aoe_scale
		
		# Set source name for proper death attribution
		if username != "":
			cloud.source_name = username
			cloud.set_meta("source_name", username)
		
		GameController.instance.add_child(cloud)
	
	print("💨 Enemy %d created fart cloud at %s" % [enemy_id, pos])

# Boost is now handled directly in execute_command_for_enemy with flat speed bonus
# Old multiplier-based boost functions removed

func _fire_heart_projectile(enemy_id: int, pos: Vector2, _config: Dictionary):
	if not GameController.instance or not GameController.instance.player:
		return
	
	# Check if enemy is already casting (should already be checked but safety)
	if enemy_manager.ability_casting_flags[enemy_id] > 0:
		return  # Already casting something
	
	# DOUBLE CHECK RANGE before creating proxy
	var player_pos = GameController.instance.player.global_position
	var distance = pos.distance_to(player_pos)
	if distance > 400.0:
		# Not in range for heart projectile
		return
	
	# Use V2AbilityProxy for proper ability handling with windup
	var proxy = V2AbilityProxy.new()
	var username = ""
	if enemy_id < enemy_manager.chatter_usernames.size():
		username = enemy_manager.chatter_usernames[enemy_id]
	proxy.setup(enemy_id, enemy_manager, username)
	get_tree().current_scene.add_child(proxy)
	proxy.global_position = pos
	
	# Create target data for ability
	var target_data = {
		"target_enemy": GameController.instance.player,
		"target_position": GameController.instance.player.global_position
	}
	
	# Mark enemy as casting
	enemy_manager.ability_casting_flags[enemy_id] = 1
	
	# Attach heart projectile ability - this will handle windup, animation, etc
	if proxy.attach_ability(HeartProjectileAbility, target_data):
		print("💖 Enemy %d starting heart projectile cast" % enemy_id)
		# Set cooldown for succubus (entity_type 1)
		if enemy_manager.entity_types[enemy_id] == 1:
			enemy_manager.ability_cooldowns[enemy_id] = 2.0  # 2 second cooldown after heart projectile
	else:
		# Failed to attach ability, clear casting flag
		enemy_manager.ability_casting_flags[enemy_id] = 0
		proxy.queue_free()

func _start_suction_ability(enemy_id: int, pos: Vector2, _config: Dictionary):
	if not GameController.instance or not GameController.instance.player:
		return
	
	# Check if already casting (should already be checked but safety)
	if enemy_manager.ability_casting_flags[enemy_id] > 0:
		return
	
	# DOUBLE CHECK RANGE before creating proxy
	var player_pos = GameController.instance.player.global_position
	var distance = pos.distance_to(player_pos)
	if distance > 200.0:
		# Not in range, don't create proxy
		return
	
	# Mark as casting
	enemy_manager.ability_casting_flags[enemy_id] = 1
	
	# Get username for attribution
	var username = ""
	if enemy_manager and enemy_id >= 0 and enemy_id < enemy_manager.chatter_usernames.size():
		username = enemy_manager.chatter_usernames[enemy_id]
	
	# Use the reusable proxy system
	var proxy = V2AbilityProxyClass.new()
	proxy.name = "SuccubusProxy_%d" % enemy_id
	
	# Setup proxy BEFORE adding to tree (timer will autostart when added)
	proxy.setup(enemy_id, enemy_manager, username)
	
	# Now add to tree and set position
	GameController.instance.add_child(proxy)
	proxy.global_position = pos
	
	# Create target data
	var target_data = {
		"target_enemy": GameController.instance.player,
		"target_position": GameController.instance.player.global_position
	}
	
	# Attach and execute ability
	if proxy.attach_ability(SuctionAbilityClass, target_data):
		print("💜 Suction ability started for enemy %d at distance %.1f" % [enemy_id, pos.distance_to(GameController.instance.player.global_position)])
		
		# Set cooldown for succubus (entity_type 1) 
		if enemy_manager.entity_types[enemy_id] == 1:
			enemy_manager.ability_cooldowns[enemy_id] = 30.0  # 30 second cooldown for suction
		
		# Clean up when ability ends
		if proxy.tracked_ability and proxy.tracked_ability.has_signal("channel_ended"):
			proxy.tracked_ability.channel_ended.connect(func():
				# Clear casting flag when suction ends
				if enemy_id < enemy_manager.ability_casting_flags.size():
					enemy_manager.ability_casting_flags[enemy_id] = 0
				proxy.queue_free()
			)
	else:
		print("❌ Failed to start suction ability")
		# Clear casting flag if ability failed to start
		if enemy_id < enemy_manager.ability_casting_flags.size():
			enemy_manager.ability_casting_flags[enemy_id] = 0
		proxy.queue_free()

func _trigger_suicide_bomb(enemy_id: int, pos: Vector2, config: Dictionary):
	var telegraph_time = config.get("telegraph_time", 0.4)
	var damage = config.get("damage", 100.0)
	var radius = config.get("radius", 120.0)
	
	# Telegraph effect
	_create_bomb_telegraph(pos, telegraph_time)
	
	# Delay the actual explosion - use bind to avoid lambda capture
	var timer = get_tree().create_timer(telegraph_time)
	timer.timeout.connect(_delayed_explosion.bind(enemy_id, pos, damage, radius))
	
	print("💣 Enemy %d priming suicide bomb" % enemy_id)

func _delayed_explosion(enemy_id: int, pos: Vector2, damage: float, radius: float):
	# Check if enemy is still alive
	if enemy_id < enemy_manager.alive_flags.size() and enemy_manager.alive_flags[enemy_id] == 1:
		_trigger_explosion(enemy_id, pos, {"damage": damage, "radius": radius})
		# Kill the enemy
		enemy_manager.despawn_enemy(enemy_id)

func _trigger_telegraph_charge(enemy_id: int, pos: Vector2, config: Dictionary):
	if not GameController.instance or not GameController.instance.player:
		return
	
	var telegraph_time = config.get("telegraph_time", 1.0)
	var charge_speed = config.get("charge_speed", 400.0)
	var player_pos = GameController.instance.player.global_position
	
	# Show telegraph line
	_create_charge_telegraph(pos, player_pos, telegraph_time)
	
	# After telegraph, execute charge - use bind to avoid lambda capture
	var timer = get_tree().create_timer(telegraph_time)
	timer.timeout.connect(_execute_charge.bind(enemy_id, pos, player_pos, charge_speed))
	
	print("🐎 Enemy %d charging!" % enemy_id)

func _execute_charge(enemy_id: int, pos: Vector2, player_pos: Vector2, charge_speed: float):
	if enemy_id < enemy_manager.alive_flags.size() and enemy_manager.alive_flags[enemy_id] == 1:
		# Set velocity toward target
		var direction = (player_pos - pos).normalized()
		enemy_manager.velocities[enemy_id] = direction * charge_speed
		enemy_manager.move_speeds[enemy_id] = charge_speed
		
		# Charge for a short duration then despawn
		var timer = get_tree().create_timer(2.0)
		timer.timeout.connect(_despawn_enemy.bind(enemy_id))

func _despawn_enemy(enemy_id: int):
	if enemy_id < enemy_manager.alive_flags.size():
		enemy_manager.despawn_enemy(enemy_id)

func _create_bomb_telegraph(pos: Vector2, duration: float):
	# Create a warning visual at the bomb position
	var warning = ColorRect.new()
	warning.color = Color(1, 0, 0, 0.5)
	warning.size = Vector2(40, 40)
	warning.position = pos - Vector2(20, 20)
	GameController.instance.add_child(warning)
	
	# Pulsing animation
	var tween = warning.create_tween()
	tween.set_loops(-1)
	tween.tween_property(warning, "modulate:a", 0.2, 0.2)
	tween.tween_property(warning, "modulate:a", 0.8, 0.2)
	
	# Remove after duration - use bind to avoid lambda capture
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(_cleanup_node.bind(warning))

func _create_charge_telegraph(start_pos: Vector2, end_pos: Vector2, duration: float):
	# Create a line showing the charge path
	var line = Line2D.new()
	line.add_point(start_pos)
	line.add_point(end_pos)
	line.width = 5.0
	line.default_color = Color(1, 1, 0, 0.7)
	GameController.instance.add_child(line)
	
	# Remove after duration - use bind to avoid lambda capture
	var timer = get_tree().create_timer(duration)
	timer.timeout.connect(_cleanup_node.bind(line))

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

func _add_boost_visual_effect(enemy_id: int):
	if not enemy_manager or enemy_id >= enemy_manager.alive_flags.size():
		return
	
	# Store original color to restore later (not currently used but kept for future enhancements)
	var _original_color = enemy_manager.chatter_colors[enemy_id]
	
	# Create yellow boost effect - modulate the enemy's color
	# We'll use the flash timer system that already exists
	enemy_manager.flash_timers[enemy_id] = enemy_manager.BOOST_DURATION
	
	# Add the effect tracking
	_add_effect(enemy_id, "boost_visual", enemy_manager.BOOST_DURATION)

func _end_effect(_enemy_id: int, effect: Dictionary):
	match effect.id:
		"boost_visual":
			# Remove visual boost effect
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

# Helper function to create temporary ability resources for commands
func _create_command_ability_resource(command: String) -> AbilityResource:
	var ability = AbilityResource.new()
	
	match command:
		"explode":
			ability.ability_id = "command_explode"
			ability.display_name = "Explode"
			ability.trigger_type = "instant"
			ability.damage = 20.0
			ability.range = 80.0
			ability.cooldown = 0.0
			ability.effect_scene = load("res://entities/effects/explosion_effect.tscn")
			
		"fart":
			ability.ability_id = "command_fart"
			ability.display_name = "Fart"
			ability.trigger_type = "area"
			ability.damage = 5.0
			ability.range = 100.0
			ability.duration = 3.0
			ability.cooldown = 0.0
			ability.effect_scene = load("res://entities/effects/poison_cloud.tscn")
			
		_:
			return null
	
	return ability

# Public API for V2 enemy commands
func execute_command_for_enemy(enemy_id: int, command: String):
	if not enemy_manager or enemy_id >= enemy_manager.alive_flags.size() or enemy_manager.alive_flags[enemy_id] == 0:
		return
	
	# Try to use AbilityExecutor if available for resource-based abilities
	if ability_executor and command in ["explode", "fart"]:
		# Create temporary ability resource for the command
		var temp_ability = _create_command_ability_resource(command)
		if temp_ability:
			ability_executor.execute_ability(enemy_id, temp_ability)
			return
	
	# Fall back to legacy execution
	match command:
		"explode":
			var config = {"damage": 20.0, "radius": 80.0, "visuals": {"effect_scene": "res://entities/effects/explosion_effect.tscn"}}
			_trigger_explosion(enemy_id, enemy_manager.positions[enemy_id], config)
		"fart":
			var config = {"visuals": {"effect_scene": "res://entities/effects/poison_cloud.tscn"}}
			_trigger_fart_cloud(enemy_id, enemy_manager.positions[enemy_id], config)
		"boost":
			# Check cooldown
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - enemy_manager.last_boost_times[enemy_id] < enemy_manager.BOOST_COOLDOWN:
				return  # Still on cooldown
			
			# Apply flat boost
			enemy_manager.temporary_speed_boosts[enemy_id] = enemy_manager.BOOST_FLAT_BONUS
			enemy_manager.boost_end_times[enemy_id] = current_time + enemy_manager.BOOST_DURATION
			enemy_manager.last_boost_times[enemy_id] = current_time
			
			# Visual effect - make enemy flash yellow
			_add_boost_visual_effect(enemy_id)
			
			# Activity feed message
			if GameController.instance:
				var feed = GameController.instance.get_action_feed()
				if feed:
					var username = enemy_manager.chatter_usernames[enemy_id]
					if username != "":
						feed.add_message("⚡ %s used BOOST! (+500 speed)" % username, Color(1.0, 1.0, 0.3))
			
			print("⚡ Enemy %d boosted (+%.0f speed for %.1fs)" % [enemy_id, enemy_manager.BOOST_FLAT_BONUS, enemy_manager.BOOST_DURATION])
		"grow":
			# Increase visual scale and collision weight slightly
			enemy_manager.scales[enemy_id] = enemy_manager.scales[enemy_id] * 1.25
			# Optional: buff health a bit when growing
			enemy_manager.max_healths[enemy_id] *= 1.1
			enemy_manager.healths[enemy_id] = min(enemy_manager.healths[enemy_id], enemy_manager.max_healths[enemy_id])
		"bomb":
			# Arm a suicide bomb similar to ugandan warrior
			var config = {"telegraph_time": 0.4, "damage": 100.0, "radius": 120.0}
			_trigger_suicide_bomb(enemy_id, enemy_manager.positions[enemy_id], config)
