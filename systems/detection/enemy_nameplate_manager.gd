extends CanvasLayer
class_name EnemyNameplateManager

## OPTIMIZED NAMEPLATE SYSTEM
## Only shows names for the nearest N enemies to prevent UI performance issues
## Uses object pooling for Label nodes to avoid constant creation/destruction

static var instance: EnemyNameplateManager

# Settings
const MAX_VISIBLE_NAMEPLATES: int = 20  # Only show nearest 20 rat names
const NAMEPLATE_DISTANCE: float = 300.0  # Max distance to show nameplates
const UPDATE_INTERVAL: float = 0.033  # Update nameplates ~30 times per second for smoother movement

# Nameplate pool
var nameplate_pool: Array[Label] = []
var active_nameplates: Dictionary = {}  # enemy_id -> Label
var nameplate_timer: float = 0.0

# Smoothing for nameplate positions
var nameplate_target_positions: Dictionary = {}  # enemy_id -> Vector2
var nameplate_current_positions: Dictionary = {}  # enemy_id -> Vector2

# Camera reference for screen positioning
var camera: Camera2D

func _ready():
	instance = self
	layer = 10  # Render above game content
	
	# Create nameplate pool
	_create_nameplate_pool()
	
	print("🏷️ Enemy Nameplate Manager initialized - max visible: %d" % MAX_VISIBLE_NAMEPLATES)

func _create_nameplate_pool():
	# Pre-create Label nodes for performance
	for i in range(MAX_VISIBLE_NAMEPLATES):
		var nameplate = _create_nameplate()
		nameplate.visible = false
		add_child(nameplate)
		nameplate_pool.append(nameplate)

func _create_nameplate() -> Label:
	var label = Label.new()
	
	# Style the nameplate
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 200  # Ensure above most UI within this CanvasLayer
	label.z_as_relative = false  # Use absolute z-index to avoid relative stacking flicker
	label.focus_mode = Control.FOCUS_NONE
	label.clip_contents = false
	
	# Add background for better readability
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	bg.content_margin_left = 4
	bg.content_margin_right = 4
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	label.add_theme_stylebox_override("normal", bg)
	
	return label

func _process(delta: float):
	nameplate_timer += delta
	if nameplate_timer >= UPDATE_INTERVAL:
		nameplate_timer = 0.0
		_update_nameplates()

func _update_nameplates():
	if not EnemyManager.instance:
		return
	
	# Get camera reference
	if not camera and GameController.instance and GameController.instance.player:
		camera = GameController.instance.player.get_node_or_null("Camera2D")
	
	if not camera:
		return
	
	# Use player's world position for correct distance calculations
	var player_pos = GameController.instance.player.global_position if GameController.instance and GameController.instance.player else Vector2.ZERO
	
	# Find nearest enemies for nameplates (rats only)
	var nearest_enemies = _get_nearest_enemies(player_pos)
	
	# Determine which IDs should be visible this frame
	var desired_ids: Dictionary = {}
	for e in nearest_enemies:
		desired_ids[e.id] = true
	
	# Hide nameplates that are no longer needed
	var currently_active_ids: Array = active_nameplates.keys()
	for enemy_id in currently_active_ids:
		if not desired_ids.has(enemy_id):
			var nameplate = active_nameplates[enemy_id] as Label
			nameplate.visible = false
			nameplate_pool.append(nameplate)
			active_nameplates.erase(enemy_id)
			nameplate_target_positions.erase(enemy_id)
			nameplate_current_positions.erase(enemy_id)
	
	# Show or update nameplates for desired enemies
	_show_nameplates_for_enemies(nearest_enemies)

func _get_nearest_enemies(player_world_pos: Vector2) -> Array:
	var enemy_manager = EnemyManager.instance
	# Top-K selection by squared distance without full sort
	var best: Array = []  # Array of dicts with key "d2"
	var worst_index: int = -1
	var worst_d2: float = -1.0
	var limit: int = MAX_VISIBLE_NAMEPLATES
	var max_radius2: float = NAMEPLATE_DISTANCE * NAMEPLATE_DISTANCE
	
	var array_size = min(enemy_manager.positions.size(), enemy_manager.alive_flags.size())
	for i in range(array_size):
		if enemy_manager.alive_flags[i] == 0:
			continue
		if int(enemy_manager.entity_types[i]) != 0:
			continue
		var enemy_pos: Vector2 = enemy_manager.positions[i]
		var d2: float = player_world_pos.distance_squared_to(enemy_pos)
		if d2 > max_radius2:
			continue
		var item = {
			"id": i,
			"d2": d2,
			"position": enemy_pos,
			"username": enemy_manager.chatter_usernames[i],
			"color": enemy_manager.chatter_colors[i],
			"scale": enemy_manager.scales[i]
		}
		if best.size() < limit:
			best.append(item)
			# track worst
			if item.d2 > worst_d2:
				worst_d2 = item.d2
				worst_index = best.size() - 1
		else:
			if d2 < worst_d2 and worst_index >= 0:
				best[worst_index] = item
				# recompute worst
				worst_d2 = -1.0
				worst_index = -1
				for j in range(best.size()):
					if best[j].d2 > worst_d2:
						worst_d2 = best[j].d2
						worst_index = j
	# Sort the selected few by distance for stable UI layering
	best.sort_custom(func(a, b): return a.d2 < b.d2)
	return best

