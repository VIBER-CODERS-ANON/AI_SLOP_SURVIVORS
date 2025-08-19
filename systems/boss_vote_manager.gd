extends Node
class_name BossVoteManager

static var instance: BossVoteManager

signal vote_started(boss_options: Array)
signal vote_updated(votes: Dictionary)
signal vote_ended(winner_boss_id: String)
signal boss_spawned(boss_name: String)

const VOTE_INTERVAL: float = 120.0  # 2 minutes
const VOTE_DURATION: float = 20.0   # 20 seconds

# Boss registry - all available bosses
var boss_registry: Dictionary = {
	"thor": {
		"name": "THOR",
		"display_name": "⚡ THOR - God of Thunder",
		"description": "Mana-based lightning boss",
		"spawn_func": "_spawn_thor_boss",
		"icon_path": "res://entities/enemies/pirate_skull.png"
	},
	"zzran": {
		"name": "ZZran",
		"display_name": "🔮 ZZran - Energy Master",
		"description": "Teleporting energy boss",
		"spawn_func": "_spawn_zzran_boss",
		"icon_path": "res://BespokeAssetSources/zizidle.png"
	},
	"mika": {
		"name": "Mika",
		"display_name": "⚔️ Mika - Swift Striker",
		"description": "Fast and aggressive melee boss",
		"spawn_func": "_spawn_mika_boss",
		"icon_path": "res://BespokeAssetSources/mika.png"
	},
	"forsen": {
		"name": "Forsen",
		"display_name": "🎮 Forsen - The Meme Lord",
		"description": "Chat-interactive boss that transforms into HORSEN",
		"spawn_func": "_spawn_forsen_boss",
		"icon_path": "res://BespokeAssetSources/forsen/forsen.png"
	}
}

# State tracking
var spawned_bosses: Array = []  # Bosses already spawned this session
var vote_timer: float = 0.0
var voting_timer: float = 0.0
var is_voting: bool = false
var current_vote_options: Array = []
var current_votes: Dictionary = {}  # boss_id -> vote_count
var voter_tracker: Dictionary = {}  # username -> boss_id they voted for

# Reference to game controller
var game_controller: Node

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep running even when paused
	
	# Try to get game controller reference early
	game_controller = get_parent()  # Should be GameController since we're added as a child
	if game_controller:
		print("🗳️ Boss Vote Manager found parent GameController: ", game_controller.name)
	
	# Start the vote timer
	vote_timer = VOTE_INTERVAL
	
	print("🗳️ Boss Vote Manager initialized! First vote in %d seconds" % int(VOTE_INTERVAL))

func _process(_delta):
	# Check if game is paused
	if GameController.instance and GameController.instance.state_manager and GameController.instance.state_manager.is_paused():
		return  # Don't process timers when paused
		
	if not is_voting:
		# Count down to next vote
		vote_timer -= _delta
		if vote_timer <= 0:
			_start_vote()
	else:
		# Count down voting timer
		voting_timer -= _delta
		if voting_timer <= 0:
			_end_vote()

func _start_vote():
	# Get available bosses (not yet spawned)
	var available_bosses = []
	for boss_id in boss_registry:
		if boss_id not in spawned_bosses:
			available_bosses.append(boss_id)
	
	# If no bosses are available, cancel the vote
	if available_bosses.size() == 0:
		print("⚠️ All bosses have been spawned! No more boss votes.")
		# Show message to players
		var action_feed = _get_action_feed()
		if action_feed:
			action_feed.add_message("🏆 ALL BOSSES DEFEATED! You are the true survivor!", Color(1, 1, 0))
		# Stop future votes
		set_process(false)
		return
	
	# Select up to 3 random bosses (or however many are available)
	available_bosses.shuffle()
	current_vote_options = []
	for i in range(min(3, available_bosses.size())):
		current_vote_options.append(available_bosses[i])
	
	# Initialize vote counts
	current_votes.clear()
	voter_tracker.clear()
	for boss_id in current_vote_options:
		current_votes[boss_id] = 0
	
	# Start voting
	is_voting = true
	voting_timer = VOTE_DURATION
	
	# Pause the game
	get_tree().paused = true
	
	# Emit signal for UI
	vote_started.emit(current_vote_options)
	
	# Announce in chat
	var chat_feed = _get_action_feed()
	if chat_feed:
		chat_feed.add_message("🗳️ BOSS VOTE STARTED! Type !vote1, !vote2, or !vote3", Color(1, 0.8, 0))
		for i in range(current_vote_options.size()):
			var boss_data = boss_registry[current_vote_options[i]]
			chat_feed.add_message("  %d. %s" % [i + 1, boss_data.display_name], Color(0.8, 0.8, 1))

