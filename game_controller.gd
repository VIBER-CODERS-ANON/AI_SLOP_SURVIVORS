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
	var ui_layer = ui_coordinator.setup_ui(self)
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
	var msg_lower = message.to_lower()
	
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
	
	# Show death screen
	var death_screen = get_node_or_null("UILayer/DeathScreen")
	if death_screen:
		# Try to get the killer's color if they're a twitch chatter
		var killer_color = Color.WHITE
		if player and player.has_meta("last_damage_source"):
			var source = player.get_meta("last_damage_source")
			if source and is_instance_valid(source):
				# Try to get chatter color from various sources
				if source.has_method("get_chatter_color"):
					killer_color = source.get_chatter_color()
				elif source.has_meta("chatter_color"):
					killer_color = source.get_meta("chatter_color")
				elif source.has_meta("original_spawner"):
					var spawner = source.get_meta("original_spawner")
					if spawner and is_instance_valid(spawner) and spawner.has_method("get_chatter_color"):
						killer_color = spawner.get_chatter_color()
				elif source.has_meta("original_owner"):
					var entity_owner = source.get_meta("original_owner")
					if entity_owner and is_instance_valid(entity_owner) and entity_owner.has_method("get_chatter_color"):
						killer_color = entity_owner.get_chatter_color()
		
		death_screen.show_death(killer_name, death_cause, killer_color)
	
	# Notify chat
	var feed = get_action_feed()
	if feed:
		var death_message = "GAME OVER! " + killer_name
		if death_cause != "":
			death_message += " killed the player with " + death_cause + "!"
		else:
			death_message += " killed the player!"
		feed.add_message(death_message, Color.RED)
	



func _on_player_health_changed(new_health: float, max_health: float):
	# Update health display
	var player_stats = get_node_or_null("UILayer/PlayerStatsDisplay")
	if player_stats and player_stats.has_method("update_health"):
		player_stats.update_health(new_health, max_health)

func _on_action_bar_slot_clicked(_slot_index: int):
	# print("Action bar slot %d clicked!" % (slot_index + 1))
	# For now, slot 0 (sword) doesn't do anything special as it's always active
	pass

func _get_safe_spawn_position(from_pos: Vector2, min_dist: float, max_dist: float) -> Vector2:
	# Try to find a safe position avoiding pits and pillars
	for attempt in range(30):
		var angle = randf() * TAU
		var distance = randf_range(min_dist, max_dist)
		var test_pos = from_pos + Vector2(cos(angle), sin(angle)) * distance
		
		# Check if position is safe from obstacles
		if _is_position_safe(test_pos):
			return test_pos
	
	# Fallback to a basic position if all attempts fail
	return from_pos + Vector2(randf_range(-200, 200), randf_range(-200, 200))

func _get_random_safe_arena_position(max_radius: float) -> Vector2:
	# Try to find a safe random position in the arena
	for attempt in range(50):
		var x = randf_range(-max_radius, max_radius)
		var y = randf_range(-max_radius, max_radius)
		var test_pos = Vector2(x, y)
		
		# Check if position is safe from obstacles
		if _is_position_safe(test_pos):
			return test_pos
	
	# Fallback to a position away from center if all attempts fail
	return Vector2(randf_range(200, 400) * (1.0 if randf() > 0.5 else -1.0), 
				  randf_range(200, 400) * (1.0 if randf() > 0.5 else -1.0))

func _is_position_safe(pos: Vector2) -> bool:
	# Check distance from dark pits
	var pits = get_meta("dark_pits", [])
	for pit in pits:
		if pos.distance_to(pit.position) < pit.radius + 50:
			return false
	
	# Check distance from pillars
	var pillars = get_meta("pillars", [])
	for pillar in pillars:
		if pos.distance_to(pillar.position) < pillar.radius + 50:
			return false
	
	# Check arena bounds (half map size is 1500, with some margin)
	if abs(pos.x) > 1400 or abs(pos.y) > 1400:
		return false
	
	return true

func _spawn_twitch_rat(_username: String, _color: Color):
	# LEGACY FUNCTION - Disabled with new ticket system
	pass

# Legacy tracking - still used by entities themselves to register with GameController
func track_twitch_entity(_username: String, _entity: Node):
	# Now just forwards to TicketSpawnManager
	pass

func register_entity_for_tracking(_username: String):
	# Legacy function - no longer used
	pass

func _on_player_experience_gained(_amount: int):
	# Update XP bar
	var xp_bar = get_node_or_null("UILayer/XPBar")
	if xp_bar and player:
		xp_bar.update_xp(player.experience, player.experience_to_next_level, player.level)

