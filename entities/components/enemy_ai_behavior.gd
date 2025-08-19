class_name EnemyAIBehavior
extends Node

signal aggro_state_changed(is_aggroed: bool)
signal target_changed(new_target: Node2D)

@export_group("Aggro Settings")
@export var aggro_radius: float = 300.0
@export var deaggro_radius: float = 400.0
@export var aggro_check_interval: float = 0.5

@export_group("Wandering Settings")
@export var enable_wandering: bool = true
@export var wander_radius: float = 100.0
@export var wander_speed: float = 50.0
@export var wander_change_interval: float = 2.0

var is_aggroed: bool = false
var current_target: Node2D = null
var wander_target: Vector2
var wander_timer: float = 0.0
var aggro_check_timer: float = 0.0

var _enemy: BaseEnemy
var _initial_position: Vector2

func initialize(enemy: BaseEnemy) -> void:
	_enemy = enemy
	_initial_position = enemy.global_position
	if enable_wandering:
		_randomize_wander_target()

func process_ai(delta: float) -> void:
	if not _enemy or not is_instance_valid(_enemy):
		return
	
	_update_aggro_state(delta)
	
	if not is_aggroed and enable_wandering:
		_handle_wandering(delta)

func _update_aggro_state(delta: float) -> void:
	aggro_check_timer += delta
	if aggro_check_timer < aggro_check_interval:
		return
	
	aggro_check_timer = 0.0
	var player = _find_player()
	
	if not player:
		if is_aggroed:
			_set_aggro_state(false)
		return
	
	var distance_to_player = _enemy.global_position.distance_to(player.global_position)
	
	if not is_aggroed and distance_to_player <= aggro_radius:
		current_target = player
		_set_aggro_state(true)
	elif is_aggroed and distance_to_player > deaggro_radius:
		current_target = null
		_set_aggro_state(false)

func _set_aggro_state(new_state: bool) -> void:
	if is_aggroed == new_state:
		return
	
	is_aggroed = new_state
	aggro_state_changed.emit(is_aggroed)
	
	if is_aggroed:
		target_changed.emit(current_target)
	else:
		target_changed.emit(null)
		if enable_wandering:
			_randomize_wander_target()

func _handle_wandering(delta: float) -> void:
	if not enable_wandering or is_aggroed:
		return
	
	wander_timer += delta
	if wander_timer >= wander_change_interval:
		_randomize_wander_target()
		wander_timer = 0.0
	
	var direction = (wander_target - _enemy.global_position).normalized()
	_enemy.velocity = direction * wander_speed
	
	if _enemy.global_position.distance_to(wander_target) < 10.0:
		_randomize_wander_target()
		wander_timer = 0.0

func _randomize_wander_target() -> void:
	var angle = randf() * TAU
	var distance = randf_range(wander_radius * 0.5, wander_radius)
	wander_target = _initial_position + Vector2(cos(angle), sin(angle)) * distance

func _find_player() -> Node2D:
	var tree = _enemy.get_tree()
	if not tree:
		return null
	
	var players = tree.get_nodes_in_group("player")
	if players.is_empty():
		return null
	
	return players[0]

func get_movement_direction() -> Vector2:
	if is_aggroed and current_target:
		return (_enemy.global_position.direction_to(current_target.global_position))
	elif enable_wandering:
		return (_enemy.global_position.direction_to(wander_target))
	return Vector2.ZERO

func get_distance_to_target() -> float:
	if current_target:
		return _enemy.global_position.distance_to(current_target.global_position)
	return INF