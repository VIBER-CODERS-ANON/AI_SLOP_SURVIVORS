extends Node
class_name EntitySelector

# Get entity at a specific position
func get_entity_at_position(world_pos: Vector2) -> Dictionary:
	# Check minions first (array-based)
	if EnemyManager.instance:
		var minion_data = _get_minion_at_position(world_pos)
		if not minion_data.is_empty():
			return minion_data
	
	# Check bosses (node-based)
	if BossFactory.instance:
		var boss_data = _get_boss_at_position(world_pos)
		if not boss_data.is_empty():
			return boss_data
	
	return {}

func _get_minion_at_position(world_pos: Vector2) -> Dictionary:
	if not EnemyManager.instance or not EnemyManager.instance.has_method("get_enemy_at_position"):
		return {}
	
	# Call EnemyManager to find enemy at position
	var enemy_id = EnemyManager.instance.get_enemy_at_position(world_pos, 30.0)  # 30 pixel radius
	
	if enemy_id >= 0:
		var enemy_data = EnemyManager.instance.get_enemy_data(enemy_id)
		if enemy_data:
			return {
				"type": "minion",
				"id": enemy_id,
				"data": enemy_data,
				"position": enemy_data.get("position", Vector2.ZERO)
			}
	
	return {}

func _get_boss_at_position(world_pos: Vector2) -> Dictionary:
	if not BossFactory.instance:
		return {}
	
	# Get all boss nodes
	var bosses = get_tree().get_nodes_in_group("bosses")
	
	var closest_boss = null
	var closest_distance = 50.0  # Maximum selection distance
	
	for boss in bosses:
		if not is_instance_valid(boss):
			continue
		
		var distance = boss.global_position.distance_to(world_pos)
		if distance < closest_distance:
			closest_distance = distance
			closest_boss = boss
	
	if closest_boss:
		return {
			"type": "boss",
			"node": closest_boss,
			"data": closest_boss.get_debug_data() if closest_boss.has_method("get_debug_data") else {},
			"position": closest_boss.global_position
		}
	
	return {}

# Get all entities in a radius
func get_entities_in_radius(world_pos: Vector2, radius: float) -> Array:
	var entities = []
	
	# Get minions in radius
	if EnemyManager.instance and EnemyManager.instance.has_method("get_enemies_in_radius"):
		var minion_ids = EnemyManager.instance.get_enemies_in_radius(world_pos, radius)
		for id in minion_ids:
			var enemy_data = EnemyManager.instance.get_enemy_data(id)
			if enemy_data:
				entities.append({
					"type": "minion",
					"id": id,
					"data": enemy_data
				})
	
	# Get bosses in radius
	var bosses = get_tree().get_nodes_in_group("bosses")
	for boss in bosses:
		if not is_instance_valid(boss):
			continue
		
		if boss.global_position.distance_to(world_pos) <= radius:
			entities.append({
				"type": "boss",
				"node": boss,
				"data": boss.get_debug_data() if boss.has_method("get_debug_data") else {}
			})
	
	return entities

# Get entity by ID (for minions) or node reference (for bosses)
func get_entity_by_reference(ref) -> Dictionary:
	if ref is int:
		# It's a minion ID
		if EnemyManager.instance:
			var enemy_data = EnemyManager.instance.get_enemy_data(ref)
			if enemy_data:
				return {
					"type": "minion",
					"id": ref,
					"data": enemy_data
				}
	elif ref is Node:
		# It's a boss node
		if is_instance_valid(ref) and ref.is_in_group("bosses"):
			return {
				"type": "boss",
				"node": ref,
				"data": ref.get_debug_data() if ref.has_method("get_debug_data") else {}
			}
	
	return {}