extends Node2D
class_name GameController

## Main game controller that manages the game state and systems

# Singleton instance
static var instance: GameController

# Signals
signal chat_message_received(username: String, message: String, color: Color)

# References
var player: Player
# var chat_display: ChatDisplay # Removed - no longer needed
var twitch_bot: Node
var state_manager: GameStateManager
var pause_menu: PauseMenu

# Game state
var game_time: float = 0.0
var is_paused: bool = false
var cleanup_timer: float = 0.0  # Periodic cleanup

# Spawning
var mana_gem_spawn_timer: float = 60.0  # Start spawn after 1 minute
var mana_gem_spawn_interval: float = 60.0  # Spawn every 60 seconds (1 per minute)
var spawn_radius: float = 200.0  # Closer spawns for testing

# Twitch chatter entity tracking - NOW HANDLED BY TicketSpawnManager
# Legacy tracking kept for command compatibility during transition
var rat_spawn_radius: float = 600.0  # Spawn rats further away

# Get current ramping stats
func get_monster_power_stats() -> Dictionary:
	if TicketSpawnManager.instance:
		return TicketSpawnManager.instance.get_ramping_stats()
	return {}

func _ready():
	# Game controller should continue during pause
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initialize debug settings if not already created
	if not DebugSettings.instance:
		var debug_settings = preload("res://systems/debug_settings.gd").new()
		debug_settings.name = "DebugSettings"
		get_tree().root.call_deferred("add_child", debug_settings)
		debug_settings.call_deferred("apply_settings")
	
	# Set custom cursor
	_setup_custom_cursor()
	
	# Set singleton instance
	instance = self
	
	# Add to group for easier finding
	add_to_group("game_controller")
	
	# Create game state manager
	state_manager = GameStateManager.new()
	state_manager.name = "GameStateManager"
	add_child(state_manager)
	
	# Create audio manager
	var audio_manager = AudioManager.new()
	audio_manager.name = "AudioManager"
	add_child(audio_manager)
	
	# Create NPC rarity manager
	var npc_rarity_manager = preload("res://systems/npc_rarity_system/npc_rarity_manager.gd").new()
	npc_rarity_manager.name = "NPCRarityManager"
	add_child(npc_rarity_manager)
	
	# Initialize Impact Sound System
	var impact_sound_system = preload("res://systems/weapon_system/impact_sound_system.gd").new()
	impact_sound_system.name = "ImpactSoundSystem"
	add_child(impact_sound_system)
	
	# Create MXP manager
	var mxp_manager = MXPManager.new()
	mxp_manager.name = "MXPManager"
	add_child(mxp_manager)
	
	# Create MXP modifier manager
	var mxp_modifier_manager = MXPModifierManager.new()
	mxp_modifier_manager.name = "MXPModifierManager"
	add_child(mxp_modifier_manager)
	
	# Create chatter entity manager
	var chatter_manager = ChatterEntityManager.new()
	chatter_manager.name = "ChatterEntityManager"
	add_child(chatter_manager)
	
	# Create settings manager
	var settings_manager = preload("res://systems/settings_manager.gd").new()
	settings_manager.name = "SettingsManager"
	add_child(settings_manager)
	
	# Create boss vote manager
	var boss_vote_manager = preload("res://systems/boss_vote_manager.gd").new()
	boss_vote_manager.name = "BossVoteManager"
	add_child(boss_vote_manager)
	
	# Create ticket spawn manager
	var ticket_spawn_manager = TicketSpawnManager.new()
	ticket_spawn_manager.name = "TicketSpawnManager"
	add_child(ticket_spawn_manager)
	
	# Create flocking system for zombie horde behavior
	var flocking_system = preload("res://systems/flocking_system.gd").new()
	flocking_system.name = "FlockingSystem"
	add_child(flocking_system)
	
	# Create boss buff manager
	var boss_buff_manager = preload("res://systems/boss_buff_manager.gd").new()
	boss_buff_manager.name = "BossBuffManager"
	add_child(boss_buff_manager)
	
	# Create evolution system
	var evolution_system = preload("res://systems/evolution_system/evolution_system.gd").new()
	evolution_system.name = "EvolutionSystem"
	add_child(evolution_system)
	
	# Skip navigation manager for now - causing performance issues
	# var nav_manager = preload("res://systems/navigation_system/navigation_manager.gd").new()
	# nav_manager.name = "NavigationManager"
	# add_child(nav_manager)
	
	# Set up the game world
	_setup_world()
	
	# Set up UI
	_setup_ui()
	
	# Connect to Twitch bot
	_connect_twitch_bot()
	
	# print("ðŸŽ® Game initialized! Use WASD to move. Press ESC to pause.")
	
	# Initialize XP bar with starting values
	var xp_bar = get_node_or_null("UILayer/XPBar")
	if xp_bar and player:
		xp_bar.update_xp(player.experience, player.experience_to_next_level, player.level)
	
	# Initialize HP display
	var hp_label = get_node_or_null("UILayer/HPDisplay/HPLabel")
	if hp_label and player:
		hp_label.text = "HP: %d/%d" % [int(player.current_health), int(player.max_health)]
	
	# Set up background music
	_setup_background_music()
	
	# Show cheat instructions
	var cheat_feed = get_action_feed()
	if cheat_feed:
		cheat_feed.add_message("🎮 Testing Cheats: CTRL+1 = God Mode | CTRL+2 = Spawn 100 XP | CTRL+4 = Boss Vote", Color(0.8, 0.8, 0.8))
		cheat_feed.add_message("ðŸŽ® More Cheats: ALT+1 = +1 MXP All | ALT+2 = +500 HP & Full Heal", Color(0.8, 0.8, 0.8))

