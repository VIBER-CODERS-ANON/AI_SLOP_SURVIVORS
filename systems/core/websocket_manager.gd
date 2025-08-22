extends Node

signal connection_status_changed(connected: bool)
signal error_occurred(message: String)

static var instance: WebSocketManager

@export_group("WebSocket")
@export var default_url: String = "ws://localhost:8080/ws"
@export var auto_enable: bool = false

var enabled: bool = false
var url: String = ""
var _ws: WebSocketPeer
var _connected: bool = false
var _send_queue: Array[String] = []
var _last_state: int = 0
var _last_connect_attempt: float = 0.0
const RECONNECT_INTERVAL := 3.0
var _last_game_controller_instance = null

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("🔌 WebSocketManager: Starting initialization...")
	
	# Load settings if available
	if SettingsManager.instance:
		enabled = SettingsManager.instance.get_websocket_enabled()
		url = SettingsManager.instance.get_websocket_url()
		print("🔌 WebSocketManager: Loaded from settings - enabled: %s, url: %s" % [enabled, url])
	else:
		enabled = auto_enable
		url = default_url
		print("🔌 WebSocketManager: Using defaults - enabled: %s, url: %s" % [enabled, url])
	
	# Connect to scene tree changes to detect reloads
	if not get_tree().is_connected("tree_changed", Callable(self, "_on_scene_tree_changed")):
		get_tree().tree_changed.connect(_on_scene_tree_changed)
	
	# Initialize GameController tracking
	_last_game_controller_instance = GameController.instance
	
	# Wait a bit for other systems to initialize, then try to connect and wire signals
	print("🔌 WebSocketManager: Waiting 2 seconds for other systems...")
	await get_tree().create_timer(2.0).timeout
	print("🔌 WebSocketManager: Wait complete, proceeding with initialization...")
	
	if enabled:
		print("🔌 WebSocketManager: Extension enabled, attempting connection...")
		_connect()
	else:
		print("🔌 WebSocketManager: Extension disabled, skipping connection")
	
	# Wire up signals from systems after boot
	print("🔌 WebSocketManager: Wiring signals...")
	call_deferred("_try_wire_signals")
	# Send session start event
	call_deferred("notify_session_start")

func _process(_delta: float) -> void:
	if not _ws:
		if enabled and (Time.get_ticks_msec() / 1000.0 - _last_connect_attempt) >= RECONNECT_INTERVAL:
			print("🔄 WebSocketManager: Reconnect interval reached, attempting reconnection...")
			_connect()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	
	# Log state changes
	if state != _last_state:
		var state_name = ""
		match state:
			WebSocketPeer.STATE_CONNECTING:
				state_name = "CONNECTING"
			WebSocketPeer.STATE_OPEN:
				state_name = "OPEN"
			WebSocketPeer.STATE_CLOSING:
				state_name = "CLOSING"
			WebSocketPeer.STATE_CLOSED:
				state_name = "CLOSED"
			_:
				state_name = "UNKNOWN(%d)" % state
		print("🔌 WebSocketManager: State changed from %d to %s" % [_last_state, state_name])
	
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				print("✅ WebSocketManager: Connection established!")
				_connected = true
				connection_status_changed.emit(true)
				_flush_queue()
			# This client is primarily outbound; ignore inbound packets for now
		WebSocketPeer.STATE_CLOSED:
			if _connected:
				print("❌ WebSocketManager: Connection lost!")
				_connected = false
				connection_status_changed.emit(false)
			_ws = null  # allow reconnect
		_:
			pass
	_last_state = state

func enable() -> void:
	enabled = true
	if SettingsManager.instance:
		SettingsManager.instance.set_websocket_enabled(true)
	_connect()
	# Re-wire signals in case they weren't connected before
	call_deferred("_try_wire_signals")

func disable() -> void:
	enabled = false
	if SettingsManager.instance:
		SettingsManager.instance.set_websocket_enabled(false)
	_disconnect()

func set_url(new_url: String) -> void:
	url = new_url
	if SettingsManager.instance:
		SettingsManager.instance.set_websocket_url(new_url)
	if enabled:
		_disconnect()
		_connect()

