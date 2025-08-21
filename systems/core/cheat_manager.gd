extends Node
class_name CheatManager

## Handles all cheat implementations and debug functionality

signal cheat_executed(cheat_name: String, details: String)

var game_controller: GameController
var player: Player

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

func spawn_xp_orbs_around_player():
	if not player:
		return
	
	var num_orbs = 10
	var radius = 100.0
	var xp_per_orb = 10
	
	var positions = PositionHelper.get_circular_positions_around_point(player.global_position, num_orbs, radius)
	
	for i in range(positions.size()):
		var spawn_pos = positions[i]
		var offset = spawn_pos - player.global_position
		
		var xp_orb = ResourceManager.instantiate_scene("xp_orb")
		xp_orb.process_mode = Node.PROCESS_MODE_PAUSABLE
		xp_orb.xp_value = xp_per_orb
		game_controller.add_child(xp_orb)
		xp_orb.global_position = spawn_pos
		
		if xp_orb.has_method("set_velocity"):
			xp_orb.set_velocity(offset.normalized() * 50)
	
	cheat_executed.emit("spawn_xp_orbs", "%d XP orbs spawned around player" % num_orbs)

func trigger_boss_vote():
	if BossVoteManager.instance:
		BossVoteManager.instance.start_boss_vote()
		cheat_executed.emit("boss_vote", "Boss vote started")

func grant_global_mxp(amount: int):
	if MXPManager.instance:
		MXPManager.instance.total_mxp_available += amount
		MXPManager.instance.mxp_granted.emit(amount)
		
		var feed = _get_action_feed()
		if feed:
			feed.add_message("💰 CHEAT: +%d MXP granted to all!" % amount, Color.YELLOW)
		
		cheat_executed.emit("grant_mxp", "%d MXP granted globally" % amount)

func grant_player_health_boost():
	if not player:
		return
	
	var boost_amount = 500
	player.max_health += boost_amount
	player.current_health = player.max_health
	player.health_changed.emit(player.current_health, player.max_health)
	
	var feed = _get_action_feed()
	if feed:
		feed.add_message("💪 CHEAT: +%d Max HP! Healed to full!" % boost_amount, Color.GREEN)
	
	# Visual feedback
	_apply_health_boost_visual_feedback()
	
	cheat_executed.emit("health_boost", "+%d Max HP granted" % boost_amount)

func spawn_test_rats():
	if not player or not EnemyManager.instance:
		return
	
	var num_rats = 20
	for i in range(num_rats):
		var spawn_pos = PositionHelper.get_random_position_in_ring(player.global_position, 200.0, 400.0)
		
		var username = "TestRat%d" % i
		EnemyManager.instance.spawn_enemy(0, spawn_pos, username, Color.GRAY)
	
	cheat_executed.emit("spawn_rats", "%d test rats spawned" % num_rats)

func spawn_boss_cheat(boss_type: String):
	if not player or not game_controller.boss_factory:
		return
	
	var spawn_pos = game_controller.boss_factory.get_random_spawn_position(player.global_position)
	game_controller.boss_factory.spawn_boss(boss_type, spawn_pos)
	
	cheat_executed.emit("spawn_boss", "%s boss spawned" % boss_type.capitalize())

func clear_all_enemies():
	if EnemyManager.instance:
		EnemyManager.instance.clear_all_enemies()
	
	# Clear node-based enemies
	var enemies = get_tree().get_nodes_in_group("enemies")
	var cleared_count = enemies.size()
	for enemy in enemies:
		enemy.queue_free()
	
	cheat_executed.emit("clear_enemies", "%d enemies cleared" % cleared_count)

func toggle_god_mode():
	if not player or not game_controller.input_manager:
		return
	
	game_controller.input_manager._toggle_god_mode()
	cheat_executed.emit("god_mode", "God mode toggled")

func _apply_health_boost_visual_feedback():
	if not player:
		return
		
	var player_sprite = player.get_node_or_null("SpriteContainer/Sprite")
	if player_sprite:
		var tween = game_controller.create_tween()
		tween.set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(player_sprite, "scale", player_sprite.scale * 1.3, 0.2)
		tween.tween_property(player_sprite, "scale", player_sprite.scale, 0.2)
		tween.parallel().tween_property(player_sprite, "modulate", Color(0.5, 1, 0.5), 0.2)
		tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.3)

func _get_action_feed() -> ActionFeed:
	if game_controller and game_controller.ui_coordinator:
		return game_controller.ui_coordinator.get_action_feed()
	return null

# Batch operations for efficiency
func spawn_multiple_xp_orbs(count: int, radius: float = 100.0, xp_per_orb: int = 10):
	if not player:
		return
	
	var positions = PositionHelper.get_circular_positions_around_point(player.global_position, count, radius)
	
	for i in range(positions.size()):
		var spawn_pos = positions[i]
		var offset = spawn_pos - player.global_position
		
		var xp_orb = ResourceManager.instantiate_scene("xp_orb")
		xp_orb.process_mode = Node.PROCESS_MODE_PAUSABLE
		xp_orb.xp_value = xp_per_orb
		game_controller.add_child(xp_orb)
		xp_orb.global_position = spawn_pos
		
		if xp_orb.has_method("set_velocity"):
			xp_orb.set_velocity(offset.normalized() * 50)
	
	cheat_executed.emit("spawn_multiple_xp_orbs", "%d XP orbs spawned" % count)
