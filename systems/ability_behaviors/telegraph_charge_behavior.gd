extends BaseAbilityBehavior
class_name TelegraphChargeBehavior

## Telegraph Charge ability behavior implementation
## Shows telegraph warning, then charges at target position, despawning after impact

func execute(entity_id: int, ability: AbilityResource, pos: Vector2, target_data: Dictionary) -> bool:
	if not GameController.instance:
		print("❌ TelegraphChargeBehavior: GameController not found")
		return false
	
	# Get ability parameters
	var params = ability.additional_parameters
	var telegraph_time = params.get("telegraph_time", ability.cast_time)
	var charge_speed = params.get("charge_speed", ability.projectile_speed)
	var despawn_after = params.get("despawn_after_charge", true)
	var show_telegraph = params.get("telegraph_visual", true)
	
	# Get target position
	var target_pos = target_data.get("target_position", Vector2.ZERO)
	if target_pos == Vector2.ZERO:
		# Default to player position
		if GameController.instance.player:
			target_pos = GameController.instance.player.global_position
		else:
			print("❌ TelegraphChargeBehavior: No target position available")
			return false
	
	print("⚡ Starting telegraph charge from %s to %s" % [pos, target_pos])
	
	# Show telegraph visual if enabled
	if show_telegraph:
		_create_charge_telegraph(pos, target_pos, telegraph_time)
	
	# Create timer for charge execution
	var timer = Engine.get_main_loop().create_timer(telegraph_time)
	timer.timeout.connect(_execute_charge.bind(entity_id, pos, target_pos, charge_speed, despawn_after, ability.duration))
	
	# Play sound effect if available
	if ability.sound_effect:
		_play_sound_at(ability.sound_effect, pos)
	
	return true

func _execute_charge(entity_id: int, start_pos: Vector2, target_pos: Vector2, charge_speed: float, despawn_after: bool, charge_duration: float):
	"""Execute the actual charge movement"""
	if not _is_enemy_alive(entity_id):
		print("⚠️ TelegraphChargeBehavior: Enemy %d no longer alive, canceling charge" % entity_id)
		return
	
	# Set velocity toward target for enemy
	if entity_id >= 0 and EnemyManager.instance:
		var enemy_manager = EnemyManager.instance
		var direction = (target_pos - start_pos).normalized()
		
		if entity_id < enemy_manager.velocities.size():
			enemy_manager.velocities[entity_id] = direction * charge_speed
		if entity_id < enemy_manager.move_speeds.size():
			enemy_manager.move_speeds[entity_id] = charge_speed
		
		print("🐎 Enemy %d charging at speed %.0f!" % [entity_id, charge_speed])
		
		# Schedule despawn after charge duration if enabled
		if despawn_after:
			var despawn_timer = Engine.get_main_loop().create_timer(charge_duration)
			despawn_timer.timeout.connect(_despawn_enemy.bind(entity_id))

func _create_charge_telegraph(start_pos: Vector2, end_pos: Vector2, duration: float):
	"""Create a visual telegraph line showing the charge path"""
	var line = Line2D.new()
	line.add_point(start_pos)
	line.add_point(end_pos)
	line.width = 5.0
	line.default_color = Color(1, 1, 0, 0.7)  # Yellow warning line
	
	if GameController.instance:
		GameController.instance.add_child(line)
	else:
		Engine.get_main_loop().current_scene.add_child(line)
	
	# Create pulsing animation
	var tween = line.create_tween()
	tween.set_loops(-1)
	tween.tween_property(line, "default_color:a", 0.3, 0.2)
	tween.tween_property(line, "default_color:a", 0.9, 0.2)
	
	# Remove telegraph after duration
	var cleanup_timer = Engine.get_main_loop().create_timer(duration)
	cleanup_timer.timeout.connect(_cleanup_node.bind(line))

func _despawn_enemy(entity_id: int):
	"""Despawn the enemy after charge completion"""
	if entity_id >= 0 and EnemyManager.instance:
		if _is_enemy_alive(entity_id):
			EnemyManager.instance.despawn_enemy(entity_id)
			print("💀 Enemy %d despawned after charge" % entity_id)

func _is_enemy_alive(entity_id: int) -> bool:
	"""Check if enemy is still alive"""
	if not EnemyManager.instance or entity_id < 0:
		return false
	
	return (entity_id < EnemyManager.instance.alive_flags.size() and 
			EnemyManager.instance.alive_flags[entity_id] == 1)

func _cleanup_node(node: Node):
	"""Safe cleanup helper"""
	if is_instance_valid(node):
		node.queue_free()