func _connect() -> void:
	if _ws:
		print("🔌 WebSocketManager: Already have WebSocket instance, skipping connect")
		return
	if url.is_empty():
		url = default_url
		print("🔌 WebSocketManager: URL was empty, using default: %s" % url)
	
	print("🔌 WebSocketManager: Creating WebSocket connection to: %s" % url)
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	_last_connect_attempt = Time.get_ticks_msec() / 1000.0
	
	if err != OK:
		print("❌ WebSocketManager: connect_to_url failed with code %d" % err)
		push_error("WebSocketManager: connect_to_url failed with code %d" % err)
		_ws = null
	else:
		print("✅ WebSocketManager: Connection attempt initiated successfully")

func _disconnect() -> void:
	if _ws:
		_ws.close()
		_ws = null
	if _connected:
		_connected = false
		connection_status_changed.emit(false)

func send_event(event_name: String, data: Dictionary = {}) -> void:
	var envelope := {
		"type": event_name,
		"timestamp": Time.get_unix_time_from_system(),
		"channel": SettingsManager.instance.get_twitch_channel() if SettingsManager.instance else "",
		"data": data
	}
	var txt := JSON.stringify(envelope)
	if _ws and _connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(txt)
	else:
		_send_queue.append(txt)

func _flush_queue() -> void:
	if not _ws or not _connected:
		return
	for msg in _send_queue:
		_ws.send_text(msg)
	_send_queue.clear()

