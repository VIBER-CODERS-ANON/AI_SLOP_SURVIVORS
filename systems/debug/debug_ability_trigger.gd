extends Node
class_name DebugAbilityTrigger

## Debug system for manually triggering entity abilities during development
## Modernized to use the new resource-based ability system via AbilityExecutor
## Automatically discovers abilities from AbilityResource files instead of hardcoded lists

signal ability_triggered(entity_data: Dictionary, ability_name: String)
signal ability_trigger_failed(reason: String)

# Trigger an ability for the selected entity
func trigger_ability(entity_data: Dictionary, ability_name: String):
	if entity_data.is_empty():
		emit_signal("ability_trigger_failed", "No entity selected")
		return
	
	if ability_name.is_empty():
		emit_signal("ability_trigger_failed", "No ability specified")
		return
	
	var success = false
	
	match entity_data.type:
		"minion":
			success = _trigger_minion_ability(entity_data.id, ability_name)
		"boss":
			success = _trigger_boss_ability(entity_data.node, ability_name)
		_:
			emit_signal("ability_trigger_failed", "Unknown entity type")
			return
	
	if success:
		emit_signal("ability_triggered", entity_data, ability_name)
		print("[DebugAbilityTrigger] Triggered ability '%s' for entity" % ability_name)
	else:
		emit_signal("ability_trigger_failed", "Failed to trigger ability")

func _trigger_minion_ability(enemy_id: int, ability_name: String) -> bool:
	# Use the new resource-based ability system via AbilityExecutor
	if AbilityExecutor.instance:
		# Try to execute ability by ID
		return AbilityExecutor.instance.execute_ability_by_id(enemy_id, ability_name)
	
	# Legacy fallback: Try through EnemyBridge
	if EnemyBridge.instance and EnemyBridge.instance.has_method("execute_ability"):
		EnemyBridge.instance.execute_ability(enemy_id, ability_name)
		return true
	
	return false

func _trigger_boss_ability(boss_node: Node, ability_name: String) -> bool:
	if not is_instance_valid(boss_node):
		return false
	
	# Try standard force trigger method
	if boss_node.has_method("force_trigger_ability"):
		boss_node.force_trigger_ability(ability_name)
		return true
	
	# Try debug trigger method
	if boss_node.has_method("debug_trigger_ability"):
		boss_node.debug_trigger_ability(ability_name)
		return true
	
	# Try to trigger specific ability methods directly
	var method_name = "_trigger_" + ability_name.to_lower()
	if boss_node.has_method(method_name):
		boss_node.call(method_name)
		return true
	
	# Try to set ability cooldown to 0 and trigger
	if boss_node.has_method("reset_ability_cooldown"):
		boss_node.reset_ability_cooldown(ability_name)
		return true
	
	return false

# Get available abilities for an entity
func get_entity_abilities(entity_data: Dictionary) -> Array:
	var abilities = []
	
	match entity_data.type:
		"minion":
			abilities = _get_minion_abilities(entity_data.id)
		"boss":
			abilities = _get_boss_abilities(entity_data.node)
	
	return abilities

func _get_minion_abilities(enemy_id: int) -> Array:
	var abilities = []
	
	# Get abilities from the new resource system via AbilityExecutor
	if AbilityExecutor.instance and AbilityExecutor.instance.active_abilities.has(enemy_id):
		var ability_resources = AbilityExecutor.instance.active_abilities[enemy_id]
		for ability_res in ability_resources:
			if ability_res is AbilityResource:
				abilities.append(ability_res.ability_id)
	
	# Fallback: Try to get from enemy config via ResourceManager
	if abilities.is_empty() and ResourceManager.instance:
		var enemy_config = ResourceManager.instance.get_enemy_config_by_id(enemy_id)
		if enemy_config and enemy_config.has("abilities"):
			for ability_res in enemy_config.abilities:
				if ability_res is AbilityResource:
					abilities.append(ability_res.ability_id)
	
	return abilities

func _get_boss_abilities(boss_node: Node) -> Array:
	var abilities = []
	
	if not is_instance_valid(boss_node):
		return abilities
	
	# First priority: Get from resource system if boss has an entity_id or similar
	if boss_node.has_method("get_entity_id"):
		var entity_id = boss_node.get_entity_id()
		if AbilityExecutor.instance and AbilityExecutor.instance.active_abilities.has(entity_id):
			var ability_resources = AbilityExecutor.instance.active_abilities[entity_id]
			for ability_res in ability_resources:
				if ability_res is AbilityResource:
					abilities.append(ability_res.ability_id)
			if not abilities.is_empty():
				return abilities
	
	# Second priority: Try to get abilities from boss methods
	if boss_node.has_method("get_abilities"):
		abilities = boss_node.get_abilities()
	elif boss_node.has_method("get_debug_abilities"):
		abilities = boss_node.get_debug_abilities()
	elif "abilities" in boss_node:
		abilities = boss_node.abilities
	
	# Third priority: Try to get from boss resource file
	if abilities.is_empty():
		var boss_name = boss_node.name.to_lower()
		abilities = _get_abilities_from_boss_resource(boss_name)
	
	return abilities

func _get_abilities_from_enemy_resource(enemy_type: String) -> Array:
	# Get abilities from enemy resource files
	var abilities = []
	
	if ResourceManager.instance:
		# Try to find enemy resource by type/ID
		var enemy_resource = ResourceManager.instance.get_enemy_resource(enemy_type)
		if enemy_resource and enemy_resource.has("abilities"):
			for ability_res in enemy_resource.abilities:
				if ability_res is AbilityResource:
					abilities.append(ability_res.ability_id)
	
	return abilities

func _get_abilities_from_boss_resource(boss_name: String) -> Array:
	# Get abilities from boss resource files
	var abilities = []
	
	if ResourceManager.instance:
		# Try to find boss resource by name/ID
		var boss_resource = null
		
		# Check common boss resource paths
		var boss_paths = [
			"res://resources/enemies/bosses/%s.tres" % boss_name,
			"res://resources/enemies/bosses/%s_boss.tres" % boss_name
		]
		
		for path in boss_paths:
			if ResourceLoader.exists(path):
				boss_resource = load(path)
				break
		
		if boss_resource and boss_resource.has("abilities"):
			for ability_res in boss_resource.abilities:
				if ability_res is AbilityResource:
					abilities.append(ability_res.ability_id)
	
	return abilities

# Force reset all cooldowns for an entity
func reset_all_cooldowns(entity_data: Dictionary):
	match entity_data.type:
		"minion":
			# Reset cooldowns through AbilityExecutor (new system)
			if AbilityExecutor.instance and AbilityExecutor.instance.entity_cooldowns.has(entity_data.id):
				var cooldowns = AbilityExecutor.instance.entity_cooldowns[entity_data.id]
				for ability_id in cooldowns:
					cooldowns[ability_id] = 0.0
				print("[DebugAbilityTrigger] Reset all cooldowns for minion %d" % entity_data.id)
		"boss":
			if is_instance_valid(entity_data.node) and entity_data.node.has_method("reset_all_cooldowns"):
				entity_data.node.reset_all_cooldowns()
				print("[DebugAbilityTrigger] Reset all cooldowns for boss %s" % entity_data.node.name)