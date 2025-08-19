extends Node
class_name EvolutionSystem

## Manages entity evolutions for Twitch chatters
## Handles evolution requests, validations, and transformations

static var instance: EvolutionSystem

# Evolution definitions - easily extendable
var evolution_registry: Dictionary = {}

signal evolution_requested(username: String, evolution_name: String)
signal evolution_completed(username: String, old_entity: Node, new_entity: Node)
signal evolution_failed(username: String, reason: String)

func _ready():
	instance = self
	_register_evolutions()
	print("🧬 Evolution System initialized!")

func _register_evolutions():
	# Register all available evolutions
	register_evolution("woodlandjoe", EvolutionConfig.new().setup(
		"WoodlandJoe",
		"res://entities/enemies/woodland_joe.tscn",
		5,  # MXP cost
		"A slow but unstoppable juggernaut",
		["Boss", "Melee", "WoodlandJoe"]
	))
	
	register_evolution("succubus", EvolutionConfig.new().setup(
		"Succubus",
		"res://entities/enemies/succubus.tscn",
		10,  # MXP cost as specified
		"A flying seductress that shoots hearts and drains life force",
		["Flying", "Evolved", "Succubus"]
	))

func register_evolution(evolution_name: String, config: EvolutionConfig):
	evolution_registry[evolution_name.to_lower()] = config
	print("📝 Registered evolution: %s (Cost: %d MXP)" % [config.display_name, config.mxp_cost])

func request_evolution(username: String, evolution_name: String) -> bool:
	var normalized_name = evolution_name.to_lower()
	print("🧬 Evolution request for ", username, " to evolve to: ", normalized_name)
	print("🧬 Available evolutions: ", evolution_registry.keys())
	
	# Check if evolution exists
	if not evolution_registry.has(normalized_name):
		evolution_failed.emit(username, "Unknown evolution: " + evolution_name)
		print("❌ Evolution not found: ", normalized_name)
		if GameController.instance and GameController.instance.has_method("get_action_feed"):
			var feed = GameController.instance.get_action_feed()
			if feed:
				feed.add_message("❌ Unknown evolution: " + evolution_name, Color(1, 0.5, 0.5))
		return false
	
	var config = evolution_registry[normalized_name]
	
	# Check MXP cost
	var current_mxp = MXPManager.instance.get_available_mxp(username)
	print("🧬 User ", username, " has ", current_mxp, " MXP, needs ", config.mxp_cost)
	if current_mxp < config.mxp_cost:
		evolution_failed.emit(username, "Not enough MXP! Need %d, have %d" % [config.mxp_cost, current_mxp])
		if GameController.instance and GameController.instance.has_method("get_action_feed"):
			var feed = GameController.instance.get_action_feed()
			if feed:
				feed.add_message("❌ %s needs %d MXP (has %d)" % [username, config.mxp_cost, current_mxp], Color(1, 0.5, 0.5))
		return false
	
	# Try V2 path first: evolve the user's live V2 enemies
	if TicketSpawnManager.instance and EnemyManager.instance:
		var ids: Array[int] = TicketSpawnManager.instance.get_alive_entities_for_chatter(username)
		if not ids.is_empty():
			var new_type_id = EnemyManager.instance.get_enemy_type_from_string(normalized_name)
			for enemy_id in ids:
				EnemyManager.instance.evolve_enemy(enemy_id, new_type_id)
			# Deduct MXP and announce
			MXPManager.instance.spend_mxp(username, config.mxp_cost, "evolution_" + normalized_name)
			if GameController.instance and GameController.instance.has_method("get_action_feed"):
				var feed = GameController.instance.get_action_feed()
				if feed:
					feed.add_message("🧬 %s evolved into %s!" % [username, config.display_name], Color(0.8, 0, 0.8))
			return true

	# Fallback to legacy node-based path
	var current_entity = _find_user_entity(username)
	if not current_entity:
		evolution_failed.emit(username, "No active entity to evolve!")
		print("❌ No entity found for user: ", username)
		if GameController.instance and GameController.instance.has_method("get_action_feed"):
			var feed = GameController.instance.get_action_feed()
			if feed:
				feed.add_message("❌ %s has no active entity to evolve!" % username, Color(1, 0.5, 0.5))
		return false
	
	# Deduct MXP
	MXPManager.instance.spend_mxp(username, config.mxp_cost, "evolution_" + normalized_name)
	# Perform legacy evolution
	_perform_evolution(username, current_entity, config)
	return true