func _try_wire_signals() -> void:
	print("🔗 WebSocketManager: Attempting to wire signals...")
	
	# Check manager availability
	print("🔗 WebSocketManager: Manager status:")
	print("  - TicketSpawnManager: %s" % ("✅" if TicketSpawnManager.instance else "❌"))
	print("  - EnemyManager: %s" % ("✅" if EnemyManager.instance else "❌"))
	print("  - MXPManager: %s" % ("✅" if MXPManager.instance else "❌"))
	print("  - BossVoteManager: %s" % ("✅" if BossVoteManager.instance else "❌"))
	print("  - GameController: %s" % ("✅" if GameController.instance else "❌"))
	
	# Ticket system: monster join and entity spawned
	if TicketSpawnManager.instance:
		if not TicketSpawnManager.instance.is_connected("chatter_joined", Callable(self, "_on_chatter_joined")):
			TicketSpawnManager.instance.chatter_joined.connect(_on_chatter_joined)
			print("🔗 WebSocketManager: Connected to TicketSpawnManager.chatter_joined")
		if not TicketSpawnManager.instance.is_connected("entity_spawned", Callable(self, "_on_entity_spawned")):
			TicketSpawnManager.instance.entity_spawned.connect(_on_entity_spawned)
			print("🔗 WebSocketManager: Connected to TicketSpawnManager.entity_spawned")
		if not TicketSpawnManager.instance.is_connected("monster_power_changed", Callable(self, "_on_monster_power_changed")):
			TicketSpawnManager.instance.monster_power_changed.connect(_on_monster_power_changed)
			print("🔗 WebSocketManager: Connected to TicketSpawnManager.monster_power_changed")
	
	# Enemy deaths
	if EnemyManager.instance and not EnemyManager.instance.is_connected("enemy_died", Callable(self, "_on_enemy_died")):
		EnemyManager.instance.enemy_died.connect(_on_enemy_died)
		print("🔗 WebSocketManager: Connected to EnemyManager.enemy_died")
	
	# MXP changes
	if MXPManager.instance:
		if not MXPManager.instance.is_connected("mxp_granted", Callable(self, "_on_mxp_granted")):
			MXPManager.instance.mxp_granted.connect(_on_mxp_granted)
			print("🔗 WebSocketManager: Connected to MXPManager.mxp_granted")
		if not MXPManager.instance.is_connected("mxp_spent", Callable(self, "_on_mxp_spent")):
			MXPManager.instance.mxp_spent.connect(_on_mxp_spent)
			print("🔗 WebSocketManager: Connected to MXPManager.mxp_spent")
	
	# Boss vote events
	if BossVoteManager.instance:
		if not BossVoteManager.instance.is_connected("vote_started", Callable(self, "_on_vote_started")):
			BossVoteManager.instance.vote_started.connect(_on_vote_started)
			print("🔗 WebSocketManager: Connected to BossVoteManager.vote_started")
		if not BossVoteManager.instance.is_connected("vote_updated", Callable(self, "_on_vote_updated")):
			BossVoteManager.instance.vote_updated.connect(_on_vote_updated)
			print("🔗 WebSocketManager: Connected to BossVoteManager.vote_updated")
		if not BossVoteManager.instance.is_connected("vote_ended", Callable(self, "_on_vote_ended")):
			BossVoteManager.instance.vote_ended.connect(_on_vote_ended)
			print("🔗 WebSocketManager: Connected to BossVoteManager.vote_ended")
		if not BossVoteManager.instance.is_connected("boss_spawned", Callable(self, "_on_boss_spawned")):
			BossVoteManager.instance.boss_spawned.connect(_on_boss_spawned)
			print("🔗 WebSocketManager: Connected to BossVoteManager.boss_spawned")
	
	# Player events (via GameController)
	if GameController.instance:
		if GameController.instance.player:
			var player = GameController.instance.player
			if not player.is_connected("level_up", Callable(self, "_on_player_level_up")):
				player.level_up.connect(_on_player_level_up)
				print("🔗 WebSocketManager: Connected to Player.level_up")
			if not player.is_connected("experience_gained", Callable(self, "_on_player_experience_gained")):
				player.experience_gained.connect(_on_player_experience_gained)
				print("🔗 WebSocketManager: Connected to Player.experience_gained")
			if not player.is_connected("health_changed", Callable(self, "_on_player_health_changed")):
				player.health_changed.connect(_on_player_health_changed)
				print("🔗 WebSocketManager: Connected to Player.health_changed")
			if not player.is_connected("died", Callable(self, "_on_player_died")):
				player.died.connect(_on_player_died)
				print("🔗 WebSocketManager: Connected to Player.died")
		else:
			print("🔗 WebSocketManager: GameController.player is null")
		
		# Connect to GameController pause menu signals for game state events
		if GameController.instance.pause_menu:
			var pause_menu = GameController.instance.pause_menu
			if not pause_menu.is_connected("resume_requested", Callable(self, "_on_game_resumed")):
				pause_menu.resume_requested.connect(_on_game_resumed)
				print("🔗 WebSocketManager: Connected to PauseMenu.resume_requested")
			if not pause_menu.is_connected("restart_requested", Callable(self, "_on_game_restart_requested")):
				pause_menu.restart_requested.connect(_on_game_restart_requested)
				print("🔗 WebSocketManager: Connected to PauseMenu.restart_requested")
		
		# Connect to GameStateManager for pause events
		if GameController.instance.state_manager:
			var state_manager = GameController.instance.state_manager
			if state_manager.has_signal("pause_state_changed") and not state_manager.is_connected("pause_state_changed", Callable(self, "_on_pause_state_changed")):
				state_manager.pause_state_changed.connect(_on_pause_state_changed)
				print("🔗 WebSocketManager: Connected to GameStateManager.pause_state_changed")
	
	# Connect to boss signals when they spawn
	_connect_to_existing_bosses()
	
	# Retry until all are ready
	if not TicketSpawnManager.instance or not EnemyManager.instance or not MXPManager.instance or not BossVoteManager.instance:
		print("🔗 WebSocketManager: Some managers not ready, retrying in 1 second...")
		await get_tree().create_timer(1.0).timeout
		call_deferred("_try_wire_signals")
	else:
		print("✅ WebSocketManager: All managers ready, signal wiring complete!")

func _on_chatter_joined(username: String) -> void:
	var monster_type := "twitch_rat"
	if TicketSpawnManager.instance and TicketSpawnManager.instance.joined_chatters.has(username):
		monster_type = str(TicketSpawnManager.instance.joined_chatters[username].get("monster_type", "twitch_rat"))
	send_event("monster_join", {
		"username": username,
		"monster_type": monster_type
	})

