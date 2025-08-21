extends Node
class_name SessionManager

## Manages game session state, timers, and cleanup

signal session_started()
signal session_ended()
signal game_time_updated(time: float)

# Session state
var game_time: float = 0.0
var is_session_active: bool = false
var cleanup_timer: float = 0.0

# Configuration
const CLEANUP_INTERVAL: float = 5.0  # Cleanup every 5 seconds

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(delta: float):
	if not is_session_active:
		return
	
	# Update game time
	game_time += delta
	game_time_updated.emit(game_time)
	
	# Periodic cleanup
	cleanup_timer += delta
	if cleanup_timer >= CLEANUP_INTERVAL:
		cleanup_timer = 0.0
		_perform_cleanup()

func start_session():
	is_session_active = true
	game_time = 0.0
	cleanup_timer = 0.0
	
	# Reset all relevant managers
	_reset_managers()
	
	session_started.emit()
	print("📊 Session started")

func end_session():
	is_session_active = false
	session_ended.emit()
	print("📊 Session ended - Duration: %.1f seconds" % game_time)

func reset_session():
	end_session()
	start_session()

func _reset_managers():
	# Reset TicketSpawnManager
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.reset_session()
	
	# Reset MXPManager
	if MXPManager.instance:
		MXPManager.instance.reset_session()
	
	# Clear enemy manager
	if EnemyManager.instance:
		EnemyManager.instance.clear_all_enemies()
	

func _perform_cleanup():
	# Clean up orphaned nodes
	var orphan_count = 0
	var game_node = get_node_or_null("/root/Game")
	if game_node:
		for child in game_node.get_children():
			if not is_instance_valid(child):
				orphan_count += 1
				child.queue_free()
	
	if orphan_count > 0:
		print("🧹 Cleaned up %d orphaned nodes" % orphan_count)
	
	# Clean up damage numbers
	var damage_numbers = get_tree().get_nodes_in_group("damage_numbers")
	var old_numbers = 0
	for number in damage_numbers:
		if number.has_meta("spawn_time"):
			var age = game_time - number.get_meta("spawn_time")
			if age > 2.0:  # Remove damage numbers older than 2 seconds
				number.queue_free()
				old_numbers += 1
	
	if old_numbers > 0:
		print("🧹 Cleaned up %d old damage numbers" % old_numbers)


func get_monster_power_stats() -> Dictionary:
	if TicketSpawnManager.instance:
		return TicketSpawnManager.instance.get_ramping_stats()
	return {}

func is_paused() -> bool:
	if GameStateManager.instance:
		return GameStateManager.instance.is_paused()
	return false
