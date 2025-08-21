extends Node
class_name InputManager

## Handles all debug inputs, cheats, and testing commands

signal god_mode_toggled(enabled: bool)
signal xp_orbs_requested()
signal boss_vote_requested()
signal mxp_granted(amount: int)
signal hp_boost_requested(amount: int)
signal rats_spawn_requested()
signal boss_spawn_requested(boss_type: String)
signal clear_enemies_requested()
signal pause_toggled()

# Cheat state
var god_mode_enabled: bool = false

# References (set by GameController)
var player: Player
var game_controller: Node2D

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent):
	if not event.is_pressed():
		return
	
	# CTRL combos
	if event.ctrl_pressed:
		_handle_ctrl_cheats(event)
	# ALT combos
	elif event.alt_pressed:
		_handle_alt_cheats(event)
	# Regular inputs
	else:
		_handle_regular_inputs(event)

func _handle_ctrl_cheats(event: InputEvent):
	if not event is InputEventKey:
		return
	match event.keycode:
		KEY_1:  # God mode
			_toggle_god_mode()
		KEY_2:  # Spawn XP
			xp_orbs_requested.emit()
			_show_cheat_message("✨ Spawned 100 XP! (10 orbs × 10 XP)", Color(1, 0.8, 0.2))
		KEY_3:  # Skip level
			if player:
				player._perform_level_up()
				_show_cheat_message("📈 Forced level up!", Color.GOLD)
		KEY_4:  # Boss vote
			boss_vote_requested.emit()
			_show_cheat_message("🗳️ Boss vote initiated!", Color.CYAN)

func _handle_alt_cheats(event: InputEvent):
	if not event is InputEventKey:
		return
	match event.keycode:
		KEY_1:  # +1 MXP to all
			mxp_granted.emit(1)
			_show_cheat_message("💰 +1 MXP to all chatters!", Color.GOLD)
		KEY_2:  # +500 HP
			hp_boost_requested.emit(500)
			_show_cheat_message("❤️ +500 HP!", Color.RED)
		KEY_3:  # Spawn rats
			rats_spawn_requested.emit()
			_show_cheat_message("🐀 Spawning rat swarm!", Color.GRAY)
		KEY_4:  # Clear screen damage numbers
			_clear_damage_numbers()
			_show_cheat_message("🧹 Cleared damage numbers", Color.WHITE)
		KEY_5:  # Spawn Forsen
			boss_spawn_requested.emit("forsen")
			_show_cheat_message("🐴 Spawning Forsen boss!", Color.PURPLE)
		KEY_6:  # Spawn Thor
			boss_spawn_requested.emit("thor")
			_show_cheat_message("⚡ Spawning Thor boss!", Color.CYAN)
		KEY_7:  # Spawn Mika
			boss_spawn_requested.emit("mika")
			_show_cheat_message("👹 Spawning Mika boss!", Color.RED)
		KEY_8:  # Spawn ZZran
			boss_spawn_requested.emit("zzran")
			_show_cheat_message("🔮 Spawning ZZran boss!", Color.MAGENTA)
		KEY_9:  # Clear all enemies
			clear_enemies_requested.emit()
			_show_cheat_message("💥 Cleared all enemies!", Color.ORANGE)

func _handle_regular_inputs(event: InputEvent):
	if not event is InputEventKey:
		return
	match event.keycode:
		KEY_ESCAPE:
			pause_toggled.emit()
		KEY_P:  # Alternative pause key
			pause_toggled.emit()

func _toggle_god_mode():
	if not player:
		return
	
	god_mode_enabled = not god_mode_enabled
	player.invulnerable = god_mode_enabled
	
	god_mode_toggled.emit(god_mode_enabled)
	
	if god_mode_enabled:
		_show_cheat_message("GOD MODE: ON", Color(1, 1, 0))
		var player_sprite = player.get_node_or_null("SpriteContainer/Sprite")
		if player_sprite:
			player_sprite.modulate = Color(1.5, 1.3, 0.8)
	else:
		_show_cheat_message("GOD MODE: OFF", Color(0.5, 0.5, 0.5))
		var player_sprite = player.get_node_or_null("SpriteContainer/Sprite")
		if player_sprite:
			player_sprite.modulate = Color.WHITE

func _clear_damage_numbers():
	var damage_numbers = get_tree().get_nodes_in_group("damage_numbers")
	for number in damage_numbers:
		number.queue_free()

func _show_cheat_message(text: String, color: Color):
	if game_controller and game_controller.has_method("get_action_feed"):
		var feed = game_controller.get_action_feed()
		if feed:
			feed.add_message(text, color)

func show_cheat_instructions():
	var messages = [
		["Testing Cheats: CTRL+1 = God Mode | CTRL+2 = Spawn XP | CTRL+4 = Boss Vote", Color(0.8, 0.8, 0.8)],
		["More Cheats: ALT+1 = +1 MXP All | ALT+2 = +500 HP | ALT+3 = Spawn Rats", Color(0.8, 0.8, 0.8)],
		["Boss Spawns: ALT+5 = Forsen | ALT+6 = Thor | ALT+7 = Mika | ALT+8 = ZZran", Color(0.8, 0.8, 0.8)],
		["Performance: ALT+9 = Clear All Enemies", Color(0.8, 0.8, 0.8)]
	]
	
	for msg in messages:
		_show_cheat_message(msg[0], msg[1])