func _setup_world():
	# Arena size - DOUBLED to 3000
	var arena_size = 3000.0
	var half_size = arena_size / 2.0
	
	# Create navigation region first
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	add_child(nav_region)
	
	# Create navigation polygon for the arena
	var nav_poly = NavigationPolygon.new()
	
	# Create arena bounds as navigation polygon
	var arena_points = PackedVector2Array([
		Vector2(-half_size, -half_size),
		Vector2(half_size, -half_size),
		Vector2(half_size, half_size),
		Vector2(-half_size, half_size)
	])
	nav_poly.add_outline(arena_points)
	
	# We'll add obstacle outlines after creating them
	
	# BRUTAL DUNGEON GENERATION!
	# Replace the complex pipeline with a minimal, robust ground tilemap
	if get_node_or_null("GroundTileMap") == null:
		var ground_tilemap = preload("res://systems/tilemap_system/ground_tilemap.gd").new()
		ground_tilemap.name = "GroundTileMap"
		add_child(ground_tilemap)
		# Use the user's placeholder seamless single tile
		ground_tilemap.setup_single_tile_from_path("res://BespokeAssetSources/placeholder_floor/ground_stone1.png")
		# Determine tile size from the texture we loaded and compute grid size to cover 3000px
		var ts: Vector2i = ground_tilemap.tile_set.tile_size
		var tiles_x := int(ceil(3000.0 / float(max(ts.x, 1))))
		var tiles_y := int(ceil(3000.0 / float(max(ts.y, 1))))
		ground_tilemap.fill_grid(Vector2i(tiles_x, tiles_y), true)
	
	# Dark background (in case tilemap has gaps)
	var background = ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08)  # Very dark
	background.set_position(Vector2(-half_size, -half_size))
	background.set_deferred("size", Vector2(arena_size, arena_size))
	background.z_index = -20  # Behind tilemap
	background.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(background)
	
	# Add random light sources around the map
	_place_random_lights(arena_size)
	
	# Create arena walls
	_create_arena_walls(arena_size)
	
	# Create highly visible dark pits
	var pit_outlines = _create_dark_pits()
	
	# Create visible pillars
	var pillar_outlines = _create_visible_pillars()
	
	# Add obstacle outlines to navigation mesh
	for outline in pit_outlines:
		nav_poly.add_outline(outline)
	for outline in pillar_outlines:
		nav_poly.add_outline(outline)
	
	# Use new navigation baking method (Godot 4.4+)
	var source_geometry = NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_geometry, nav_region)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geometry)
	nav_region.navigation_polygon = nav_poly
	
	# Create player
	var player_scene = preload("res://entities/player/player.tscn")
	player = player_scene.instantiate()
	player.position = Vector2(150, 150)  # Start offset from center to avoid pillar
	add_child(player)
	
	# Connect player signals
	player.died.connect(_on_player_died)
	
	# Reset session for new game
	if TicketSpawnManager.instance:
		TicketSpawnManager.instance.reset_session()
	if MXPManager.instance:
		MXPManager.instance.reset_session()
	player.level_up.connect(_on_player_level_up)
	player.health_changed.connect(_on_player_health_changed)
	player.mana_changed.connect(_on_player_mana_changed)
	player.experience_gained.connect(_on_player_experience_gained)
	
	# Bosses are now spawned via voting system, not automatically

func _create_arena_walls(arena_size: float):
	var wall_thickness = 50.0
	var half_size = arena_size / 2.0
	
	# Wall positions: [position, size, name]
	var walls = [
		[Vector2(-half_size - wall_thickness/2.0, 0), Vector2(wall_thickness, arena_size + wall_thickness*2.0), "WestWall"],
		[Vector2(half_size + wall_thickness/2.0, 0), Vector2(wall_thickness, arena_size + wall_thickness*2.0), "EastWall"],
		[Vector2(0, -half_size - wall_thickness/2.0), Vector2(arena_size + wall_thickness*2.0, wall_thickness), "NorthWall"],
		[Vector2(0, half_size + wall_thickness/2.0), Vector2(arena_size + wall_thickness*2.0, wall_thickness), "SouthWall"]
	]
	
	for wall_data in walls:
		# Create static body for collision
		var wall_body = StaticBody2D.new()
		wall_body.name = wall_data[2]
		wall_body.position = wall_data[0]
		wall_body.collision_layer = 1
		wall_body.collision_mask = 0
		wall_body.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(wall_body)
		
		# Add collision shape
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = wall_data[1]
		collision.shape = shape
		wall_body.add_child(collision)
		
		# Visual representation
		var wall_visual = ColorRect.new()
		wall_visual.color = Color(0.4, 0.3, 0.2)  # Brown wall
		wall_visual.size = wall_data[1]
		wall_visual.position = -wall_data[1] / 2.0
		wall_visual.z_index = 10
		wall_body.add_child(wall_visual)

func _create_dark_pits() -> Array:
	# Store pit positions for spawn avoidance
	if not has_meta("dark_pits"):
		set_meta("dark_pits", [])
	
	# Create pits at strategic positions (spread out to avoid pillar overlap)
	var pit_positions = [
		# Corners (far from corner pillars)
		Vector2(-1200, -1200),
		Vector2(1200, -1200),
		Vector2(-1200, 1200),
		Vector2(1200, 1200),
		# Edge positions
		Vector2(0, -1400),
		Vector2(0, 1400),
		Vector2(-1400, 0),
		Vector2(1400, 0),
		# Mid positions (avoiding pillar locations)
		Vector2(-300, -900),
		Vector2(300, -900),
		Vector2(-300, 900),
		Vector2(300, 900)
	]
	
	var pit_list = []
	var nav_outlines = []
	
	for pos in pit_positions:
		var pit = _create_single_pit(pos, 80.0)  # Smaller pits for smaller map
		add_child(pit)
		pit_list.append({
			"position": pos,
			"radius": 80.0
		})
		
		# Create square navigation outline
		var outline = _create_square_outline(pos, 80.0 + 19.0)  # Add margin and keep inside outer bounds
		nav_outlines.append(outline)
	
	set_meta("dark_pits", pit_list)
	return nav_outlines

func _create_single_pit(pit_position: Vector2, radius: float) -> StaticBody2D:
	var pit = StaticBody2D.new()
	pit.position = pit_position
	pit.collision_layer = 1  # Same layer as walls/pillars
	pit.collision_mask = 0  # Doesn't need to detect anything
	pit.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Square collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(radius * 2.0, radius * 2.0)  # Convert radius to square size
	collision.shape = shape
	pit.add_child(collision)
	
	# SPOOKY PIT SPRITE - NEW VERSION!
	var pit_sprite = Sprite2D.new()
	pit_sprite.texture = load("res://BespokeAssetSources/pitsprite_new.png")
	# Scale sprite to match collision size exactly
	var target_size = radius * 2.0  # 160 for pit radius of 80
	if pit_sprite.texture:
		var texture_size = pit_sprite.texture.get_size().x
		var scale_factor = target_size / texture_size
		pit_sprite.scale = Vector2(scale_factor, scale_factor)
	pit_sprite.z_index = 20
	pit.add_child(pit_sprite)
	
	# Note: Flying entities will need special handling in their movement code
	
	return pit

