extends Node
class_name MXPManager

## Manages Monster XP (MXP) - a global currency that all chatters earn over time
## Resets each session, grants +1 MXP every 10 seconds to all chatters

signal mxp_granted(amount: int)
signal mxp_spent(username: String, amount: int, upgrade_type: String)

static var instance: MXPManager

# MXP Settings
const MXP_GRANT_INTERVAL: float = 10.0  # Grant MXP every 10 seconds
const MXP_PER_GRANT: int = 1

# Session tracking
var session_time: float = 0.0
var total_mxp_available: int = 0
var grant_timer: float = 0.0
var session_start_time: float = 0.0

# Chatter spending tracking (username -> spent_mxp)
var chatter_spent_mxp: Dictionary = {}

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_PAUSABLE  # Should pause with game
	session_start_time = Time.get_ticks_msec() / 1000.0
	print("💰 MXP Manager initialized - New session started!")

func _process(_delta):
	# Only process if game is not paused
	if get_tree().paused:
		return
		
	session_time += _delta
	grant_timer += _delta
	
	# Grant MXP at intervals
	if grant_timer >= MXP_GRANT_INTERVAL:
		grant_timer = 0.0
		_grant_mxp()

func _grant_mxp():
	total_mxp_available += MXP_PER_GRANT
	mxp_granted.emit(MXP_PER_GRANT)
	print("💰 MXP Granted! All chatters now have %d MXP available" % total_mxp_available)
	
	# Notify in action feed
	if GameController.instance:
		var action_feed = GameController.instance.get_action_feed()
		if action_feed:
			action_feed.add_message(
				"⬆️ +%d Monster XP! (Total: %d MXP)" % [MXP_PER_GRANT, total_mxp_available], 
				Color.GOLD
			)

## Get available MXP for a chatter
func get_available_mxp(username: String) -> int:
	var spent = chatter_spent_mxp.get(username, 0)
	return total_mxp_available - spent

## Check if chatter can afford an upgrade
func can_afford(username: String, cost: int) -> bool:
	return get_available_mxp(username) >= cost

## Spend MXP for a chatter
func spend_mxp(username: String, amount: int, upgrade_type: String) -> bool:
	if not can_afford(username, amount):
		return false
	
	# Track spending
	if not chatter_spent_mxp.has(username):
		chatter_spent_mxp[username] = 0
	chatter_spent_mxp[username] += amount
	
	mxp_spent.emit(username, amount, upgrade_type)
	print("💰 %s spent %d MXP on %s (Remaining: %d)" % [
		username, amount, upgrade_type, get_available_mxp(username)
	])
	
	return true

## Get session stats
func get_session_stats() -> Dictionary:
	return {
		"session_time": session_time,
		"total_mxp_granted": total_mxp_available,
		"chatters_participated": chatter_spent_mxp.size(),
		"total_mxp_spent": chatter_spent_mxp.values().reduce(func(a, b): return a + b, 0)
	}

## Reset for new session (called on game restart)
func reset_session():
	session_time = 0.0
	total_mxp_available = 0
	grant_timer = 0.0
	chatter_spent_mxp.clear()
	session_start_time = Time.get_ticks_msec() / 1000.0
	print("💰 MXP Manager reset - New session!")