func _on_enemy_died(enemy_id: int, killer_name: String, death_cause: String) -> void:
	if not EnemyManager.instance:
		return
	var username := ""
	if enemy_id >= 0 and enemy_id < EnemyManager.instance.chatter_usernames.size():
		username = EnemyManager.instance.chatter_usernames[enemy_id]
	var type_str := "unknown"
	if enemy_id >= 0 and enemy_id < EnemyManager.instance.entity_types.size():
		type_str = EnemyManager.instance._get_type_name_string(int(EnemyManager.instance.entity_types[enemy_id]))
	send_event("monster_death", {
		"enemy_id": enemy_id,
		"username": username,
		"monster_type": type_str,
		"killer": killer_name,
		"cause": death_cause
	})

func _on_mxp_granted(amount: int) -> void:
	var total := MXPManager.instance.total_mxp_available if MXPManager.instance else 0
	send_event("mxp_granted", {
		"amount": amount,
		"total": total
	})

func _on_mxp_spent(username: String, amount: int, upgrade_type: String) -> void:
	var remaining := MXPManager.instance.get_available_mxp(username) if MXPManager.instance else 0
	send_event("mxp_spent", {
		"username": username,
		"amount": amount,
		"upgrade_type": upgrade_type,
		"remaining": remaining
	})

# Additional event handlers for comprehensive coverage

func _on_entity_spawned(enemy_id: int, username: String, monster_type: String) -> void:
	send_event("entity_spawned", {
		"enemy_id": enemy_id,
		"username": username,
		"monster_type": monster_type
	})

func _on_monster_power_changed(current_power: int, threshold: int) -> void:
	send_event("monster_power_changed", {
		"current_power": current_power,
		"threshold": threshold
	})

# Boss vote events
func _on_vote_started(boss_options: Array) -> void:
	var options_data = []
	for boss_id in boss_options:
		if BossVoteManager.instance and BossVoteManager.instance.boss_registry.has(boss_id):
			var boss_data = BossVoteManager.instance.boss_registry[boss_id]
			options_data.append({
				"id": boss_id,
				"name": boss_data.get("name", boss_id),
				"display_name": boss_data.get("display_name", boss_id),
				"description": boss_data.get("description", "")
			})
	
	send_event("vote_started", {
		"options": options_data,
		"duration": BossVoteManager.VOTE_DURATION if BossVoteManager.instance else 20.0
	})

func _on_vote_updated(votes: Dictionary) -> void:
	send_event("vote_updated", {
		"votes": votes
	})

func _on_vote_ended(winner_boss_id: String) -> void:
	var winner_data = {}
	if BossVoteManager.instance and BossVoteManager.instance.boss_registry.has(winner_boss_id):
		var boss_data = BossVoteManager.instance.boss_registry[winner_boss_id]
		winner_data = {
			"id": winner_boss_id,
			"name": boss_data.get("name", winner_boss_id),
			"display_name": boss_data.get("display_name", winner_boss_id)
		}
	
	send_event("vote_result", {
		"winner": winner_data
	})

func _on_boss_spawned(boss_name: String) -> void:
	send_event("boss_spawned", {
		"boss_name": boss_name,
		"timestamp": Time.get_unix_time_from_system()
	})

# Player events
func _on_player_level_up(new_level: int) -> void:
	send_event("player_level_up", {
		"level": new_level
	})

func _on_player_experience_gained(amount: int) -> void:
	send_event("player_experience_gained", {
		"amount": amount,
		"total_xp": GameController.instance.player.experience if GameController.instance and GameController.instance.player else 0
	})

var _last_health_update: float = 0.0
const HEALTH_UPDATE_RATE_LIMIT: float = 1.0  # Only send health updates once per second

func _on_player_health_changed(new_health: float, max_health: float) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _last_health_update >= HEALTH_UPDATE_RATE_LIMIT:
		_last_health_update = current_time
		send_event("player_health_changed", {
			"current_health": new_health,
			"max_health": max_health,
			"health_percentage": (new_health / max_health) * 100.0 if max_health > 0 else 0.0
		})