func _find_user_entity(username: String) -> Node:
	# Search through all entities for this user
	var entities = get_tree().get_nodes_in_group("enemies")
	print("🧬 Searching for entity belonging to: ", username)
	print("🧬 Found ", entities.size(), " enemies to check")
	
	for entity in entities:
		# Try different methods to get username
		var entity_username = ""
		if entity.has_method("get_twitch_username"):
			entity_username = entity.get_twitch_username()
		elif entity.has_method("get_chatter_username"):
			entity_username = entity.get_chatter_username()
		elif "chatter_username" in entity:
			entity_username = entity.chatter_username
		
		print("🧬 Checking entity: ", entity.name, " with username: ", entity_username)
		
		if entity_username == username:
			print("🧬 Found entity for ", username, "!")
			return entity
	
	print("🧬 No entity found for ", username)
	return null

func _perform_evolution(username: String, old_entity: Node, config: EvolutionConfig):
	evolution_requested.emit(username, config.display_name)
	
	# Store important data from old entity
	var old_position = old_entity.global_position
	var old_health_percentage = float(old_entity.current_health) / float(old_entity.max_health)
	
	# Get chatter color from old entity
	var chatter_color = Color.WHITE
	if "chatter_color" in old_entity:
		chatter_color = old_entity.chatter_color
	else:
		# Generate from hash as fallback
		var hash_value = username.hash()
		chatter_color = Color(
			float(hash_value % 256) / 255.0,
			float((hash_value / 256.0) % 256) / 255.0,
			float((hash_value / 65536.0) % 256) / 255.0
		)
	
	# Get the game controller to spawn new entity
	var game_controller = GameController.instance
	if not game_controller:
		evolution_failed.emit(username, "Game controller not found!")
		return
	
	# Create evolution effect
	_create_evolution_effect(old_position)
	
	# Remove old entity
	old_entity.queue_free()
	
	# Spawn new evolved entity
	call_deferred("_spawn_evolved_entity", username, config, old_position, old_health_percentage, chatter_color)

func _spawn_evolved_entity(username: String, config: EvolutionConfig, position: Vector2, health_percentage: float, color: Color):
	# Ensure color is bright enough
	if color.v < 0.5:
		color.v = 0.5 + randf() * 0.5
	
	# Create evolved entity using factory method
	var new_entity = BaseCreature.create_chatter_entity(config.scene_path, username, color)
	if not new_entity:
		evolution_failed.emit(username, "Failed to create evolution!")
		return
	
	new_entity.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Apply special tags
	if new_entity.has_method("add_tag"):
		for tag in config.special_tags:
			new_entity.add_tag(tag)
	
	# Add to scene
	GameController.instance.add_child(new_entity)
	new_entity.global_position = position
	
	# Note: The new TicketSpawnManager will handle tracking
	# No need to update old active_twitch_rats dictionary
	
	# Restore health percentage
	if "current_health" in new_entity and "max_health" in new_entity:
		new_entity.current_health = int(new_entity.max_health * health_percentage)
	
	# IMPORTANT: Clear any cached base stats from previous entity
	# This ensures the new entity's base stats are properly cached
	if new_entity.has_meta("base_max_health"):
		new_entity.remove_meta("base_max_health")
	if new_entity.has_meta("base_damage"):
		new_entity.remove_meta("base_damage")
	if new_entity.has_meta("base_move_speed"):
		new_entity.remove_meta("base_move_speed")
	
	# Apply any upgrades the user had
	ChatterEntityManager.instance.apply_upgrades_to_entity(new_entity, username)
	
	# Notify completion
	evolution_completed.emit(username, null, new_entity)
	
	# Announce in action feed
	if GameController.instance.has_method("get_action_feed"):
		var feed = GameController.instance.get_action_feed()
		if feed:
			feed.add_message("🧬 %s evolved into %s!" % [username, config.display_name], Color(0.8, 0, 0.8))

func _create_evolution_effect(position: Vector2):
	# Create a visual effect for evolution
	var effect = preload("res://entities/effects/evolution_effect.gd").new()
	effect.position = position
	GameController.instance.add_child(effect)

func get_evolution_list() -> Array:
	var list = []
	for key in evolution_registry:
		var config = evolution_registry[key]
		list.append({
			"command": key,
			"name": config.display_name,
			"cost": config.mxp_cost,
			"description": config.description
		})
	return list

func get_evolution_info(evolution_name: String) -> Dictionary:
	var normalized = evolution_name.to_lower()
	if evolution_registry.has(normalized):
		var config = evolution_registry[normalized]
		return {
			"name": config.display_name,
			"cost": config.mxp_cost,
			"description": config.description,
			"tags": config.special_tags
		}
	return {}