func _create_circle_outline(center: Vector2, radius: float, segments: int = 16) -> PackedVector2Array:
	var points = PackedVector2Array()
	for i in range(segments):
		var angle = (i * TAU) / segments
		var point = center + Vector2(cos(angle), sin(angle)) * radius
		points.append(point)
	return points

func _create_square_outline(center: Vector2, half_size: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	# Create square points clockwise
	points.append(center + Vector2(-half_size, -half_size))  # Top-left
	points.append(center + Vector2(half_size, -half_size))   # Top-right
	points.append(center + Vector2(half_size, half_size))    # Bottom-right
	points.append(center + Vector2(-half_size, half_size))   # Bottom-left
	return points

func _create_visible_pillars() -> Array:
	# Store pillar positions
	if not has_meta("pillars"):
		set_meta("pillars", [])
	
	# Create pillars at strategic positions (reduced count for better navigation)
	var pillar_positions = [
		# Inner square formation
		Vector2(-600, -600),
		Vector2(600, -600),
		Vector2(-600, 600),
		Vector2(600, 600),
		# Center
		Vector2(0, 0),
		# Mid-edge positions (removed 4 pillars)
		Vector2(-900, -300),
		Vector2(900, 300),
		# Removed the additional strategic positions
	]
	
	var pillar_list = []
	var nav_outlines = []
	
	for pos in pillar_positions:
		var pillar = _create_single_pillar(pos, 120.0)  # Scaled down by 20% (was 150)
		add_child(pillar)
		pillar_list.append({
			"position": pos,
			"radius": 120.0
		})
		
		# Create square navigation outline
		var outline = _create_square_outline(pos, 120.0 + 19.0)  # Add margin and keep inside outer bounds
		nav_outlines.append(outline)
	
	set_meta("pillars", pillar_list)
	return nav_outlines

func _create_single_pillar(pillar_position: Vector2, radius: float) -> StaticBody2D:
	var pillar = StaticBody2D.new()
	pillar.position = pillar_position
	pillar.collision_layer = 1
	pillar.collision_mask = 0
	pillar.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Square collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(radius * 2.0, radius * 2.0)  # Convert radius to square size
	collision.shape = shape
	pillar.add_child(collision)
	
	# STONE PILLAR SPRITE - NEW VERSION!
	var pillar_sprite = Sprite2D.new()
	pillar_sprite.texture = load("res://BespokeAssetSources/pillar_sprite_new.png")
	# Scale sprite to match collision size exactly
	var target_size = radius * 2.0  # 300 for pillar radius of 150
	if pillar_sprite.texture:
		var texture_size = pillar_sprite.texture.get_size().x
		var scale_factor = target_size / texture_size
		pillar_sprite.scale = Vector2(scale_factor, scale_factor)
	pillar_sprite.z_index = 25
	pillar.add_child(pillar_sprite)
	
	# Add subtle pulse to show it's solid
	var pillar_tween = pillar.create_tween()
	pillar_tween.set_loops(-1)  # Infinite loops
	
	# Store tween reference for cleanup
	pillar.set_meta("tween", pillar_tween)
	
	# Kill tween when pillar is freed
	pillar.tree_exiting.connect(func(): 
		if pillar_tween and pillar_tween.is_valid():
			pillar_tween.kill()
	)
	
	pillar_tween.tween_property(pillar_sprite, "modulate", Color(1.2, 1.2, 1.2), 1.0)
	pillar_tween.tween_property(pillar_sprite, "modulate", Color(1, 1, 1), 1.0)
	
	return pillar

func _setup_ui():
	# Create UI layer
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS  # UI continues during pause
	add_child(ui_layer)
	
	# Chat display removed - no longer needed
	
	# Create action feed at top-right
	var ui_action_feed = preload("res://ui/action_feed.gd").new()
	ui_action_feed.name = "ActionFeed"
	ui_action_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ui_action_feed.position = Vector2(-410, 20)  # 10px from right edge (400 width + 10px margin)
	ui_action_feed.custom_minimum_size = Vector2(400, 250)  # Limited height to not overlap commands
	ui_layer.add_child(ui_action_feed)
	
	# Store reference for easy access
	set_meta("action_feed", ui_action_feed)
	
	# Create modular commands display at bottom-right
	var commands_display = preload("res://ui/modular_commands_display.gd").new()
	commands_display.name = "CommandsDisplay"
	commands_display.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	commands_display.position = Vector2(-450, -300)  # Moved up to prevent overflow
	commands_display.custom_minimum_size = Vector2(430, 180)  # Reduced height
	ui_layer.add_child(commands_display)
	
	# Add dash cooldown display
	_setup_dash_cooldown_ui(ui_layer)
	
	# Add boss vote UI
	var boss_vote_ui = preload("res://ui/boss_vote_ui.gd").new()
	boss_vote_ui.name = "BossVoteUI"
	ui_layer.add_child(boss_vote_ui)
	
	# Add MXP display at top left
	var mxp_display = preload("res://ui/mxp_display.gd").new()
	mxp_display.name = "MXPDisplay"
	mxp_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mxp_display.position = Vector2(20, 80)  # Below boss timer
	ui_layer.add_child(mxp_display)
	
	# Add Player HP display below MXP
	var hp_container = VBoxContainer.new()
	hp_container.name = "HPDisplay"
	hp_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp_container.position = Vector2(20, 170)  # Moved down 40px (was 130)
	ui_layer.add_child(hp_container)
	
	# HP Label
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.add_theme_font_size_override("font_size", 24)
	hp_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red color
	hp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	hp_label.add_theme_constant_override("outline_size", 2)
	hp_label.text = "HP: 0/0"
	hp_container.add_child(hp_label)
	
	# Add boss buff display
	var boss_buff_display = preload("res://ui/boss_buff_display.gd").new()
	boss_buff_display.name = "BossBuffDisplay"
	boss_buff_display.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_buff_display.position = Vector2(-150, 20)  # Top center
	ui_layer.add_child(boss_buff_display)
	
	# Add player stats display (top left) - Hidden since health is above player
	var player_stats = preload("res://ui/player_stats_display.tscn").instantiate()
	player_stats.name = "PlayerStatsDisplay"
	player_stats.position = Vector2(20, 20)
	player_stats.visible = false  # Hide since health bar is now above player
	ui_layer.add_child(player_stats)
	
	# Add boss timer display (moved to top left)
	var boss_timer = preload("res://ui/boss_timer_display.gd").new()
	boss_timer.name = "BossTimerDisplay"
	boss_timer.position = Vector2(20, 20)  # Top left position
	ui_layer.add_child(boss_timer)
	
	# Add death screen (hidden by default)
	var death_screen = preload("res://ui/death_screen.gd").new()
	death_screen.name = "DeathScreen"
	ui_layer.add_child(death_screen)
	
	# Add boon selection (hidden by default)
	var boon_selection = preload("res://ui/boon_selection.gd").new()
	boon_selection.name = "BoonSelection"
	boon_selection.process_mode = Node.PROCESS_MODE_WHEN_PAUSED  # Still works when paused
	ui_layer.add_child(boon_selection)
	boon_selection.boon_selected.connect(_on_boon_selected)
	
	# Debug UI removed for cleaner console
	
	# Add some test messages
	# Initial messages moved to action feed
	# Add some initial messages
	if ui_action_feed:
		ui_action_feed.add_message("Welcome to A.S.S!", Color.YELLOW)
		ui_action_feed.add_message("WASD to move, Mouse to aim!", Color.GREEN)
	
	# Create Monster Power Display (just a number, top center)
	var power_display = MonsterPowerDisplay.new()
	power_display.name = "MonsterPowerDisplay"
	power_display.set_anchors_preset(Control.PRESET_CENTER_TOP)
	power_display.anchor_left = 0.5
	power_display.anchor_right = 0.5
	power_display.anchor_top = 0.0
	power_display.anchor_bottom = 0.0
	power_display.offset_left = -50
	power_display.offset_right = 50
	power_display.offset_top = 60  # Moved down 40 pixels (was 20)
	power_display.offset_bottom = 100
	ui_layer.add_child(power_display)
	
	# Create entity counter
	var entity_counter = preload("res://ui/entity_counter.gd").new()
	entity_counter.name = "EntityCounter"
	ui_layer.add_child(entity_counter)
	
	# Create XP bar
	var xp_bar = preload("res://ui/xp_bar.tscn").instantiate()
	xp_bar.name = "XPBar"
	xp_bar.anchor_bottom = 1.0
	xp_bar.anchor_top = 1.0
	xp_bar.anchor_left = 0.5
	xp_bar.anchor_right = 0.5
	xp_bar.offset_left = -200
	xp_bar.offset_right = 200
	xp_bar.offset_top = -120
	xp_bar.offset_bottom = -90
	ui_layer.add_child(xp_bar)
	
	# Create action bar
	var action_bar = preload("res://ui/action_bar.gd").new()
	action_bar.name = "ActionBar"
	action_bar.anchor_left = 0.5
	action_bar.anchor_top = 1.0
	action_bar.anchor_right = 0.5
	action_bar.anchor_bottom = 1.0
	action_bar.offset_left = -284  # Half of action bar width (568px / 2.0)
	action_bar.offset_top = -80  # 16px from bottom + 64px height
	action_bar.offset_right = 284
	action_bar.offset_bottom = -16  # 16px from bottom
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	ui_layer.add_child(action_bar)
	
	# Connect action bar signals
	action_bar.slot_clicked.connect(_on_action_bar_slot_clicked)
	
	# Add pause menu (hidden by default)
	pause_menu = preload("res://ui/pause_menu.gd").new()
	pause_menu.name = "PauseMenu"
	ui_layer.add_child(pause_menu)
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
			# print("âœ… Connected to Twitch bot!")
			var feed = get_action_feed()
			if feed:
				feed.add_message("Twitch integration ready!", Color.GREEN)
		else:
			# print("âš ï¸ Twitch bot doesn't have chat_message_received signal!")
			pass
	else:
		# print("âš ï¸ Twitch bot not found! Chat integration disabled.")
		pass

func _handle_chat_message(username: String, message: String, color: Color = Color.WHITE):
	# If no color provided, generate one
	if color == Color.WHITE:
		color = _get_user_color(username)
	
	# Add to chat display
	# Chat messages no longer displayed - chat display removed
	
	# Re-emit the signal for other systems (like bosses)
	chat_message_received.emit(username, message, color)
	
	# Check for keywords that affect the game
	var msg_lower = message.to_lower()
	
	# Boss Vote Commands - Always process these first, even during pause or voting
	if msg_lower.begins_with("!vote"):
		_handle_vote_command(username, msg_lower)
		return
	
	# Check if commands are blocked (game is paused)
	if state_manager and state_manager.is_commands_blocked():
		# Don't process any game-affecting commands while paused
		return
	
	# MXP Commands - DISABLED FOR BIG PATCH
	# if MXPModifierManager.instance and msg_lower.begins_with("!"):
	# 	if MXPModifierManager.instance.process_command(username, message):
	# 		return
	
	# !join command - Join the monster spawning pool
	if msg_lower == "!join":
		if TicketSpawnManager.instance:
			TicketSpawnManager.instance.handle_join_command(username)
		return
	
	# Evolution Commands
	if msg_lower.begins_with("!evolve"):
		_handle_evolve_command(username, msg_lower)
		return
	
	# Check if boss voting is active
	if BossVoteManager.instance and BossVoteManager.instance.is_voting:
		# Don't process entity commands during boss vote
		return
	
	# Game integration examples:
	
	# Check for special usernames
	if username.to_lower() == "quin69":
		# Streamer bonus!
		if player and player.is_alive:
			player.heal(10)
			var feed = get_action_feed()
			if feed:
				feed.add_message("Streamer blessed the player! +10 HP", Color.GOLD)

	# Commands bound to ALL of chatter's entities (concurrent execution)
	if msg_lower.begins_with("!explode"):
		_execute_command_on_all_entities(username, "trigger_explode")
	if msg_lower.begins_with("!fart"):
		_execute_command_on_all_entities(username, "trigger_fart")
	if msg_lower.begins_with("!boost"):
		_execute_command_on_all_entities(username, "trigger_boost")
	
	# Emote reactions
	if "pog" in msg_lower or "poggers" in msg_lower:
		# Could trigger a visual effect here
		# print("ðŸ'¥ POG moment from %s!" % username)
		pass

func _execute_command_on_all_entities(username: String, method_name: String):
	if not TicketSpawnManager.instance:
		return
	
	var entities = TicketSpawnManager.instance.get_alive_entities_for_chatter(username)
	for entity in entities:
		if is_instance_valid(entity) and entity.has_method(method_name):
			entity.call(method_name)

func _get_user_color(username: String) -> Color:
	# Simple color generation based on username
	var hash_value = username.hash()
	
	# Generate hue from hash (0-360 degrees)
	var hue = float(hash_value % 360) / 360.0
	
	# Use HSV with good saturation and value for visibility
	return Color.from_hsv(hue, 0.7, 0.9)

var cursor_hotspot: Vector2 = Vector2(37.5, 41.0)  # Perfect position for rotated gauntlet



func _adjust_cursor_hotspot(adjustment: Vector2):
	cursor_hotspot += adjustment
	var cursor_texture = load("res://ui/gauntlet_cursor_small.png")
	if cursor_texture:
		Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, cursor_hotspot)
		# print("Cursor hotspot adjusted to: ", cursor_hotspot)
		
		# Update the display label
		if has_meta("hotspot_label"):
			var label = get_meta("hotspot_label")
			if is_instance_valid(label):
				label.text = "Hotspot: " + str(cursor_hotspot)