func _on_player_level_up(new_level: int):
	# Handle level up
	# print("ðŸŽ‰ LEVEL UP! Now level %d!" % new_level)
	
	# Report to action feed
	var level_feed = get_action_feed()
	if level_feed:
		level_feed.player_leveled_up(new_level)
	
	# Update XP bar
	var xp_bar = get_node_or_null("UILayer/XPBar")
	if xp_bar:
		xp_bar.on_level_up(new_level)
		# Update with new values
		if player:
			xp_bar.update_xp(player.experience, player.experience_to_next_level, player.level)
	
	# Show level up message in chat
	var feed = get_action_feed()
	if feed:
		feed.add_message("LEVEL UP! You are now level %d!" % new_level, Color.GOLD)
	
	# Show boon selection UI
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		var boon_selection = ui_layer.get_node_or_null("BoonSelection")
		if boon_selection:
			# Use the new pause system
			state_manager.set_pause(GameStateManager.PauseReason.LEVEL_UP_SELECTION, true)
			boon_selection.show_selection()

func get_action_feed() -> ActionFeed:
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		return ui_layer.get_node_or_null("ActionFeed")
	return null

func _on_boon_selected(boon: BaseBoon):
	if not player:
		return
	
	# Get the boon manager and apply the boon
	var boon_manager = BoonManager.get_instance()
	if boon_manager:
		boon_manager.apply_boon(boon, player)
		
		# Handle area_of_effect scaling if needed
		if boon.base_type == "area_of_effect":
			var weapon = player.get_primary_weapon()
			if weapon:
				# AoE scaling handled differently in new weapon system
				pass  # TODO: Implement AoE scaling for new weapons
	
	# Report to action feed
	var boon_feed = get_action_feed()
	if boon_feed:
		var rarity_color = boon.get_display_color()
		boon_feed.add_message("Boon acquired: [%s] %s" % [boon.rarity.display_name, boon.display_name], rarity_color)
	
	# Clear level up pause state
	state_manager.set_pause(GameStateManager.PauseReason.LEVEL_UP_SELECTION, false)

func _scale_aoe_ability(ability_node: Node, scale_multiplier: float):
	# Scale collision shapes for AoE abilities
	var collision_shape = ability_node.get_node_or_null("CollisionShape2D")
	if collision_shape and collision_shape.shape:
		# Store original size if not already stored
		if not collision_shape.has_meta("original_shape_scale"):
			if collision_shape.shape is RectangleShape2D:
				collision_shape.set_meta("original_shape_scale", collision_shape.shape.size)
			elif collision_shape.shape is CircleShape2D:
				collision_shape.set_meta("original_shape_scale", collision_shape.shape.radius)
		
		# Apply scaling
		if collision_shape.shape is RectangleShape2D:
			var original_size = collision_shape.get_meta("original_shape_scale")
			collision_shape.shape.size = original_size * scale_multiplier
		elif collision_shape.shape is CircleShape2D:
			var original_radius = collision_shape.get_meta("original_shape_scale")
			collision_shape.shape.radius = original_radius * scale_multiplier
		
		# print("ðŸ”§ Scaled AoE ability to ", scale_multiplier, "x size")

func _setup_custom_cursor():
	# Load and set the custom gauntlet cursor
	var cursor_texture = load("res://ui/gauntlet_cursor_small.png")
	if cursor_texture:
		# Set cursor with hotspot at the tip of the pointing finger
		# Adjust hotspot based on where the actual point is in the image
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, cursor_hotspot)
		# print("Ã°ÂŸÂŽÂ® Custom WC3-style gauntlet cursor loaded!")
		
		# Cursor setup complete!
	else:
		# print("Ã¢ÂÂŒ Failed to load custom cursor!")
		pass

# Old function removed - was causing duplicate tilemap rendering with checkerboard pattern
# Now using SimpleDungeonSetup.setup_dungeon() with proper PixelLab tileset
# Removed functions: _setup_dungeon_floor, _render_dungeon_to_tilemap, _create_brutal_tileset_texture
	# print("Ã°ÂŸÂÂ—Ã¯Â¸Â Setting up dungeon floor...")
# REMOVED: Old tilemap rendering function that created checkerboard pattern
# Now using PixelLabTilesetLoader with proper Wang tiles

