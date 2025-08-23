extends Node2D
class_name GameController

## Main game controller - orchestrates all game systems

# Singleton instance
static var instance: GameController

# Signals
signal chat_message_received(username: String, message: String, color: Color)

# Core Managers
var world_setup_manager: WorldSetupManager
var input_manager: InputManager
var session_manager: SessionManager
var ui_coordinator: UICoordinator
var boss_factory: BossFactory
var state_manager: GameStateManager
var cursor_manager: CursorManager
var system_initializer: SystemInitializer
var command_processor: CommandProcessor
var cheat_manager: CheatManager

# References
var player: Player
var twitch_bot: Node
var pause_menu: PauseMenu


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	instance = self
	add_to_group("game_controller")
	
	# Initialize debug settings
	_ensure_debug_settings()
	
	# Initialize cursor manager
	cursor_manager = CursorManager.new()
	cursor_manager.name = "CursorManager"
	add_child(cursor_manager)
	
	# Set custom cursor
	cursor_manager.setup_custom_cursor()
	
	# Initialize core managers
	_initialize_core_managers()
	
	# Initialize command processor
	command_processor = CommandProcessor.new()
	command_processor.name = "CommandProcessor"
	command_processor.game_controller = self
	add_child(command_processor)
	
	# Initialize cheat manager
	cheat_manager = CheatManager.new()
	cheat_manager.name = "CheatManager"
	cheat_manager.game_controller = self
	add_child(cheat_manager)
	
	# Initialize system initializer and all game systems
	system_initializer = SystemInitializer.new()
	system_initializer.name = "SystemInitializer"
	add_child(system_initializer)
	system_initializer.initialize_all_systems(self)
	
	# Setup world and UI
	_setup_game_world()
	
	# Connect systems
	_connect_systems()
	
	# Start session
	session_manager.start_session()
	
	print("🎮 Game initialized!")

func _ensure_debug_settings():
	if not DebugSettings.instance:
		var debug_settings = preload("res://systems/debug/debug_settings.gd").new()
		debug_settings.name = "DebugSettings"
		get_tree().root.call_deferred("add_child", debug_settings)
		debug_settings.call_deferred("apply_settings")

func _ensure_resource_manager():
	if not ResourceManager.instance:
		var resource_manager = ResourceManager.new()
		resource_manager.name = "ResourceManager"
		add_child(resource_manager)

func _initialize_core_managers():
	# World Setup Manager
	world_setup_manager = WorldSetupManager.new()
	world_setup_manager.name = "WorldSetupManager"
	add_child(world_setup_manager)
	
	# Input Manager
	input_manager = InputManager.new()
	input_manager.name = "InputManager"
	input_manager.game_controller = self
	add_child(input_manager)
	
	# Session Manager
	session_manager = SessionManager.new()
	session_manager.name = "SessionManager"
	add_child(session_manager)
	
	# UI Coordinator
	ui_coordinator = UICoordinator.new()
	ui_coordinator.name = "UICoordinator"
	ui_coordinator.game_controller = self
	add_child(ui_coordinator)
	
	# Boss Factory
	boss_factory = BossFactory.new()
	boss_factory.name = "BossFactory"
	boss_factory.game_scene = self
	add_child(boss_factory)
	
	# Game State Manager
	state_manager = GameStateManager.new()
	state_manager.name = "GameStateManager"
	add_child(state_manager)

func _setup_game_world():
	# Ensure ResourceManager is initialized
	_ensure_resource_manager()
	
	# Setup world
	world_setup_manager.setup_world(self)
	
	# Set up position helper
	PositionHelper.set_world_setup_manager(world_setup_manager)
	
	# Create player
	_create_player()
	
	# Setup UI
	var _ui_layer = ui_coordinator.setup_ui(self)
	ui_coordinator.connect_player_signals(player)
	
	# Get reference to the pause menu created by UICoordinator
	pause_menu = ui_coordinator.pause_menu
	
	# Setup background music
	ResourceManager.setup_background_music(self)
	
	# Connect to Twitch
	_connect_twitch_bot()
	
	# Show cheat instructions
	input_manager.show_cheat_instructions()

func _create_player():
	var player_scene = ResourceManager.load_scene("res://entities/player/player.tscn")
	if not player_scene:
		push_error("Failed to load player scene")
		return
	
	player = player_scene.instantiate()
	player.position = Vector2(150, 150)
	add_child(player)
	
	# Connect player signals
	player.died.connect(_on_player_died)
	player.level_up.connect(ui_coordinator._on_player_level_up)
	player.health_changed.connect(ui_coordinator._on_player_health_changed)
	player.experience_gained.connect(ui_coordinator._on_player_experience_gained)
	
	# Set player reference for input manager and cheat manager
	input_manager.player = player
	cheat_manager.player = player

