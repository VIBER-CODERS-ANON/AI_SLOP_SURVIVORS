extends Node
class_name WebSocketManager

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

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load settings if available
	if SettingsManager.instance:
		enabled = SettingsManager.instance.get_websocket_enabled()
		url = SettingsManager.instance.get_websocket_url()
	else:
		enabled = auto_enable
		url = default_url
	if enabled:
		_connect()
	# Wire up signals from systems after boot
	call_deferred("_try_wire_signals")

func _process(_delta: float) -> void:
	if not _ws:
		if enabled and (Time.get_ticks_msec() / 1000.0 - _last_connect_attempt) >= RECONNECT_INTERVAL:
			_connect()
		return
	_ws.poll()
	var state := _ws.get_ready_state()
	match state:
		WebSocketPeer.STATE_OPEN:
			if not _connected:
				_connected = true
				connection_status_changed.emit(true)
				_flush_queue()
			# This client is primarily outbound; ignore inbound packets for now
		WebSocketPeer.STATE_CLOSED:
			if _connected:
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
		return
	if url.is_empty():
		url = default_url
	_ws = WebSocketPeer.new()
	var err := _ws.connect_to_url(url)
	_last_connect_attempt = Time.get_ticks_msec() / 1000.0
	if err != OK:
		push_error("WebSocketManager: connect_to_url failed with code %d" % err)
		_ws = null

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
	# Ticket system: monster join
	if TicketSpawnManager.instance and not TicketSpawnManager.instance.is_connected("chatter_joined", Callable(self, "_on_chatter_joined")):
		TicketSpawnManager.instance.chatter_joined.connect(_on_chatter_joined)
	# Enemy deaths
	if EnemyManager.instance and not EnemyManager.instance.is_connected("enemy_died", Callable(self, "_on_enemy_died")):
		EnemyManager.instance.enemy_died.connect(_on_enemy_died)
	# MXP changes
	if MXPManager.instance:
		if not MXPManager.instance.is_connected("mxp_granted", Callable(self, "_on_mxp_granted")):
			MXPManager.instance.mxp_granted.connect(_on_mxp_granted)
		if not MXPManager.instance.is_connected("mxp_spent", Callable(self, "_on_mxp_spent")):
			MXPManager.instance.mxp_spent.connect(_on_mxp_spent)
	# Retry until all are ready
	if not TicketSpawnManager.instance or not EnemyManager.instance or not MXPManager.instance:
		await get_tree().create_timer(1.0).timeout
		call_deferred("_try_wire_signals")

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

func notify_player_death(killer_name: String, death_cause: String) -> void:
	send_event("player_death", {
		"killer": killer_name,
		"cause": death_cause
	})