func _create_brutal_tileset_texture() -> Texture2D:
	# OLD FUNCTION - DO NOT USE - Causes checkerboard pattern
	push_error("OLD TILESET FUNCTION CALLED - This should not happen!")
	return null  # Return null to prevent any tileset creation
	
	# UNREACHABLE CODE REMOVED - Was creating brutal tileset texture
	# var tile_size = 32
	# var atlas_size = Vector2i(tile_size * 4, tile_size * 4)  # 4x4 grid for 16 tiles
	# var image = Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	
	# Define brutal colors
	# var colors = {
	# 	"stone": Color(0.15, 0.15, 0.2),      # Dark blue-gray stone
	# 	"blood": Color(0.4, 0.05, 0.05),      # Dark dried blood
	# 	"gore": Color(0.6, 0.1, 0.0),         # Fresh gore
	# 	"wall": Color(0.05, 0.05, 0.08),      # Almost black walls
	# 	"lava": Color(0.8, 0.2, 0.0)          # Molten lava
	# }
	
	# Create tiles with different blood/gore patterns based on corner configuration
	# for i in range(16):
	# 	var x_offset = (i % 4) * tile_size
	# 	var y_offset = (i / 4.0) * tile_size
		
		# Count how many corners have upper terrain (blood/gore)
		# var corner_count = 0
		# for bit in range(4):
		# 	if i & (1 << bit):
		# 		corner_count += 1
		
		# Base color depends on corner count
		# var base_color: Color
		# if corner_count == 0:
		# 	base_color = colors.stone
		# elif corner_count <= 2:
		# 	base_color = colors.stone.lerp(colors.blood, corner_count * 0.3)
		# else:
		# 	base_color = colors.blood.lerp(colors.gore, (corner_count - 2) * 0.5)
		
		# Fill tile with base color and add texture
		# for y in range(tile_size):
		# 	for x in range(tile_size):
		# 		var pixel_color = base_color
				
				# Add noise for texture
				# var noise = randf() * 0.15 - 0.075
				# pixel_color = pixel_color + Color(noise, noise, noise, 0)
				
				# Add cracks and details based on position
				# if (x + y) % 8 == 0:
				# 	pixel_color = pixel_color.darkened(0.2)
				
				# Add blood splatters for tiles with gore
				# if corner_count > 2 and randf() < 0.1:
				# 	pixel_color = colors.gore.darkened(randf() * 0.3)
				
				# Darken edges
				# if x == 0 or x == tile_size - 1 or y == 0 or y == tile_size - 1:
				# 	pixel_color = pixel_color.darkened(0.3)
				
				# image.set_pixel(x_offset + x, y_offset + y, pixel_color)
	
	# var texture = ImageTexture.create_from_image(image)
	# print("Ã°ÂŸÂŽÂ¨ Created brutal tileset texture: ", texture.get_size())
	# return texture

func _setup_cursor_debug():
	# Add hotspot display label
	var hotspot_label = Label.new()
	hotspot_label.name = "HotspotDisplay"
	hotspot_label.text = "Hotspot: " + str(cursor_hotspot)
	hotspot_label.add_theme_font_size_override("font_size", 24)
	hotspot_label.modulate = Color(1, 1, 0)  # Yellow
	hotspot_label.position = Vector2(10, 10)
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(hotspot_label)
		set_meta("hotspot_label", hotspot_label)
	
func _setup_cursor_debug_crosshair():
	# Create a canvas layer for the debug cursor so it's always on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "DebugCursorLayer"
	canvas_layer.layer = 100  # High layer to be on top
	add_child(canvas_layer)
	
	# Create a crosshair overlay to show true mouse position
	var debug_container = Control.new()
	debug_container.name = "DebugCursor"
	debug_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_container.z_index = 999
	
	# Horizontal line
	var h_line = ColorRect.new()
	h_line.name = "HLine"
	h_line.color = Color(1, 0, 0, 0.8)  # Red with more opacity
	h_line.size = Vector2(40, 2)
	h_line.position = Vector2(-20, -1)
	h_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_container.add_child(h_line)
	
	# Vertical line
	var v_line = ColorRect.new()
	v_line.name = "VLine"
	v_line.color = Color(1, 0, 0, 0.8)  # Red with more opacity
	v_line.size = Vector2(2, 40)
	v_line.position = Vector2(-1, -20)
	v_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_container.add_child(v_line)
	
	# Center dot
	var dot = ColorRect.new()
	dot.name = "Dot"
	dot.color = Color(1, 1, 0, 1)  # Yellow for visibility
	dot.size = Vector2(6, 6)
	dot.position = Vector2(-3, -3)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_container.add_child(dot)
	
	# Add to canvas layer (NOT ui layer)
	canvas_layer.add_child(debug_container)
	
	# Store reference for updating
	set_meta("debug_cursor", debug_container)
	# print("Ã°ÂŸÂ”Â´ Debug crosshair added - shows true mouse position")

