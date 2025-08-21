extends Node
class_name CameraShake

## Global Camera Shake Utility System
## 
## Provides standardized camera shake effects that can be used throughout the game.
## Automatically finds the player's camera and applies various shake effects.

static var instance: CameraShake

signal shake_started(duration: float, intensity: float)
signal shake_ended()

# Shake presets for different scenarios
const SHAKE_PRESETS = {
	"light": {"intensity": 2.0, "duration": 0.2},
	"medium": {"intensity": 5.0, "duration": 0.4},
	"heavy": {"intensity": 8.0, "duration": 0.6},
	"boss_spawn": {"intensity": 8.0, "duration": 0.4},
	"explosion": {"intensity": 12.0, "duration": 0.3},
	"damage": {"intensity": 3.0, "duration": 0.15}
}

# Currently active shakes (for layering multiple effects)
var active_shakes: Array[Dictionary] = []

func _ready():
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("📷 CameraShake utility initialized!")

## Apply shake effect with preset intensity
static func shake_preset(preset_name: String) -> bool:
	if not instance:
		push_warning("CameraShake instance not available")
		return false
		
	if not SHAKE_PRESETS.has(preset_name):
		push_error("Unknown camera shake preset: " + preset_name)
		return false
	
	var preset = SHAKE_PRESETS[preset_name]
	return instance.shake(preset.intensity, preset.duration)

## Apply shake effect with custom intensity and duration
static func shake_custom(intensity: float, duration: float) -> bool:
	if not instance:
		push_warning("CameraShake instance not available")
		return false
	
	return instance.shake(intensity, duration)

## Main shake method - finds player camera and applies shake
func shake(intensity: float, duration: float) -> bool:
	var camera = _find_player_camera()
	if not camera:
		print("⚠️ Could not find player camera for shake effect")
		return false
	
	print("📷 Applying camera shake: intensity=%.1f, duration=%.2fs" % [intensity, duration])
	_apply_shake_to_camera(camera, intensity, duration)
	shake_started.emit(duration, intensity)
	return true

## Find the player's Camera2D
func _find_player_camera() -> Camera2D:
	# Try multiple ways to find the player camera
	var game_scene = get_tree().current_scene
	if not game_scene:
		return null
	
	# Method 1: Direct path from game scene
	var player = game_scene.get_node_or_null("Player")
	if player and player.has_node("Camera2D"):
		return player.get_node("Camera2D")
	
	# Method 2: Search through groups
	var players = get_tree().get_nodes_in_group("player")
	for player_node in players:
		if player_node.has_node("Camera2D"):
			return player_node.get_node("Camera2D")
	
	# Method 3: Search all cameras and find the one attached to a player
	var cameras = get_tree().get_nodes_in_group("cameras")  # If cameras are grouped
	for camera in cameras:
		if camera is Camera2D and camera.get_parent().is_in_group("player"):
			return camera
	
	# Method 4: Get current camera from viewport
	var viewport = get_tree().current_scene.get_viewport()
	if viewport:
		var current_camera = viewport.get_camera_2d()
		if current_camera:
			return current_camera
	
	return null

## Apply shake effect to a specific camera
func _apply_shake_to_camera(camera: Camera2D, intensity: float, duration: float):
	if not camera:
		return
	
	# Create shake data
	var shake_data = {
		"camera": camera,
		"original_offset": camera.offset,
		"intensity": intensity,
		"duration": duration,
		"elapsed": 0.0,
		"timer": null
	}
	
	# Create timer for this shake
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60 FPS
	timer.one_shot = false
	shake_data.timer = timer
	
	# Connect timer to shake update
	timer.timeout.connect(func(): _update_shake(shake_data))
	
	# Add to active shakes and start
	active_shakes.append(shake_data)
	add_child(timer)
	timer.start()

## Update shake effect each frame
func _update_shake(shake_data: Dictionary):
	shake_data.elapsed += shake_data.timer.wait_time
	
	if shake_data.elapsed >= shake_data.duration:
		# Shake finished
		_end_shake(shake_data)
		return
	
	var camera: Camera2D = shake_data.camera
	if not is_instance_valid(camera):
		_end_shake(shake_data)
		return
	
	# Calculate shake with decay
	var shake_percent = 1.0 - (shake_data.elapsed / shake_data.duration)
	var current_intensity = shake_data.intensity * shake_percent
	
	# Apply shake offset
	var shake_offset = Vector2(
		randf_range(-current_intensity, current_intensity),
		randf_range(-current_intensity, current_intensity)
	)
	
	# Combine with base offset and any other active shakes
	var total_offset = _calculate_total_offset(camera, shake_data.original_offset, shake_offset)
	camera.offset = total_offset

## Calculate total offset from all active shakes
func _calculate_total_offset(camera: Camera2D, base_offset: Vector2, current_shake: Vector2) -> Vector2:
	# Start with base offset plus current shake
	var total = base_offset + current_shake
	
	# Add any other active shakes (but avoid double-counting the current one)
	for shake_data in active_shakes:
		if shake_data.camera == camera and shake_data.get("current_shake_offset"):
			total += shake_data.current_shake_offset
	
	return total

## End a specific shake effect
func _end_shake(shake_data: Dictionary):
	var camera: Camera2D = shake_data.camera
	var timer: Timer = shake_data.timer
	
	# Remove from active shakes
	active_shakes.erase(shake_data)
	
	# Stop and cleanup timer
	if timer and is_instance_valid(timer):
		timer.stop()
		timer.queue_free()
	
	# Reset camera offset if no other shakes are active for this camera
	if is_instance_valid(camera):
		var has_other_shakes = false
		for other_shake in active_shakes:
			if other_shake.camera == camera:
				has_other_shakes = true
				break
		
		if not has_other_shakes:
			camera.offset = shake_data.original_offset
			shake_ended.emit()

## Stop all active shakes immediately
static func stop_all_shakes():
	if not instance:
		return
	
	instance._stop_all_shakes_internal()

func _stop_all_shakes_internal():
	var cameras_to_reset = {}
	
	# Collect all cameras and their original offsets
	for shake_data in active_shakes:
		var camera = shake_data.camera
		if is_instance_valid(camera) and not cameras_to_reset.has(camera):
			cameras_to_reset[camera] = shake_data.original_offset
		
		# Clean up timer
		var timer = shake_data.timer
		if timer and is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	
	# Reset all camera offsets
	for camera in cameras_to_reset:
		camera.offset = cameras_to_reset[camera]
	
	# Clear active shakes
	active_shakes.clear()
	shake_ended.emit()

## Get info about active shakes (for debugging)
static func get_active_shake_count() -> int:
	if not instance:
		return 0
	return instance.active_shakes.size()

## Check if camera is currently shaking
static func is_shaking() -> bool:
	if not instance:
		return false
	return instance.active_shakes.size() > 0