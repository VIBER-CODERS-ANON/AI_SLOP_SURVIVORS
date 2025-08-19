extends CharacterBody2D
class_name EnemyBody

# Bridge for V2 data-driven enemies so node-based systems (weapons, knockback)
# can interact using familiar methods on a PhysicsBody2D.

func _ready():
	# Ensure on enemies layer; pooling code also sets these
	if collision_layer == 0:
		collision_layer = 2
	# Register in enemies group so weapons recognize us
	add_to_group("enemies")

func _get_enemy_id() -> int:
	return int(get_meta("enemy_id", -1))

func _get_manager():
	return EnemyManager.instance if EnemyManager else null


func take_damage(damage_amount: float, attacker: Node = null, _weapon_tags: Array = []):
	var enemy_id := _get_enemy_id()
	var mgr = _get_manager()
	if enemy_id < 0 or mgr == null:
		return
	var killer_name: String = ""
	if attacker:
		if attacker.has_meta("chatter_username"):
			killer_name = str(attacker.get_meta("chatter_username"))
		else:
			killer_name = str(attacker.name)
	var cause: String = "sword"  # Default cause; can be refined via tags if needed
	mgr.damage_enemy(enemy_id, damage_amount, killer_name, cause)
	# Determine crit styling heuristically from tags (Parity-lite with node system)
	var is_crit: bool = false
	if _weapon_tags and _weapon_tags is Array:
		for t in _weapon_tags:
			var lt = str(t).to_lower()
			if lt.find("crit") != -1 or lt == "headshot":
				is_crit = true
				break
	# Spawn damage number like node-based entities
	_spawn_damage_number(damage_amount, is_crit)

func apply_knockback(direction: Vector2, force: float):
	var enemy_id := _get_enemy_id()
	var mgr = _get_manager()
	if enemy_id < 0 or mgr == null:
		return
	var dir := direction.normalized()
	# Apply as an instantaneous velocity impulse in the data model
	if enemy_id < mgr.velocities.size():
		mgr.velocities[enemy_id] += dir * force

func _spawn_damage_number(damage: float, is_crit: bool = false) -> void:
	if DebugSettings.instance and not DebugSettings.instance.damage_numbers_enabled:
		return
	var damage_num = preload("res://ui/damage_number.gd").new()
	damage_num.setup(damage, is_crit)
	if GameController.instance:
		GameController.instance.add_child(damage_num)
		damage_num.global_position = global_position + Vector2(0, -20)
