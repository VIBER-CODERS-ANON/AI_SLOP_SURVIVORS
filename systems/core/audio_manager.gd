extends Node
class_name AudioManager

## Manages audio playback with pooling to prevent channel exhaustion
## Singleton pattern for global access

static var instance: AudioManager

# Audio pools by bus type
var sfx_pool: Array[AudioStreamPlayer2D] = []
var dialog_pool: Array[AudioStreamPlayer2D] = []
var music_players: Dictionary = {}  # Track music players separately

# Pool settings
const SFX_POOL_SIZE = 32  # Maximum concurrent SFX
const DIALOG_POOL_SIZE = 8  # Maximum concurrent dialog
const CLEANUP_INTERVAL = 5.0  # Clean up finished sounds every 5 seconds

var cleanup_timer: float = 0.0

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Pre-create audio players for pooling
	_initialize_pools()
	
	print("🔊 Audio Manager initialized with %d SFX and %d Dialog channels" % [SFX_POOL_SIZE, DIALOG_POOL_SIZE])

func _initialize_pools():
	# Create SFX pool
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer2D.new()
		player.bus = "SFX"
		player.max_polyphony = 1  # Each player handles one sound
		add_child(player)
		sfx_pool.append(player)
	
	# Create Dialog pool
	for i in range(DIALOG_POOL_SIZE):
		var player = AudioStreamPlayer2D.new()
		player.bus = "Dialog"
		player.max_polyphony = 1
		add_child(player)
		dialog_pool.append(player)

func _process(_delta):
	cleanup_timer += _delta
	if cleanup_timer >= CLEANUP_INTERVAL:
		cleanup_timer = 0.0
		_cleanup_finished_sounds()

func _cleanup_finished_sounds():
	# Clean up any orphaned music players
	for key in music_players.keys():
		var player = music_players[key]
		if not is_instance_valid(player) or not player.playing:
			music_players.erase(key)

## Play a sound effect at a position
func play_sfx(stream: AudioStream, position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer2D:
	var player = _get_available_player(sfx_pool)
	if not player:
		print("⚠️ No available SFX channels! Consider reducing concurrent sounds.")
		return null
	
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	
	return player

## Play a sound effect attached to a node
func play_sfx_on_node(stream: AudioStream, parent_node: Node2D, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer2D:
	var player = play_sfx(stream, parent_node.global_position, volume_db, pitch_scale)
	if player:
		# Make the player follow the parent node
		_attach_player_to_node(player, parent_node)
	return player

## Play a sound effect at a specific position (alias for play_sfx for clarity)
func play_sfx_at_position(stream: AudioStream, position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer2D:
	return play_sfx(stream, position, volume_db, pitch_scale)

## Play dialog/voice line
func play_dialog(stream: AudioStream, position: Vector2, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer2D:
	var player = _get_available_player(dialog_pool)
	if not player:
		print("⚠️ No available Dialog channels!")
		return null
	
	player.stream = stream
	player.global_position = position
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	
	return player

## Play dialog attached to a node
func play_dialog_on_node(stream: AudioStream, parent_node: Node2D, volume_db: float = 0.0, pitch_scale: float = 1.0) -> AudioStreamPlayer2D:
	var player = play_dialog(stream, parent_node.global_position, volume_db, pitch_scale)
	if player:
		_attach_player_to_node(player, parent_node)
	return player

## Play music (not pooled, as we typically have few music tracks)
func play_music(stream: AudioStream, key: String, volume_db: float = 0.0, loop: bool = true) -> AudioStreamPlayer:
	# Stop existing music with this key
	if music_players.has(key):
		var old_player = music_players[key]
		if is_instance_valid(old_player):
			old_player.stop()
			old_player.queue_free()
	
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "Music"
	
	if stream is AudioStreamMP3:
		stream.loop = loop
	
	add_child(player)
	player.play()
	music_players[key] = player
	
	return player

## Stop music by key
func stop_music(key: String):
	if music_players.has(key):
		var player = music_players[key]
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
		music_players.erase(key)

## Get an available player from a pool
func _get_available_player(pool: Array) -> AudioStreamPlayer2D:
	for player in pool:
		if not player.playing:
			# Reset any attachments
			if player.has_meta("attached_to"):
				player.remove_meta("attached_to")
			return player
	
	# If no free player, try to find one that's almost done
	var oldest_player: AudioStreamPlayer2D = null
	var oldest_time: float = 0.0
	
	for player in pool:
		if player.stream:
			var play_pos = player.get_playback_position()
			if play_pos > oldest_time:
				oldest_time = play_pos
				oldest_player = player
	
	# Force stop the oldest sound if we really need a channel
	if oldest_player:
		oldest_player.stop()
		if oldest_player.has_meta("attached_to"):
			oldest_player.remove_meta("attached_to")
		return oldest_player
	
	return null

## Attach a player to follow a node
func _attach_player_to_node(player: AudioStreamPlayer2D, parent_node: Node2D):
	player.set_meta("attached_to", parent_node)
	# Connect to the player's tree_exiting signal to update position
	if not player.is_connected("tree_exiting", _on_player_finished):
		player.tree_exiting.connect(_on_player_finished.bind(player))

func _on_player_finished(player: AudioStreamPlayer2D):
	if player.has_meta("attached_to"):
		player.remove_meta("attached_to")

## Update positions of attached players (call from _physics_process)
func update_attached_positions():
	for player in sfx_pool + dialog_pool:
		if player.playing and player.has_meta("attached_to"):
			var parent = player.get_meta("attached_to")
			if is_instance_valid(parent):
				player.global_position = parent.global_position
			else:
				player.remove_meta("attached_to")

func _physics_process(_delta):
	update_attached_positions()

	