func _process(_delta):

	# Check for ESC key press
	if Input.is_action_just_pressed("ui_cancel"):
		_handle_pause_toggle()
	
	# Testing cheats
	if OS.is_debug_build() or true:  # Always enabled for testing
		# CTRL+1: Toggle god mode
		if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_1):
			if not get_meta("cheat_1_pressed", false):
				set_meta("cheat_1_pressed", true)
				_toggle_god_mode()
		elif get_meta("cheat_1_pressed", false):
			set_meta("cheat_1_pressed", false)
		
		# CTRL+2: Spawn XP orbs (spammable)
		if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_2):
			if not get_meta("cheat_2_pressed", false):
				set_meta("cheat_2_pressed", true)
				_spawn_xp_orbs_around_player()
		elif get_meta("cheat_2_pressed", false):
			set_meta("cheat_2_pressed", false)
		
		# ALT+1: Grant +1 MXP to all chatters (spammable)
		if Input.is_key_pressed(KEY_ALT) and Input.is_key_pressed(KEY_1):
			if not get_meta("cheat_alt1_pressed", false):
				set_meta("cheat_alt1_pressed", true)
				_grant_global_mxp(1)
		elif get_meta("cheat_alt1_pressed", false):
			set_meta("cheat_alt1_pressed", false)
		
		# ALT+2: Grant +500 max HP and heal to full (spammable)
		if Input.is_key_pressed(KEY_ALT) and Input.is_key_pressed(KEY_2):
			if not get_meta("cheat_alt2_pressed", false):
				set_meta("cheat_alt2_pressed", true)
				_grant_player_health_boost()
		elif get_meta("cheat_alt2_pressed", false):
			set_meta("cheat_alt2_pressed", false)
		
		# CTRL+4: Trigger boss vote
		if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_4):
			if not get_meta("cheat_4_pressed", false):
				set_meta("cheat_4_pressed", true)
				_trigger_boss_vote()
		elif get_meta("cheat_4_pressed", false):
			set_meta("cheat_4_pressed", false)
	
	if not state_manager.is_paused():
		game_time += _delta
		
		# Periodic cleanup every 5 seconds
		cleanup_timer += _delta
		if cleanup_timer >= 5.0:
			cleanup_timer = 0.0
			_cleanup_dead_references()
		
		# Update mana gem spawning
		mana_gem_spawn_timer += _delta
		if mana_gem_spawn_timer >= mana_gem_spawn_interval:
			# Limit total mana gems to prevent lag
			var gem_count = get_tree().get_nodes_in_group("mana_gems").size()
			if gem_count < 10:  # Max 10 gems at once
				_spawn_mana_gem()
			mana_gem_spawn_timer = 0.0
	
	# Update UI displays
	if player and is_instance_valid(player):
		# Update HP display
		var hp_label = get_node_or_null("UILayer/HPDisplay/HPLabel")
		if hp_label:
			hp_label.text = "HP: %d/%d" % [int(player.current_health), int(player.max_health)]
		
		# Debug UI updates removed