func _end_vote():
	is_voting = false
	
	# Find winner(s) - handle ties properly
	var winner_id = ""
	var max_votes = -1
	var tied_winners = []
	
	# Find the highest vote count and all bosses with that count
	for boss_id in current_votes:
		if current_votes[boss_id] > max_votes:
			max_votes = current_votes[boss_id]
			tied_winners = [boss_id]  # Reset tied list with new leader
		elif current_votes[boss_id] == max_votes and max_votes > 0:
			tied_winners.append(boss_id)  # Add to tie list
	
	# If no votes, pick random from all options
	if tied_winners.is_empty():
		winner_id = current_vote_options[randi() % current_vote_options.size()]
		print("🗳️ No votes received, randomly selecting boss")
	# If tie, pick random from tied winners
	elif tied_winners.size() > 1:
		winner_id = tied_winners[randi() % tied_winners.size()]
		print("🗳️ Tie detected between %d bosses with %d votes each, randomly selecting" % [tied_winners.size(), max_votes])
	else:
		winner_id = tied_winners[0]
	
	# Mark as spawned
	if winner_id not in spawned_bosses:
		spawned_bosses.append(winner_id)
	
	print("🗳️ Vote ended, winner: ", winner_id)
	
	# Emit signal
	vote_ended.emit(winner_id)
	
	# Announce winner
	var action_feed = _get_action_feed()
	if action_feed:
		var boss_data = boss_registry[winner_id]
		action_feed.add_message("🎉 VOTE ENDED! Winner: %s with %d votes!" % [boss_data.display_name, max_votes], Color(1, 1, 0))
	
	# Unpause the game first
	get_tree().paused = false
	
	# Spawn the boss (after a short delay)
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure timer runs even if paused
	var boss_to_spawn = winner_id  # Capture in local variable
	timer.timeout.connect(func(): 
		print("⏰ Boss spawn timer triggered for: ", boss_to_spawn)
		_spawn_winning_boss(boss_to_spawn)
		timer.queue_free()
	)
	add_child(timer)
	timer.start()
	print("⏰ Started boss spawn timer for: ", boss_to_spawn)
	
	# Reset vote timer
	vote_timer = VOTE_INTERVAL

