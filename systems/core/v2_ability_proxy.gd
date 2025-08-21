extends CharacterBody2D
class_name V2AbilityProxy

## Proxy node for V2 enemies to use ability instances
## Provides interface between data-oriented enemies and node-based abilities

var enemy_id: int = -1
var enemy_manager: Node = null
var tracked_ability: BaseAbility = null
var update_timer: Timer
var process_timer: Timer
var original_speed: float = 0.0

func setup(p_enemy_id: int, p_enemy_manager: Node, username: String = "") -> void:
	enemy_id = p_enemy_id
	enemy_manager = p_enemy_manager
	
	# Set metadata for attribution
	set_meta("enemy_id", enemy_id)
	set_meta("is_v2_proxy", true)
	if username != "":
		set_meta("chatter_username", username)
	
	# Add sprite for abilities that expect it
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.scale = Vector2(0.75, 0.75)
	add_child(sprite)
	
	# Update position to follow enemy
	update_timer = Timer.new()
	update_timer.wait_time = 0.05
	update_timer.one_shot = false
	update_timer.timeout.connect(_update_position)
	add_child(update_timer)
	update_timer.start()

func _update_position() -> void:
	if not enemy_manager:
		queue_free()
		return
	
	if enemy_id < enemy_manager.positions.size() and enemy_manager.alive_flags[enemy_id] == 1:
		global_position = enemy_manager.positions[enemy_id]
	else:
		# Enemy died
		if tracked_ability and tracked_ability.has_method("_end_channel"):
			tracked_ability._end_channel()
		queue_free()

func attach_ability(ability_class, target_data: Dictionary) -> bool:
	# Create ability instance
	tracked_ability = ability_class.new()
	tracked_ability.on_added(self)
	
	# Try to execute
	if tracked_ability.can_execute(self, target_data):
		tracked_ability.execute(self, target_data)
		
		# Handle channeled abilities
		if tracked_ability.has_method("update"):
			process_timer = Timer.new()
			process_timer.wait_time = 0.016
			process_timer.one_shot = false
			process_timer.timeout.connect(_update_ability)
			add_child(process_timer)
			process_timer.start()
		
		# Handle movement stop for channeled abilities
		if tracked_ability.ability_tags.has("Channel"):
			_stop_movement()
			
			# Connect to channel end signal if it exists
			if tracked_ability.has_signal("succ_ended"):
				tracked_ability.succ_ended.connect(_restore_movement)
		
		return true
	
	return false

func _update_ability() -> void:
	if tracked_ability:
		# Check if still channeling
		var is_channeling = tracked_ability.get("is_channeling")
		if is_channeling:
			tracked_ability.update(0.016, self)
		else:
			_restore_movement()
			if process_timer:
				process_timer.queue_free()
				process_timer = null

func _stop_movement() -> void:
	if enemy_manager and enemy_id < enemy_manager.move_speeds.size():
		original_speed = enemy_manager.move_speeds[enemy_id]
		enemy_manager.move_speeds[enemy_id] = 0.0

func _restore_movement() -> void:
	if enemy_manager and enemy_id < enemy_manager.move_speeds.size():
		enemy_manager.move_speeds[enemy_id] = original_speed

# Required methods for abilities
func get_chatter_username() -> String:
	return get_meta("chatter_username", "Unknown")

func get_display_name() -> String:
	return get_meta("chatter_username", "Enemy")

func on_ability_executed(_ability) -> void:
	pass  # Stub for ability system

func _exit_tree() -> void:
	# Cleanup
	if tracked_ability:
		if tracked_ability.has_method("on_removed"):
			tracked_ability.on_removed(self)
		if tracked_ability.has_method("_end_channel"):
			tracked_ability._end_channel()
	
	_restore_movement()