extends Node
class_name UICoordinator

## Manages all UI setup, connections, and updates

signal ui_ready()

# UI References
var ui_layer: CanvasLayer
var action_feed: ActionFeed
var xp_bar: Node
var hp_display: Node
var pause_menu: PauseMenu
var boon_selection: Node
var commands_display: Node
var entity_counter: Node
var boss_vote_ui: Node
var monster_power_display: Node
var mxp_display: Node
var boss_timer_display: Node
var boon_selection_was_visible_during_pause: bool = false

# References (set by GameController)
var player: Player
var game_controller: Node2D

func setup_ui(parent: Node2D) -> CanvasLayer:
	# Create UI layer
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(ui_layer)
	
	# Setup all UI components
	_setup_action_feed()
	_setup_commands_display()
	_setup_xp_bar()
	_setup_hp_display()
	_setup_entity_counter()
	_setup_pause_menu()
	_setup_boon_selection()
	_setup_boss_vote_ui()
	_setup_monster_power_display()
	_setup_mxp_display()
	_setup_boss_timer_display()
	
	ui_ready.emit()
	return ui_layer

func _setup_action_feed():
	action_feed = preload("res://ui/action_feed.gd").new()
	action_feed.name = "ActionFeed"
	action_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	action_feed.position = Vector2(-410, 20)
	action_feed.custom_minimum_size = Vector2(400, 250)
	ui_layer.add_child(action_feed)

func _setup_commands_display():
	commands_display = preload("res://ui/modular_commands_display.gd").new()
	commands_display.name = "CommandsDisplay"
	commands_display.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	commands_display.position = Vector2(-310, -220)
	ui_layer.add_child(commands_display)

func _setup_xp_bar():
	var xp_bar_scene = preload("res://ui/xp_bar.tscn")
	xp_bar = xp_bar_scene.instantiate()
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

func _setup_hp_display():
	var hp_container = VBoxContainer.new()
	hp_container.name = "HPDisplay"
	hp_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hp_container.position = Vector2(20, 20)
	ui_layer.add_child(hp_container)
	
	var hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "HP: 0/0"
	hp_label.add_theme_font_size_override("font_size", 24)
	hp_label.add_theme_color_override("font_color", Color.WHITE)
	hp_container.add_child(hp_label)
	
	hp_display = hp_container

func _setup_entity_counter():
	entity_counter = preload("res://ui/entity_counter.gd").new()
	entity_counter.name = "EntityCounter"
	entity_counter.set_anchors_preset(Control.PRESET_TOP_LEFT)
	entity_counter.position = Vector2(20, 80)
	ui_layer.add_child(entity_counter)

func _setup_pause_menu():
	pause_menu = preload("res://ui/pause_menu.gd").new()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = false
	pause_menu.z_index = 2000  # Ensure it's above everything else
	ui_layer.add_child(pause_menu)

func _setup_boon_selection():
	boon_selection = preload("res://ui/boon_selection.gd").new()
	boon_selection.name = "BoonSelection"
	boon_selection.visible = false
	ui_layer.add_child(boon_selection)
	
	if boon_selection.has_signal("boon_selected"):
		boon_selection.boon_selected.connect(_on_boon_selected)

func _setup_boss_vote_ui():
	boss_vote_ui = preload("res://ui/boss_vote_ui.gd").new()
	boss_vote_ui.name = "BossVoteUI"
	boss_vote_ui.set_anchors_preset(Control.PRESET_TOP_LEFT)
	boss_vote_ui.position = Vector2(20, -100)
	ui_layer.add_child(boss_vote_ui)

func _setup_monster_power_display():
	monster_power_display = preload("res://ui/monster_power_display.gd").new()
	monster_power_display.name = "MonsterPowerDisplay"
	monster_power_display.set_anchors_preset(Control.PRESET_TOP_LEFT)
	monster_power_display.position = Vector2(20, 140)
	ui_layer.add_child(monster_power_display)

func _setup_mxp_display():
	mxp_display = preload("res://ui/mxp_display.gd").new()
	mxp_display.name = "MXPDisplay"
	mxp_display.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	mxp_display.position = Vector2(20, -100)
	ui_layer.add_child(mxp_display)