func _spawn_winning_boss(boss_id: String):
	print("🎯 Attempting to spawn boss: ", boss_id)
	
	var boss_data = boss_registry.get(boss_id)
	if not boss_data:
		push_error("Invalid boss ID: " + boss_id)
		return
	
	# Get game controller
	if not game_controller:
		game_controller = get_node_or_null("/root/GameController")
		if not game_controller:
			# Try alternate path
			game_controller = get_tree().get_root().get_node_or_null("GameController")
		if not game_controller:
			# Try finding it in the scene
			var nodes = get_tree().get_nodes_in_group("game_controller")
			if nodes.size() > 0:
				game_controller = nodes[0]
	
	if not game_controller:
		push_error("Could not find GameController!")
		print("Scene tree root children: ")
		for child in get_tree().get_root().get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
		return
	else:
		print("✅ Found GameController: ", game_controller)
	
	# Get player position for spawn location
	var player = game_controller.get_node_or_null("Player")
	if not player:
		push_error("Could not find player!")
		return
	
	# Calculate spawn position (near player but not on top)
	var spawn_offset = Vector2(200, 0).rotated(randf() * TAU)
	var spawn_pos = player.global_position + spawn_offset
	
	print("🎯 Spawning ", boss_id, " at position: ", spawn_pos)
	
	# Call the appropriate spawn function
	match boss_id:
		"thor":
			if game_controller.has_method("spawn_thor_boss"):
				print("🎯 Calling spawn_thor_boss on GameController")
				game_controller.spawn_thor_boss(spawn_pos)
			else:
				push_error("GameController missing spawn_thor_boss method!")
				print("Available methods on GameController:")
				for method in game_controller.get_method_list():
					if method.name.contains("spawn") and method.name.contains("boss"):
						print("  - ", method.name)
		"zzran":
			if game_controller.has_method("spawn_zzran_boss"):
				print("🎯 Calling spawn_zzran_boss on GameController")
				game_controller.spawn_zzran_boss(spawn_pos)
			else:
				push_error("GameController missing spawn_zzran_boss method!")
				print("Available methods on GameController:")
				for method in game_controller.get_method_list():
					if method.name.contains("spawn") and method.name.contains("boss"):
						print("  - ", method.name)
		"mika":
			if game_controller.has_method("spawn_mika_boss"):
				print("🎯 Calling spawn_mika_boss on GameController")
				game_controller.spawn_mika_boss(spawn_pos)
			else:
				push_error("GameController missing spawn_mika_boss method!")
				print("Available methods on GameController:")
				for method in game_controller.get_method_list():
					if method.name.contains("spawn") and method.name.contains("boss"):
						print("  - ", method.name)
		"forsen":
			if game_controller.has_method("spawn_forsen_boss"):
				print("🎯 Calling spawn_forsen_boss on GameController")
				game_controller.spawn_forsen_boss(spawn_pos)
			else:
				push_error("GameController missing spawn_forsen_boss method!")
				print("Available methods on GameController:")
				for method in game_controller.get_method_list():
					if method.name.contains("spawn") and method.name.contains("boss"):
						print("  - ", method.name)
		_:
			push_error("Unknown boss ID: " + boss_id)
	
	# Emit signal
	boss_spawned.emit(boss_data.name)
	
	# Apply boss buff
	if BossBuffManager.instance:
		BossBuffManager.instance.apply_boss_buff(boss_id)
	
	# Dramatic announcement
	var action_feed = _get_action_feed()
	if action_feed:
		action_feed.add_message("⚔️ %s HAS ARRIVED!" % boss_data.display_name, Color(1, 0.2, 0.2))

func handle_vote_command(username: String, vote_number: int):
	if not is_voting:
		return false
	
	if vote_number < 1 or vote_number > current_vote_options.size():
		return false
	
	# Check if user already voted
	if username in voter_tracker:
		var old_vote = voter_tracker[username]
		current_votes[old_vote] -= 1
	
	# Record new vote
	var boss_id = current_vote_options[vote_number - 1]
	voter_tracker[username] = boss_id
	current_votes[boss_id] += 1
	
	# Emit update signal
	vote_updated.emit(current_votes)
	
	# Show vote in action feed
	var action_feed = _get_action_feed()
	if action_feed:
		var boss_data = boss_registry[boss_id]
		action_feed.add_message("🗳️ %s voted for %s" % [username, boss_data.name], Color(0.6, 0.8, 1))
	
	return true

func get_time_until_next_vote() -> float:
	if is_voting:
		return 0.0
	return vote_timer

func get_voting_time_remaining() -> float:
	if not is_voting:
		return 0.0
	return voting_timer

func _get_action_feed() -> Node:
	if not game_controller:
		game_controller = get_node_or_null("/root/GameController")
	
	if game_controller:
		return game_controller.get_node_or_null("UILayer/ActionFeed")
	
	return null
