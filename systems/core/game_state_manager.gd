extends Node
class_name GameStateManager

## Manages the game's pause states and command processing

# Singleton instance
static var instance: GameStateManager

# Pause states
enum PauseReason {
	NONE = 0,
	MANUAL_PAUSE = 1 << 0,      # Player pressed ESC
	LEVEL_UP_SELECTION = 1 << 1, # Level up UI is shown
	DEATH_SCREEN = 1 << 2,       # Death screen is shown
}

var pause_flags: int = PauseReason.NONE
var commands_blocked: bool = false

signal pause_state_changed(is_paused: bool)
signal commands_blocked_changed(is_blocked: bool)

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_paused() -> bool:
	return pause_flags != PauseReason.NONE

func is_commands_blocked() -> bool:
	return commands_blocked

func set_pause(reason: PauseReason, paused: bool):
	var was_paused = is_paused()
	
	if paused:
		pause_flags |= reason
	else:
		pause_flags &= ~reason
	
	var is_now_paused = is_paused()
	
	# Update actual pause state
	get_tree().paused = is_now_paused
	
	# Handle music pause/resume using ResourceManager API
	if was_paused != is_now_paused:
		if is_now_paused:
			ResourceManager.pause_music()
		else:
			ResourceManager.resume_music()
	
	# Commands are blocked when paused
	var was_blocked = commands_blocked
	commands_blocked = is_now_paused
	
	# Emit signals if state changed
	if was_paused != is_now_paused:
		pause_state_changed.emit(is_now_paused)
		print("🎮 Game %s" % ("PAUSED" if is_now_paused else "RESUMED"))
	
	if was_blocked != commands_blocked:
		commands_blocked_changed.emit(commands_blocked)
		if commands_blocked:
			print("🚫 Chat commands BLOCKED")
		else:
			print("✅ Chat commands ENABLED")

func toggle_manual_pause():
	set_pause(PauseReason.MANUAL_PAUSE, not (pause_flags & PauseReason.MANUAL_PAUSE))

func clear_all_pause_states():
	pause_flags = PauseReason.NONE
	get_tree().paused = false
	commands_blocked = false
	pause_state_changed.emit(false)
	commands_blocked_changed.emit(false)