func _hide_all_nameplates():
	# Return all active nameplates to pool
	for enemy_id in active_nameplates:
		var nameplate = active_nameplates[enemy_id] as Label
		nameplate.visible = false
		nameplate_pool.append(nameplate)
		
		# Clean up position tracking for hidden nameplates
		nameplate_target_positions.erase(enemy_id)
		nameplate_current_positions.erase(enemy_id)
	
	active_nameplates.clear()

func _show_nameplates_for_enemies(enemies: Array):
	for idx in range(enemies.size()):
		var enemy_data = enemies[idx]
		var enemy_id = enemy_data.id
		var enemy_pos = enemy_data.position as Vector2
		var username = enemy_data.username as String
		var color = enemy_data.color as Color
		var enemy_scale: float = float(enemy_data.scale)
		
		# Reuse existing nameplate if active; otherwise take from pool
		var nameplate: Label = active_nameplates.get(enemy_id, null)
		if nameplate == null:
			if nameplate_pool.is_empty():
				continue  # No more nameplates available
			nameplate = nameplate_pool.pop_back() as Label
			active_nameplates[enemy_id] = nameplate
			nameplate.visible = true
		
		# Configure nameplate (idempotent)
		nameplate.text = username
		nameplate.modulate = color
		# Stable draw order: nearer enemies slightly on top
		nameplate.z_index = 200 + (enemies.size() - idx)
		
		# Calculate target position above enemy
		var screen_pos = _world_to_screen_position(enemy_pos)
		# Position slightly above the rat head, accounting for mesh scale (base quad 32px)
		var base_height := 32.0
		var target_pos = screen_pos + Vector2(0, - (base_height * enemy_scale * 0.5 + 12.0))
		
		# Store target position for smooth interpolation
		nameplate_target_positions[enemy_id] = target_pos
		
		# Initialize current position if not set
		if not nameplate_current_positions.has(enemy_id):
			nameplate_current_positions[enemy_id] = target_pos
		
		# Smooth interpolation towards target
		var current_pos = nameplate_current_positions[enemy_id]
		var lerp_factor = min(get_process_delta_time() * 15.0, 1.0)  # Smooth following
		current_pos = current_pos.lerp(target_pos, lerp_factor)
		nameplate_current_positions[enemy_id] = current_pos
		
		# Apply smoothed position (pixel-snapped to avoid subpixel jitter)
		nameplate.position = Vector2(round(current_pos.x), round(current_pos.y))
		
		# Light clamping to screen bounds (less aggressive)
		_soft_clamp_nameplate_to_screen(nameplate)

func _world_to_screen_position(world_pos: Vector2) -> Vector2:
	if not camera:
		return Vector2.ZERO
	
	# Convert world position to screen position relative to current camera and zoom
	var viewport = get_viewport()
	if not viewport:
		return Vector2.ZERO
	var screen_center = viewport.get_visible_rect().size * 0.5
	return screen_center + (world_pos - camera.global_position) * camera.zoom

func _soft_clamp_nameplate_to_screen(nameplate: Label):
	# Softer clamping that doesn't cause jumpy behavior
	var viewport_size = get_viewport().get_visible_rect().size
	var margin = 10.0  # Keep some margin from screen edges
	
	# Only clamp if really necessary to prevent jarring jumps
	if nameplate.position.x < -50:
		nameplate.position.x = -50
	elif nameplate.position.x > viewport_size.x + 50:
		nameplate.position.x = viewport_size.x + 50
		
	if nameplate.position.y < -20:
		nameplate.position.y = -20
	elif nameplate.position.y > viewport_size.y + 20:
		nameplate.position.y = viewport_size.y + 20

# Public API
func set_max_visible_nameplates(count: int):
	if count == MAX_VISIBLE_NAMEPLATES:
		return
	
	# This would require rebuilding the pool - for now just warn
	print("⚠️ Changing max visible nameplates requires restart")

func set_nameplate_distance(_distance: float):
	# This would require changing the constant - for now just warn
	print("⚠️ Changing nameplate distance requires restart")

func enable_nameplates(enabled: bool):
	visible = enabled
	if not enabled:
		_hide_all_nameplates()

func get_stats() -> Dictionary:
	return {
		"active_nameplates": active_nameplates.size(),
		"available_pool": nameplate_pool.size(),
		"max_visible": MAX_VISIBLE_NAMEPLATES
	}

# Debug functions - CanvasLayer can't draw directly
func enable_debug_visualization(enabled: bool):
	# TODO: Could create a separate Control node for debug drawing if needed
	print("🔍 Nameplate debug visualization: %s" % ("enabled" if enabled else "disabled"))