func _on_player_died(killer_name: String, death_cause: String) -> void:
	send_event("player_death", {
		"killer": killer_name,
		"cause": death_cause
	})

# Session events
func notify_session_start() -> void:
	send_event("session_start", {
		"timestamp": Time.get_unix_time_from_system(),
		"channel": SettingsManager.instance.get_twitch_channel() if SettingsManager.instance else ""
	})

func notify_session_end() -> void:
	send_event("session_end", {
		"timestamp": Time.get_unix_time_from_system()
	})

# Boss lifecycle events (to be called by boss entities when they die)
func notify_boss_killed(boss_name: String, killer_name: String) -> void:
	send_event("boss_killed", {
		"boss_name": boss_name,
		"killer": killer_name,
		"timestamp": Time.get_unix_time_from_system()
	})

# Evolution events (to be called by evolution system)
func notify_evolution(username: String, old_form: String, new_form: String, rarity_type: String = "") -> void:
	send_event("evolution", {
		"username": username,
		"old_form": old_form,
		"new_form": new_form,
		"rarity_type": rarity_type
	})

# Rarity events (to be called when rarity is assigned)
func notify_rarity_assigned(username: String, rarity_type: String) -> void:
	send_event("rarity_assigned", {
		"username": username,
		"rarity_type": rarity_type
	})

# Connect to existing bosses and listen for new ones
func _connect_to_existing_bosses() -> void:
	# Connect to all existing bosses
	var bosses = get_tree().get_nodes_in_group("bosses")
	for boss in bosses:
		_connect_to_boss(boss)
	
	# Listen for new bosses being added to the scene
	if not get_tree().is_connected("node_added", Callable(self, "_on_node_added")):
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	# Check if the new node is a boss
	if node is BaseBoss:
		_connect_to_boss(node)

func _connect_to_boss(boss: BaseBoss) -> void:
	if not boss:
		return
	
	# Connect to boss death signal
	if not boss.is_connected("boss_defeated", Callable(self, "_on_boss_defeated")):
		boss.boss_defeated.connect(_on_boss_defeated)
	
	# Connect to boss spawn signal (though this usually happens via BossVoteManager)
	if not boss.is_connected("boss_spawned", Callable(self, "_on_boss_spawned_direct")):
		boss.boss_spawned.connect(_on_boss_spawned_direct)

func _on_boss_defeated(boss_name: String) -> void:
	# Find who killed the boss (usually the player)
	var killer_name = "Player"
	if GameController.instance and GameController.instance.player:
		killer_name = "Player"  # Could be enhanced to track actual killer
	
	notify_boss_killed(boss_name, killer_name)

func _on_boss_spawned_direct(boss_name: String) -> void:
	# This handles direct boss spawns that don't go through BossVoteManager
	send_event("boss_spawned", {
		"boss_name": boss_name,
		"timestamp": Time.get_unix_time_from_system()
	})

# Game state events
func _on_game_resumed() -> void:
	send_event("game_resumed", {
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_game_restart_requested() -> void:
	# Send session end before restart
	notify_session_end()
	
	send_event("game_restart", {
		"timestamp": Time.get_unix_time_from_system()
	})

func _on_pause_state_changed(is_paused: bool) -> void:
	if is_paused:
		send_event("game_paused", {
			"timestamp": Time.get_unix_time_from_system()
		})
	else:
		send_event("game_resumed", {
			"timestamp": Time.get_unix_time_from_system()
		})

# Scene reload detection
func _on_scene_tree_changed() -> void:
	# Check if GameController instance has changed (indicating a scene reload)
	if GameController.instance != _last_game_controller_instance:
		print("🔄 WebSocketManager: Scene reload detected - GameController instance changed")
		_last_game_controller_instance = GameController.instance
		
		# Re-wire signals after a short delay to allow systems to initialize
		await get_tree().create_timer(1.0).timeout
		print("🔄 WebSocketManager: Re-wiring signals after scene reload...")
		_try_wire_signals()
		
		# Send new session start event
		call_deferred("notify_session_start")