func _toggle_god_mode():
	if not player:
		return
	
	# Toggle invulnerability
	player.invulnerable = not player.invulnerable
	
	# Visual feedback
	var god_feed = get_action_feed()
	if god_feed:
		if player.invulnerable:
			god_feed.add_message("GOD MODE: ON", Color(1, 1, 0))
			# print("ðŸŒŸ GOD MODE ENABLED")
			# Add golden glow to player
			var player_sprite = player.get_node_or_null("SpriteContainer/Sprite")
			if player_sprite:
				player_sprite.modulate = Color(1.5, 1.3, 0.8)
		else:
			god_feed.add_message("GOD MODE: OFF", Color(0.5, 0.5, 0.5))
			# print("ðŸŒŸ GOD MODE DISABLED")
			# Remove glow
			var player_sprite = player.get_node_or_null("SpriteContainer/Sprite")
			if player_sprite:
				player_sprite.modulate = Color.WHITE

# Legacy MXP command handler - replaced by MXPModifierManager
# All MXP commands are now processed through MXPModifierManager.process_command()

func _handle_vote_command(username: String, message: String):
	if not BossVoteManager.instance:
		return
	
	# Extract vote number
	var vote_match = RegEx.new()
	vote_match.compile("^!vote(\\d)$")
	var result = vote_match.search(message)
	
	if result:
		var vote_num = int(result.get_string(1))
		BossVoteManager.instance.handle_vote_command(username, vote_num)

func _handle_evolve_command(username: String, message: String):
	var evolution_system = get_node_or_null("EvolutionSystem")
	if not evolution_system:
		# print("âŒ Evolution system not found!")
		return
	
	var msg_lower = message.to_lower()
	# print("ðŸ§¬ Evolution command received: ", msg_lower, " from ", username)
	
	# Extract evolution name from command
	var evolution_name = msg_lower.substr(7).strip_edges()  # Remove "!evolve" and trim
	
	if evolution_name.is_empty():
		# Show available evolutions
		var feed = get_action_feed()
		feed.add_message("Available evolutions: !evolvewoodlandjoe (5 MXP), !evolvesuccubus (10 MXP)", Color(0.8, 0.8, 0))
		return
	
	# print("ðŸ§¬ Attempting evolution to: ", evolution_name)
	
	# Attempt evolution
	var _success = evolution_system.request_evolution(username, evolution_name)
	# print("ðŸ§¬ Evolution request result: ", success)

func _spawn_xp_orbs_around_player():
	if not player:
		return
	
	# print("💎 Spawning XP orbs around player! (100 XP total)")
	
	# Spawn 10 XP orbs in a circle around the player
	var num_orbs = 10
	var radius = 100.0
	var xp_per_orb = 10  # 10 orbs × 10 XP = 100 XP total!
	
	for i in range(num_orbs):
		var angle = (TAU / num_orbs) * i
		var offset = Vector2(cos(angle), sin(angle)) * radius
		var spawn_pos = player.global_position + offset
		
		# Create XP orb
		var xp_orb = preload("res://entities/pickups/xp_orb.tscn").instantiate()
		xp_orb.process_mode = Node.PROCESS_MODE_PAUSABLE
		xp_orb.xp_value = xp_per_orb  # Set to 10 XP each
		add_child(xp_orb)
		xp_orb.global_position = spawn_pos
		
		# Make them move slightly outward for visual effect
		if xp_orb.has_method("set_velocity"):
			xp_orb.set_velocity(offset.normalized() * 50)
	
	# Action feed notification
	var xp_feed = get_action_feed()
	if xp_feed:
		xp_feed.add_message("✨ Spawned 100 XP! (10 orbs × 10 XP)", Color(1, 0.8, 0.2))

func _setup_background_music():
	# Create background music player
	var music_player = AudioStreamPlayer.new()
	music_player.name = "BackgroundMusic"
	music_player.volume_db = -6.0  # 50% volume (in decibels)
	music_player.bus = "Music"  # Use Music bus
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS  # Music continues during pause
	add_child(music_player)
	
	# Load and play Rats in the Rain
	var music_stream = preload("res://music/Rats_in_the_Rain_Deaux.mp3")
	music_player.stream = music_stream
	
	# Make it loop
	if music_stream is AudioStreamMP3:
		music_stream.loop = true
	
	# Start playing
	music_player.play()
	
	# print("ðŸŽµ Now playing: Rats in the Rain Deaux at 50% volume!")

func _cleanup_dead_references():
	# Cleanup handled by TicketSpawnManager now
	pass
	
	# Also clean up any orphaned nodes
	var orphan_count = 0
	for child in get_children():
		if not is_instance_valid(child):
			orphan_count += 1
			child.queue_free()
	
	if orphan_count > 0:
		# print("ðŸ§¹ Cleaned up ", orphan_count, " orphaned nodes")
		pass

func _handle_pause_toggle():
	if state_manager.pause_flags & ~GameStateManager.PauseReason.MANUAL_PAUSE != 0:
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
