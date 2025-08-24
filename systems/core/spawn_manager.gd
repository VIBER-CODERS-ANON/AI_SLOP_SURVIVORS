extends Node
class_name SpawnManager

static var instance: SpawnManager

# Resource cache
var loaded_resources: Dictionary = {}  # enemy_id -> EnemyResource

signal entity_spawned(entity_data: Dictionary)
signal spawn_failed(reason: String)

func _ready():
	instance = self
	_load_all_enemy_resources()

func _load_all_enemy_resources():
	# Load all enemy resources from the resources/enemies directory
	var dir = DirAccess.open("res://resources/enemies/")
	if dir:
		_scan_directory_for_resources(dir, "res://resources/enemies/")

func _scan_directory_for_resources(dir: DirAccess, path: String):
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path + "/" + file_name
		if dir.current_is_dir() and file_name != "." and file_name != "..":
			var subdir = DirAccess.open(full_path)
			if subdir:
				_scan_directory_for_resources(subdir, full_path)
		elif file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var resource = load(full_path)
			if resource is EnemyResource:
				loaded_resources[resource.enemy_id] = resource
				print("[SpawnManager] Loaded enemy resource: %s with %d abilities" % [resource.enemy_id, resource.abilities.size()])
				# Debug ability loading
				for ability in resource.abilities:
					if ability is AbilityResource:
						print("  - Ability: %s" % ability.ability_id)
					else:
						print("  - Invalid ability reference!")
		file_name = dir.get_next()

# Unified spawn interface
func spawn_entity(enemy_resource: EnemyResource, position: Vector2, owner_username: String = "") -> Dictionary:
	if not enemy_resource:
		emit_signal("spawn_failed", "Invalid enemy resource")
		return {"success": false, "error": "Invalid resource"}
	
	var result = {}
	match enemy_resource.enemy_category:
		"minion":
			result = _spawn_minion(enemy_resource, position, owner_username)
		"boss":
			result = _spawn_boss(enemy_resource, position, owner_username)
		_:
			emit_signal("spawn_failed", "Unknown enemy category: " + enemy_resource.enemy_category)
			return {"success": false, "error": "Unknown category"}
	
	if result.success:
		emit_signal("entity_spawned", result)
	
	return result

# Spawn by enemy ID (convenience method)
func spawn_entity_by_id(enemy_id: String, position: Vector2, owner_username: String = "") -> Dictionary:
	if not loaded_resources.has(enemy_id):
		emit_signal("spawn_failed", "Enemy ID not found: " + enemy_id)
		return {"success": false, "error": "Enemy not found"}
	
	return spawn_entity(loaded_resources[enemy_id], position, owner_username)

func _spawn_minion(resource: EnemyResource, position: Vector2, username: String) -> Dictionary:
	# Delegate to EnemyManager for array-based handling
	if not EnemyManager.instance:
		return {"success": false, "error": "EnemyManager not initialized"}
	
	var enemy_id = EnemyManager.instance.spawn_from_resource(resource, position, username)
	if enemy_id >= 0:
		return {
			"success": true,
			"type": "minion",
			"id": enemy_id,
			"resource": resource,
			"position": position,
			"owner": username
		}
	else:
		return {"success": false, "error": "Failed to spawn minion"}

func _spawn_boss(resource: EnemyResource, position: Vector2, username: String) -> Dictionary:
	# Delegate to BossFactory for node-based handling
	if not BossFactory.instance:
		return {"success": false, "error": "BossFactory not initialized"}
	
	var boss_node = BossFactory.instance.spawn_from_resource(resource, position, username)
	if boss_node:
		return {
			"success": true,
			"type": "boss",
			"node": boss_node,
			"resource": resource,
			"position": position,
			"owner": username
		}
	else:
		return {"success": false, "error": "Failed to spawn boss"}

# Batch spawning methods
func spawn_multiple(enemy_resource: EnemyResource, positions: Array, owner_username: String = "") -> Array:
	var results = []
	for pos in positions:
		results.append(spawn_entity(enemy_resource, pos, owner_username))
	return results

func spawn_multiple_by_id(enemy_id: String, positions: Array, owner_username: String = "") -> Array:
	if not loaded_resources.has(enemy_id):
		return []
	return spawn_multiple(loaded_resources[enemy_id], positions, owner_username)

# Get available enemy resources
func get_available_enemies() -> Dictionary:
	return loaded_resources

func get_enemy_resource(enemy_id: String) -> EnemyResource:
	return loaded_resources.get(enemy_id, null)

func get_enemies_by_category(category: String) -> Array:
	var enemies = []
	for id in loaded_resources:
		var resource = loaded_resources[id]
		if resource.enemy_category == category:
			enemies.append(resource)
	return enemies

# Reload resources (useful for development)
func reload_resources():
	loaded_resources.clear()
	_load_all_enemy_resources()