func _on_player_died(killer_name: String, death_cause: String):
	# print("ðŸ’€ Game Over!")
	
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

func _on_player_mana_changed(new_mana: float, max_mana: float):
	# Update mana display
	var player_stats = get_node_or_null("UILayer/PlayerStatsDisplay")
	if player_stats and player_stats.has_method("update_mana"):
		player_stats.update_mana(new_mana, max_mana)

func _on_action_bar_slot_clicked(_slot_index: int):
	# print("Action bar slot %d clicked!" % (slot_index + 1))
	# For now, slot 0 (sword) doesn't do anything special as it's always active
	pass

func _spawn_mana_gem():
	if not player or not is_instance_valid(player):
		return
	
	# Get a random safe spawn position anywhere in the arena
	var arena_size = 3000.0  # Match arena size
	var spawn_pos = _get_random_safe_arena_position(arena_size * 0.9)  # Stay within 90% of arena
	
	# Create mana gem
	var mana_gem = preload("res://entities/pickups/mana_gem.tscn").instantiate()
	# Add directly to the game controller scene
	mana_gem.process_mode = Node.PROCESS_MODE_PAUSABLE  # Should pause
	add_child(mana_gem)
	mana_gem.global_position = spawn_pos
	mana_gem.z_index = 10  # Make sure it's above everything
	# print("ðŸ’Ž Spawning mana gem at ", spawn_pos)

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
		feed.add_message("Available evolutions: !evolvesuccubus (10 MXP)", Color(0.8, 0.8, 0))
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
	# Don't allow manual pause if other pause reasons are active
	if state_manager.pause_flags & ~GameStateManager.PauseReason.MANUAL_PAUSE != 0:
		return
	
	# Toggle pause state
	state_manager.toggle_manual_pause()
	
	# Show/hide pause menu
	if state_manager.pause_flags & GameStateManager.PauseReason.MANUAL_PAUSE:
		pause_menu.show_menu()
	else:
		pause_menu.hide_menu()