func _setup_boss_timer_display():
	boss_timer_display = preload("res://ui/boss_timer_display.gd").new()
	boss_timer_display.name = "BossTimerDisplay"
	boss_timer_display.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_timer_display.position = Vector2(-150, 20)
	ui_layer.add_child(boss_timer_display)

func connect_player_signals(p: Player):
	player = p
	if not player:
		return
	
	# Connect player signals to UI updates (check if already connected first)
	if not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
	if not player.experience_gained.is_connected(_on_player_experience_gained):
		player.experience_gained.connect(_on_player_experience_gained)
	if not player.level_up.is_connected(_on_player_level_up):
		player.level_up.connect(_on_player_level_up)
	
	# Initialize UI with player values
	update_hp_display(player.current_health, player.max_health)
	update_xp_display(player.experience, player.experience_to_next_level, player.level)

func _on_player_health_changed(current: float, maximum: float):
	update_hp_display(current, maximum)

func _on_player_experience_gained(_amount: int):
	if player:
		update_xp_display(player.experience, player.experience_to_next_level, player.level)

func _on_player_level_up(new_level: int):
	if action_feed:
		action_feed.player_leveled_up(new_level)
		action_feed.add_message("LEVEL UP! You are now level %d!" % new_level, Color.GOLD)
	
	if xp_bar and xp_bar.has_method("on_level_up"):
		xp_bar.on_level_up(new_level)
	
	if player:
		update_xp_display(player.experience, player.experience_to_next_level, player.level)
	
	# Show boon selection
	if boon_selection and GameStateManager.instance:
		GameStateManager.instance.set_pause(GameStateManager.PauseReason.LEVEL_UP_SELECTION, true)
		boon_selection.show_selection()

func _on_boon_selected(boon: BaseBoon):
	if not player or not game_controller:
		return
	
	var boon_manager = BoonManager.get_instance()
	if boon_manager:
		boon_manager.apply_boon(boon, player)
	
	if action_feed:
		var rarity_color = boon.get_display_color()
		action_feed.add_message("Boon acquired: [%s] %s" % [boon.rarity.display_name, boon.display_name], rarity_color)
	
	if GameStateManager.instance:
		GameStateManager.instance.set_pause(GameStateManager.PauseReason.LEVEL_UP_SELECTION, false)

func update_hp_display(current: float, maximum: float):
	if hp_display:
		var hp_label = hp_display.get_node_or_null("HPLabel")
		if hp_label:
			hp_label.text = "HP: %d/%d" % [int(current), int(maximum)]

func update_xp_display(current_xp: int, xp_to_next: int, level: int):
	if xp_bar and xp_bar.has_method("update_xp"):
		xp_bar.update_xp(current_xp, xp_to_next, level)

func show_pause_menu():
	if pause_menu:
		print("UICoordinator: Showing pause menu")
		pause_menu.show_menu()
		# While pause menu is visible, disable input on boon selection so it can't steal clicks
		if boon_selection and boon_selection.visible and boon_selection.has_method("set_input_enabled"):
			boon_selection.set_input_enabled(false)
		# Also hide boon selection visuals so it doesn't render above the pause menu
		if boon_selection and boon_selection.visible:
			boon_selection_was_visible_during_pause = true
			boon_selection.visible = false
	else:
		print("UICoordinator: ERROR - pause_menu is null!")

func hide_pause_menu():
	if pause_menu:
		print("UICoordinator: Hiding pause menu")
		pause_menu.hide_menu()
		# Restore boon selection visuals and re-enable input if it was visible before pause
		if boon_selection and boon_selection_was_visible_during_pause:
			boon_selection.visible = true
			if boon_selection.has_method("set_input_enabled"):
				boon_selection.set_input_enabled(true)
			boon_selection_was_visible_during_pause = false
	else:
		print("UICoordinator: ERROR - pause_menu is null!")

func get_action_feed() -> ActionFeed:
	return action_feed

func show_death_screen(killer_name: String, death_cause: String, killer_color: Color):
	var death_screen = ui_layer.get_node_or_null("DeathScreen")
	if death_screen:
		death_screen.show_death(killer_name, death_cause, killer_color)
	else:
		# Create new death screen if it doesn't exist
		var new_death_screen = preload("res://ui/death_screen.gd").new()
		new_death_screen.name = "DeathScreen"
		ui_layer.add_child(new_death_screen)
		new_death_screen.show_death(killer_name, death_cause, killer_color)
