extends Node
class_name DebugAbilityTrigger

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
	# Try to trigger through EnemyManager first
	if EnemyManager.instance and EnemyManager.instance.has_method("trigger_enemy_ability"):
		return EnemyManager.instance.trigger_enemy_ability(enemy_id, ability_name)
	
	# Fallback: Try through EnemyBridge
	if EnemyBridge.instance:
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
	
	# Get from enemy data
	if EnemyManager.instance:
		var enemy_data = EnemyManager.instance.get_enemy_data(enemy_id)
		if enemy_data and enemy_data.has("abilities"):
			abilities = enemy_data.abilities
		elif enemy_data and enemy_data.has("enemy_type"):
			# Get default abilities for enemy type
			abilities = _get_default_abilities_for_type(enemy_data.enemy_type)
	
	return abilities

func _get_boss_abilities(boss_node: Node) -> Array:
	var abilities = []
	
	if not is_instance_valid(boss_node):
		return abilities
	
	# Try to get abilities from boss
	if boss_node.has_method("get_abilities"):
		abilities = boss_node.get_abilities()
	elif boss_node.has_method("get_debug_abilities"):
		abilities = boss_node.get_debug_abilities()
	elif "abilities" in boss_node:
		abilities = boss_node.abilities
	else:
		# Try to infer from boss type
		abilities = _get_default_boss_abilities(boss_node.name)
	
	return abilities

func _get_default_abilities_for_type(enemy_type: String) -> Array:
	# Default abilities based on enemy type
	match enemy_type.to_lower():
		"succubus":
			return ["explode", "suction", "speed_boost"]
		"woodland_joe":
			return ["shoot", "rapid_fire"]
		"rat":
			return ["bite"]
		"skeleton":
			return ["bone_throw"]
		_:
			return []

func _get_default_boss_abilities(boss_name: String) -> Array:
	# Default abilities based on boss name
	var name_lower = boss_name.to_lower()
	
	if "thor" in name_lower:
		return ["hammer_throw", "lightning_strike", "thunder_clap"]
	elif "mika" in name_lower:
		return ["charge", "slam", "roar"]
	elif "forsen" in name_lower:
		return ["spawn_minions", "rage", "teleport"]
	else:
		return ["attack"]

# Force reset all cooldowns for an entity
func reset_all_cooldowns(entity_data: Dictionary):
	match entity_data.type:
		"minion":
			# Reset cooldowns through EnemyManager directly
			if EnemyManager.instance and entity_data.id < EnemyManager.instance.ability_cooldowns.size():
				EnemyManager.instance.ability_cooldowns[entity_data.id] = 0.0
		"boss":
			if is_instance_valid(entity_data.node) and entity_data.node.has_method("reset_all_cooldowns"):
				entity_data.node.reset_all_cooldowns()