func _on_resume_requested():
	state_manager.set_pause(GameStateManager.PauseReason.MANUAL_PAUSE, false)

func _on_restart_requested():
	# Clear all pause states
	state_manager.clear_all_pause_states()
	
	# Reload the current scene
	get_tree().reload_current_scene()

func _on_quit_requested():
	# Quit the game
	get_tree().quit()

func _setup_dash_cooldown_ui(_ui_layer: CanvasLayer):
	# Dash cooldown is now handled in the player scene
	# This function is kept for compatibility but does nothing
	pass

func _create_boss_health_ui(_boss_node: Node):
	# Legacy function - bosses now handle their own health bars via BossHealthBar component
	# Kept for compatibility with old boss spawn code
	pass

func spawn_zzran_boss(spawn_position: Vector2) -> Node:
	# print("🎯 spawn_zzran_boss called at position: ", spawn_position)
	
	# Create ZZran boss dynamically FIRST (before spawn effect)
	var zzran_script = preload("res://entities/enemies/zzran_boss.gd")
	var zzran = CharacterBody2D.new()
	zzran.set_script(zzran_script)
	zzran.name = "ZZranBoss"
	zzran.position = spawn_position
	zzran.collision_layer = 2  # Enemy layer
	zzran.collision_mask = 1   # Collide with player layer
	zzran.process_mode = Node.PROCESS_MODE_PAUSABLE
	zzran.visible = false  # Start invisible
	
	# Add sprite with proper naming for base entity to find
	var boss_sprite = Sprite2D.new()  # Use regular Sprite2D like other enemies
	boss_sprite.name = "Sprite"
	boss_sprite.texture = preload("res://BespokeAssetSources/zizidle.png")
	boss_sprite.scale = Vector2(0.75, 0.75)  # Boss-appropriate scale - increased by 50%
	zzran.add_child(boss_sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 30.0
	collision.shape = shape
	zzran.add_child(collision)
	
	# Add boss health UI
	_create_boss_health_ui(zzran)
	
	# Add to scene
	add_child(zzran)
	
	# NOW create spawn effect after boss is in scene
	var spawn_effect = preload("res://entities/effects/boss_spawn_effect.gd").new()
	spawn_effect.position = spawn_position
	spawn_effect.portal_color = Color(0.8, 0.2, 0.8)  # Purple for ZZran
	spawn_effect.particle_color = Color(1.0, 0.0, 1.0)  # Magenta energy
	spawn_effect.use_lightning = false  # ZZran uses portal energy instead
	spawn_effect.process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure it runs even if something pauses
	add_child(spawn_effect)
	# print("🎨 Created ZZran spawn effect at position: ", spawn_position)
	
	# Make boss appear after spawn effect
	spawn_effect.spawn_complete.connect(func():
		# print("🎬 ZZran spawn effect complete, showing fullscreen attack!")
		# Show fullscreen Ziz attack image
		_show_ziz_fullscreen_attack()
		
		# Delay boss appearance slightly for dramatic effect
		await get_tree().create_timer(0.3).timeout
		
		# Check if zzran is still valid before setting visible
		if is_instance_valid(zzran) and zzran != null:
			zzran.visible = true
			# print("🔮 ZZran boss visibility set to: ", zzran.visible)
			# Add a fade-in animation for ZZran
			zzran.modulate.a = 0.0
			var tween = create_tween()
			tween.tween_property(zzran, "modulate:a", 1.0, 0.5)
			# print("🔮 ZZran boss is now visible and fading in!")
		else:
			push_error("ZZran boss was freed before spawn effect completed!")
	)
	
	# Assign UNIQUE rarity to boss
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager:
		rarity_manager.assign_rarity_type(zzran, NPCRarity.Type.UNIQUE)
		# print("ðŸ‘‘ Assigned UNIQUE rarity to ZZran boss")
	
	# print("ðŸ”® ZZran boss spawned at ", spawn_position)
	return zzran

func spawn_thor_boss(spawn_position: Vector2) -> Node:
	# Create spawn effect first
	var spawn_effect = preload("res://entities/effects/boss_spawn_effect.gd").new()
	spawn_effect.position = spawn_position
	spawn_effect.portal_color = Color(0.2, 0.8, 1.0)  # Blue for THOR
	spawn_effect.particle_color = Color(1.0, 1.0, 0.2)  # Yellow lightning
	add_child(spawn_effect)
	
	# Create THOR boss dynamically
	var thor_script = preload("res://entities/enemies/thor_enemy.gd")
	var thor = CharacterBody2D.new()
	thor.name = "ThorBoss"
	thor.script = thor_script
	thor.position = spawn_position
	thor.z_index = 5
	thor.collision_layer = 2  # Enemy layer
	thor.collision_mask = 3   # Collide with walls and player
	thor.process_mode = Node.PROCESS_MODE_PAUSABLE
	thor.visible = false  # Start invisible
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20
	collision.shape = shape
	thor.add_child(collision)
	
	# Add sprite
	var thor_sprite = Sprite2D.new()
	thor_sprite.name = "Sprite"
	thor_sprite.texture = preload("res://entities/enemies/pirate_skull.png")
	thor_sprite.scale = Vector2(0.1, 0.1)
	thor.add_child(thor_sprite)
	
	add_child(thor)
	
	# Make boss appear after spawn effect
	spawn_effect.spawn_complete.connect(func():
		thor.visible = true
		# Add a scale-in animation
		thor.scale = Vector2(0.1, 0.1)
		var tween = create_tween()
		tween.tween_property(thor, "scale", Vector2(1, 1), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	)
	
	# Assign UNIQUE rarity to boss
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager:
		rarity_manager.assign_rarity_type(thor, NPCRarity.Type.UNIQUE)
		# print("ðŸ‘‘ Assigned UNIQUE rarity to THOR boss")
	
	# print("â˜ ï¸ THOR (Pirate) boss spawned at ", spawn_position)
	return thor

func spawn_mika_boss(spawn_position: Vector2) -> Node:
	# Create spawn effect first
	var spawn_effect = preload("res://entities/effects/boss_spawn_effect.gd").new()
	spawn_effect.position = spawn_position
	spawn_effect.portal_color = Color(1.0, 0.3, 0.1)  # Red/orange for Mika
	spawn_effect.particle_color = Color(1.0, 0.6, 0.0)  # Orange flames
	spawn_effect.use_portal = false  # Mika uses shockwave and lightning
	add_child(spawn_effect)
	
	# Create Mika boss dynamically
	var mika_script = preload("res://entities/enemies/mika_boss.gd")
	var mika = CharacterBody2D.new()
	mika.set_script(mika_script)
	mika.name = "MikaBoss"
	mika.position = spawn_position
	mika.collision_layer = 2  # Enemy layer
	mika.collision_mask = 1   # Collide with player layer
	mika.process_mode = Node.PROCESS_MODE_PAUSABLE
	mika.visible = false  # Start invisible
	
	# Add sprite with proper naming for base entity to find
	var mika_sprite = Sprite2D.new()  # Use regular Sprite2D
	mika_sprite.name = "Sprite"
	mika_sprite.texture = preload("res://BespokeAssetSources/mika.png")
	mika_sprite.scale = Vector2(0.12, 0.12)  # Much smaller scale for large source image
	mika.add_child(mika_sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 25.0  # Slightly smaller for swift boss
	collision.shape = shape
	mika.add_child(collision)
	
	# Add boss health UI
	_create_boss_health_ui(mika)
	
	# Add to scene
	add_child(mika)
	
	# Make boss appear after spawn effect
	spawn_effect.spawn_complete.connect(func():
		if is_instance_valid(mika) and mika != null:
			mika.visible = true
			# Add a quick dash-in animation for Mika
			mika.position = spawn_position + Vector2(100, 0)
			var tween = create_tween()
			tween.tween_property(mika, "position", spawn_position, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			push_error("Mika boss was freed before spawn effect completed!")
	)
	
	# Assign UNIQUE rarity to boss
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager:
		rarity_manager.assign_rarity_type(mika, NPCRarity.Type.UNIQUE)
		# print("ðŸ‘‘ Assigned UNIQUE rarity to Mika boss")
	
	# print("âš¡ Mika boss spawned at ", spawn_position)
	return mika

func spawn_forsen_boss(spawn_position: Vector2) -> Node:
	# Create spawn effect first
	var spawn_effect = preload("res://entities/effects/boss_spawn_effect.gd").new()
	spawn_effect.position = spawn_position
	spawn_effect.portal_color = Color(0.5, 0, 0.5)  # Purple for Forsen
	spawn_effect.particle_color = Color(0.8, 0, 0.8)  # Purple energy
	spawn_effect.use_portal = true  # Use portal effect
	spawn_effect.use_lightning = true  # Add some chaos
	add_child(spawn_effect)
	
	# Create Forsen boss dynamically
	var forsen_script = preload("res://entities/enemies/bosses/forsen_boss.gd")
	var forsen = CharacterBody2D.new()
	forsen.set_script(forsen_script)
	forsen.name = "ForsenBoss"
	forsen.collision_layer = 2  # Enemy layer
	forsen.collision_mask = 1   # Collide with player layer
	forsen.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	# Add sprite
	var sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.scale = Vector2(1.2, 1.2)
	forsen.add_child(sprite)
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape = CircleShape2D.new()
	shape.radius = 35.0
	collision.shape = shape
	forsen.add_child(collision)
	
	# Initially hide boss
	forsen.visible = false
	forsen.set_physics_process(false)
	forsen.set_process(false)
	
	# Create boss health UI (only one, like other bosses)
	_create_boss_health_ui(forsen)
	
	# Add to scene
	add_child(forsen)
	
	# Make boss appear after spawn effect
	spawn_effect.spawn_complete.connect(func():
		if is_instance_valid(forsen) and not forsen.is_queued_for_deletion():
			forsen.visible = true
			forsen.set_physics_process(true)
			forsen.set_process(true)
			# Spawn position animation
			forsen.position = spawn_position + Vector2(100, 0)
			var tween = create_tween()
			tween.tween_property(forsen, "position", spawn_position, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		else:
			push_error("Forsen boss was freed before spawn effect completed!")
	)
	
	# Assign UNIQUE rarity to boss
	var rarity_manager = NPCRarityManager.get_instance()
	if rarity_manager:
		rarity_manager.assign_rarity_type(forsen, NPCRarity.Type.UNIQUE)
	
	return forsen

func _trigger_boss_vote():
	if not BossVoteManager.instance:
		# print("âŒ BossVoteManager not found!")
		return
	
	# print("ðŸ—³ï¸ Triggering boss vote! (CHEAT)")
	
	# Force start the vote immediately
	BossVoteManager.instance._start_vote()
	
	# Feedback
	var vote_feed = get_action_feed()
	if vote_feed:
		vote_feed.add_message("ðŸ—³ï¸ Boss vote triggered! (CHEAT)", Color(1, 0.5, 0))

func _show_ziz_fullscreen_attack():
	# print("🖼️ _show_ziz_fullscreen_attack() called!")
	
	# Create fullscreen container
	var fullscreen = Control.new()
	fullscreen.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.z_index = 200  # Above everything
	fullscreen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fullscreen.process_mode = Node.PROCESS_MODE_ALWAYS  # Show even during pause
	
	# Add the epic Ziz attack image
	var attack_image = TextureRect.new()
	var texture_path = "res://BespokeAssetSources/ZizFullscreenAttack.jpg"
	if not ResourceLoader.exists(texture_path):
		push_error("ZizFullscreenAttack.jpg not found at: " + texture_path)
		return
	attack_image.texture = load(texture_path)
	attack_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	attack_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.add_child(attack_image)
	
	# print("🖼️ Fullscreen attack image loaded!")
	
	# Add flash overlay for extra impact
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	fullscreen.add_child(flash)
	
	# Add to UI layer instead of viewport to properly center on camera
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		ui_layer.add_child(fullscreen)
	else:
		push_warning("UILayer not found, adding fullscreen effect to viewport")
		var viewport = get_viewport()
		if viewport:
			viewport.add_child(fullscreen)
		else:
			push_error("Cannot add fullscreen effect - no viewport found!")
			fullscreen.queue_free()
			return
	
	# Epic animation sequence (all happens in < 1 second)
	fullscreen.scale = Vector2(1.5, 1.5)
	fullscreen.pivot_offset = get_viewport().size / 2.0
	fullscreen.modulate = Color(2, 2, 2, 0)  # Start bright and invisible
	
	var tween = fullscreen.create_tween()
	tween.set_parallel(true)
	
	# Zoom in + fade in (0.2s)
	tween.tween_property(fullscreen, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(fullscreen, "modulate:a", 1.0, 0.15)
	
	# Sequential effects
	tween.set_parallel(false)
	
	# White flash at peak (0.1s)
	tween.tween_property(flash, "color:a", 0.8, 0.05)
	tween.tween_property(flash, "color:a", 0.0, 0.05)
	
	# Hold for dramatic effect (0.3s)
	tween.tween_interval(0.3)
	
	# Zoom out + fade (0.2s)
	tween.set_parallel(true)
	tween.tween_property(fullscreen, "scale", Vector2(0.8, 0.8), 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(fullscreen, "modulate:a", 0.0, 0.2)
	
	# Cleanup
	tween.set_parallel(false)
	tween.tween_callback(fullscreen.queue_free)
	
	# Camera shake for extra impact
	if player and player.has_node("Camera2D"):
		var camera = player.get_node("Camera2D")
		_add_camera_shake(camera, 10.0, 0.5)

func _add_camera_shake(camera: Camera2D, strength: float, duration: float):
	if not camera:
		return
		
	var shake_tween = camera.create_tween()
	var original_offset = camera.offset
	var shake_count = int(duration * 60)  # 60 shakes per second
	
	for i in shake_count:
		var shake_offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		shake_tween.tween_property(camera, "offset", original_offset + shake_offset, 1.0 / 60.0)
		strength *= 0.95  # Decay the shake
	
	shake_tween.tween_property(camera, "offset", original_offset, 0.1)

func _place_random_lights(arena_size: float) -> void:
	# Place random environmental lights around the map
	var num_lights = 15  # Number of random lights
	var margin = 200.0  # Stay away from edges
	
	for i in range(num_lights):
		# Get random position
		var pos = Vector2(
			randf_range(-arena_size/2.0 + margin, arena_size/2.0 - margin),
			randf_range(-arena_size/2.0 + margin, arena_size/2.0 - margin)
		)
		
		# Skip if too close to obstacles
		if not _is_position_safe(pos):
			continue
		
		# Create a simple light source
		var light = PointLight2D.new()
		light.position = pos
		light.enabled = true
		light.energy = randf_range(0.6, 1.2)
		light.texture_scale = randf_range(1.5, 3.0)
		light.color = Color(
			randf_range(0.8, 1.0),  # Warm colors
			randf_range(0.7, 0.9),
			randf_range(0.5, 0.7),
			1.0
		)
		
		# Create gradient texture
		var gradient = Gradient.new()
		gradient.set_color(0, Color.WHITE)
		gradient.set_color(1, Color(1, 1, 1, 0))
		
		var gradient_texture = GradientTexture2D.new()
		gradient_texture.gradient = gradient
		gradient_texture.fill = GradientTexture2D.FILL_RADIAL
		gradient_texture.fill_from = Vector2(0.5, 0.5)
		gradient_texture.fill_to = Vector2(1.0, 0.5)
		gradient_texture.width = 256
		gradient_texture.height = 256
		
		light.texture = gradient_texture
		light.shadow_enabled = false  # No shadows for ambient lights
		light.z_index = -5  # Behind entities
		
		add_child(light)


func _grant_global_mxp(amount: int):
	if MXPManager.instance:
		MXPManager.instance.total_mxp_available += amount
		MXPManager.instance.mxp_granted.emit(amount)
		
		# Notify in chat
		var feed = get_action_feed()
		if feed:
			feed.add_message(" CHEAT: +%d MXP granted to all!" % amount, Color.YELLOW)
		
		# Notify in action feed
		var mxp_feed = get_action_feed()
		if mxp_feed:
			mxp_feed.add_message(" CHEAT: All chatters received +%d MXP!" % amount, Color(1, 1, 0))
		
		# print(" CHEAT: Granted +%d MXP to all chatters (Total: %d)" % [amount, MXPManager.instance.total_mxp_available])

func _grant_player_health_boost():
	if not player:
		return
	
	# Increase max health by 500
	player.max_health += 500
	
	# Heal to full
	player.current_health = player.max_health
	
	# Emit health changed signal to update UI
	player.health_changed.emit(player.current_health, player.max_health)
	
	# Notify in chat
	var feed = get_action_feed()
	if feed:
		feed.add_message("💪 CHEAT: +500 Max HP! Healed to full! (HP: %d)" % player.max_health, Color.GREEN)
	
	# Notify in action feed
	var health_feed = get_action_feed()
	if health_feed:
		health_feed.add_message("💪 CHEAT: Player gained +500 Max HP and full heal!", Color(0, 1, 0))
	
	# Visual feedback on player
	var player_sprite = player.get_node_or_null("SpriteContainer/Sprite")
	if player_sprite:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_BOUNCE)
		tween.tween_property(player_sprite, "scale", player_sprite.scale * 1.3, 0.2)
		tween.tween_property(player_sprite, "scale", player_sprite.scale, 0.2)
		
		# Green glow effect
		tween.parallel().tween_property(player_sprite, "modulate", Color(0.5, 1, 0.5), 0.2)
		tween.tween_property(player_sprite, "modulate", Color.WHITE, 0.3)
	
	# print("💪 CHEAT: Player health boosted! Current: %d / Max: %d" % [player.current_health, player.max_health])

## Handle Twitch channel change from pause menu
func _on_twitch_channel_changed(new_channel: String):
	print("🔄 GameController: Changing Twitch channel to %s" % new_channel)
	
	# Tell the Twitch bot to change channels
	if twitch_bot and twitch_bot.has_method("change_channel"):
		twitch_bot.change_channel(new_channel)
	else:
		print("❌ Failed to find Twitch bot or change_channel method")
	
	# Update action feed
	var feed = get_action_feed()
	if feed:
		feed.add_message("📺 Switched to %s's Twitch channel!" % new_channel, Color(0.8, 0.6, 1.0))