func _connect_systems():
	# Connect input manager signals to cheat manager
	input_manager.xp_orbs_requested.connect(cheat_manager.spawn_xp_orbs_around_player)
	input_manager.boss_vote_requested.connect(cheat_manager.trigger_boss_vote)
	input_manager.mxp_granted.connect(cheat_manager.grant_global_mxp)
	input_manager.hp_boost_requested.connect(func(_amount): cheat_manager.grant_player_health_boost())
	input_manager.rats_spawn_requested.connect(cheat_manager.spawn_test_rats)
	input_manager.boss_spawn_requested.connect(cheat_manager.spawn_boss_cheat)
	input_manager.clear_enemies_requested.connect(cheat_manager.clear_all_enemies)
	input_manager.pause_toggled.connect(_handle_pause_toggle)
	
	# Connect pause menu signals
	if pause_menu:
		pause_menu.resume_requested.connect(_on_resume_requested)
		pause_menu.restart_requested.connect(_on_restart_requested)
		pause_menu.quit_requested.connect(_on_quit_requested)

func _connect_twitch_bot():
	# Find the Twitch bot node
	twitch_bot = get_node_or_null("TwitchBot")
	
	if twitch_bot:
		# Connect to the chat message signal
		if twitch_bot.has_signal("chat_message_received"):
			twitch_bot.chat_message_received.connect(_handle_chat_message)
			var feed = get_action_feed()
			if feed:
				feed.add_message("Twitch integration ready!", Color.GREEN)
		else:
			pass
	else:
		pass

func _handle_chat_message(username: String, message: String, color: Color = Color.WHITE):
	# If no color provided, generate one
	if color == Color.WHITE:
		color = _get_user_color(username)
	
	# Re-emit the signal for other systems (like bosses)
	chat_message_received.emit(username, message, color)
	
	# Check for keywords that affect the game
	var _msg_lower = message.to_lower()
	
	# Handle commands
	if message.begins_with("!"):
		command_processor.process_chat_command(username, message)

# ===== Action Handlers =====

func get_action_feed() -> ActionFeed:
	return ui_coordinator.get_action_feed()

func get_monster_power_stats() -> Dictionary:
	return session_manager.get_monster_power_stats()

func _on_player_died(killer_name: String, death_cause: String):
	# Pause the game for death screen
	state_manager.set_pause(GameStateManager.PauseReason.DEATH_SCREEN, true)
	
	# Show death screen through UICoordinator
	var killer_color = Color.WHITE
	if killer_name != "":
		killer_color = _get_user_color(killer_name)
	
	ui_coordinator.show_death_screen(killer_name, death_cause, killer_color)

# ===== Pause Handling =====

func _handle_pause_toggle():
	# Allow manual pause even if other pause reasons are active, except during death screen
	if state_manager.pause_flags & GameStateManager.PauseReason.DEATH_SCREEN != 0:
		return
	
	state_manager.toggle_manual_pause()
	
	if state_manager.pause_flags & GameStateManager.PauseReason.MANUAL_PAUSE:
		ui_coordinator.show_pause_menu()
	else:
		ui_coordinator.hide_pause_menu()

func _on_resume_requested():
	state_manager.set_pause(GameStateManager.PauseReason.MANUAL_PAUSE, false)

func _on_restart_requested():
	state_manager.clear_all_pause_states()
	get_tree().reload_current_scene()

func _on_quit_requested():
	get_tree().quit()

func _on_twitch_channel_changed(new_channel: String):
	if twitch_bot and twitch_bot.has_method("change_channel"):
		twitch_bot.change_channel(new_channel)
	
	var feed = get_action_feed()
	if feed:
		feed.add_message("📺 Switched to %s's Twitch channel!" % new_channel, Color(0.8, 0.6, 1.0))


# ===== Entity Command Handling =====

func _execute_command_on_all_entities(username: String, method_name: String):
	if not command_processor:
		return
	
	# Convert method names to command names for the V2 system
	var command = ""
	match method_name:
		"trigger_explode":
			command = "explode"
		"trigger_fart":
			command = "fart"
		"trigger_boost":
			command = "boost"
		_:
			return  # Unknown command
	
	command_processor._execute_entity_command(username, command)

func _get_user_color(username: String) -> Color:
	if command_processor:
		return command_processor.get_user_color(username)
	else:
		# Fallback implementation
		var hash_value = username.hash()
		var hue = float(hash_value % 360) / 360.0
		return Color.from_hsv(hue, 0.7, 0.9)

func _process(_delta):
	# Note: Pause handling is now managed by InputManager
	pass

# ===== Boss Spawn Methods =====

func spawn_thor_boss(spawn_pos: Vector2) -> Node:
	if boss_factory:
		return boss_factory.spawn_boss("thor", spawn_pos)
	else:
		push_error("BossFactory not available")
		return null

func spawn_zzran_boss(spawn_pos: Vector2) -> Node:
	if boss_factory:
		return boss_factory.spawn_boss("zzran", spawn_pos)
	else:
		push_error("BossFactory not available")
		return null

func spawn_mika_boss(spawn_pos: Vector2) -> Node:
	if boss_factory:
		return boss_factory.spawn_boss("mika", spawn_pos)
	else:
		push_error("BossFactory not available")
		return null

func spawn_forsen_boss(spawn_pos: Vector2) -> Node:
	if boss_factory:
		return boss_factory.spawn_boss("forsen", spawn_pos)
	else:
		push_error("BossFactory not available")
		return null
