extends Node
class_name WorldSetupManager

## Handles all world creation, arena setup, obstacles, and lighting

signal world_setup_complete()

# Arena configuration
const ARENA_SIZE: float = 3000.0
const WALL_THICKNESS: float = 50.0

# Obstacle configuration
const PIT_RADIUS: float = 80.0
const PIT_NAV_MARGIN: float = 19.0
const PILLAR_RADIUS: float = 120.0
const PILLAR_NAV_MARGIN: float = 19.0

# Spawn zone configuration
var spawn_radius: float = 200.0
var rat_spawn_radius: float = 600.0

# Stored obstacle positions for spawn avoidance
var pits_data: Array = []
var pillars_data: Array = []

func setup_world(parent: Node2D) -> NavigationRegion2D:
	var half_size = ARENA_SIZE / 2.0
	
	# Create navigation region first
	var nav_region = NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	parent.add_child(nav_region)
	
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
	
	# Setup ground tilemap
	_setup_ground_tilemap(parent)
	
	# Setup background
	_setup_background(parent, ARENA_SIZE)
	
	# Create arena walls
	_create_arena_walls(parent, ARENA_SIZE)
	
	# Create obstacles and get their navigation outlines (before lights so lights can avoid them)
	var pit_outlines = _create_dark_pits(parent)
	var pillar_outlines = _create_visible_pillars(parent)
	
	# Add random light sources (after obstacles so they can avoid them)
	_place_random_lights(parent, ARENA_SIZE)
	
	# Add obstacle outlines to navigation mesh
	for outline in pit_outlines:
		nav_poly.add_outline(outline)
	for outline in pillar_outlines:
		nav_poly.add_outline(outline)
	
	# Bake navigation mesh
	var source_geometry = NavigationMeshSourceGeometryData2D.new()
	NavigationServer2D.parse_source_geometry_data(nav_poly, source_geometry, nav_region)
	NavigationServer2D.bake_from_source_geometry_data(nav_poly, source_geometry)
	nav_region.navigation_polygon = nav_poly
	
	world_setup_complete.emit()
	return nav_region

func _setup_ground_tilemap(parent: Node2D):
	if parent.get_node_or_null("GroundTileMap") == null:
		var ground_tilemap = preload("res://systems/tilemap_system/ground_tilemap.gd").new()
		ground_tilemap.name = "GroundTileMap"
		parent.add_child(ground_tilemap)
		ground_tilemap.setup_single_tile_from_path("res://BespokeAssetSources/placeholder_floor/ground_stone1.png")
		
		var ts: Vector2i = ground_tilemap.tile_set.tile_size
		var tiles_x := int(ceil(ARENA_SIZE / float(max(ts.x, 1))))
		var tiles_y := int(ceil(ARENA_SIZE / float(max(ts.y, 1))))
		ground_tilemap.fill_grid(Vector2i(tiles_x, tiles_y), true)

func _setup_background(parent: Node2D, arena_size: float):
	var half_size = arena_size / 2.0
	var background = ColorRect.new()
	background.color = Color(0.05, 0.05, 0.08)
	background.set_position(Vector2(-half_size, -half_size))
	background.set_deferred("size", Vector2(arena_size, arena_size))
	background.z_index = -20
	background.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(background)

func _place_random_lights(parent: Node2D, arena_size: float):
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
		
		parent.add_child(light)

func _create_arena_walls(parent: Node2D, arena_size: float):
	var half_size = arena_size / 2.0
	
	var walls = [
		[Vector2(-half_size - WALL_THICKNESS/2.0, 0), Vector2(WALL_THICKNESS, arena_size + WALL_THICKNESS*2.0), "WestWall"],
		[Vector2(half_size + WALL_THICKNESS/2.0, 0), Vector2(WALL_THICKNESS, arena_size + WALL_THICKNESS*2.0), "EastWall"],
		[Vector2(0, -half_size - WALL_THICKNESS/2.0), Vector2(arena_size + WALL_THICKNESS*2.0, WALL_THICKNESS), "NorthWall"],
		[Vector2(0, half_size + WALL_THICKNESS/2.0), Vector2(arena_size + WALL_THICKNESS*2.0, WALL_THICKNESS), "SouthWall"]
	]
	
	for wall_data in walls:
		var wall_body = StaticBody2D.new()
		wall_body.name = wall_data[2]
		wall_body.position = wall_data[0]
		wall_body.collision_layer = 1
		wall_body.collision_mask = 0
		wall_body.process_mode = Node.PROCESS_MODE_PAUSABLE
		parent.add_child(wall_body)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = wall_data[1]
		collision.shape = shape
		wall_body.add_child(collision)
		
		var wall_visual = ColorRect.new()
		wall_visual.color = Color(0.4, 0.3, 0.2)
		wall_visual.size = wall_data[1]
		wall_visual.position = -wall_data[1] / 2.0
		wall_visual.z_index = 10
		wall_body.add_child(wall_visual)

func _create_dark_pits(parent: Node2D) -> Array:
	var pit_positions = [
		Vector2(-1200, -1200),
		Vector2(1200, -1200),
		Vector2(-1200, 1200),
		Vector2(1200, 1200),
		Vector2(0, -1400),
		Vector2(0, 1400),
		Vector2(-1400, 0),
		Vector2(1400, 0),
		Vector2(-300, -900),
		Vector2(300, -900),
		Vector2(-300, 900),
		Vector2(300, 900)
	]
	
	var nav_outlines = []
	pits_data.clear()
	
	for pos in pit_positions:
		var pit = _create_single_pit(pos)
		parent.add_child(pit)
		pits_data.append({
			"position": pos,
			"radius": PIT_RADIUS
		})
		
		var outline = _create_square_outline(pos, PIT_RADIUS + PIT_NAV_MARGIN)
		nav_outlines.append(outline)
	
	return nav_outlines

func _create_single_pit(pit_position: Vector2) -> StaticBody2D:
	var pit = StaticBody2D.new()
	pit.position = pit_position
	pit.collision_layer = 1
	pit.collision_mask = 0
	pit.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(PIT_RADIUS * 2.0, PIT_RADIUS * 2.0)
	collision.shape = shape
	pit.add_child(collision)
	
	var pit_sprite = Sprite2D.new()
	pit_sprite.texture = load("res://BespokeAssetSources/pitsprite_new.png")
	var target_size = PIT_RADIUS * 2.0
	if pit_sprite.texture:
		var texture_size = pit_sprite.texture.get_size().x
		var scale_factor = target_size / texture_size
		pit_sprite.scale = Vector2(scale_factor, scale_factor)
	pit_sprite.z_index = 20
	pit.add_child(pit_sprite)
	
	return pit

func _create_visible_pillars(parent: Node2D) -> Array:
	var pillar_positions = [
		Vector2(-600, -600),
		Vector2(600, -600),
		Vector2(-600, 600),
		Vector2(600, 600),
		Vector2(0, 0),
		Vector2(-900, -300),
		Vector2(900, 300),
	]
	
	var nav_outlines = []
	pillars_data.clear()
	
	for pos in pillar_positions:
		var pillar = _create_single_pillar(pos)
		parent.add_child(pillar)
		pillars_data.append({
			"position": pos,
			"radius": PILLAR_RADIUS
		})
		
		var outline = _create_square_outline(pos, PILLAR_RADIUS + PILLAR_NAV_MARGIN)
		nav_outlines.append(outline)
	
	return nav_outlines

func _create_single_pillar(pillar_position: Vector2) -> StaticBody2D:
	var pillar = StaticBody2D.new()
	pillar.position = pillar_position
	pillar.collision_layer = 1
	pillar.collision_mask = 0
	pillar.process_mode = Node.PROCESS_MODE_PAUSABLE
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(PILLAR_RADIUS * 2.0, PILLAR_RADIUS * 2.0)
	collision.shape = shape
	pillar.add_child(collision)
	
	var pillar_sprite = Sprite2D.new()
	pillar_sprite.texture = load("res://BespokeAssetSources/pillar_sprite_new.png")
	var target_size = PILLAR_RADIUS * 2.0
	if pillar_sprite.texture:
		var texture_size = pillar_sprite.texture.get_size().x
		var scale_factor = target_size / texture_size
		pillar_sprite.scale = Vector2(scale_factor, scale_factor)
	pillar_sprite.z_index = 25
	pillar.add_child(pillar_sprite)
	
	# Add subtle pulse animation
	var pillar_tween = pillar.create_tween()
	pillar_tween.set_loops(-1)
	pillar.set_meta("tween", pillar_tween)
	
	pillar.tree_exiting.connect(func(): 
		if pillar_tween and pillar_tween.is_valid():
			pillar_tween.kill()
	)
	
	pillar_tween.tween_property(pillar_sprite, "modulate", Color(1.2, 1.2, 1.2), 1.0)
	pillar_tween.tween_property(pillar_sprite, "modulate", Color(1, 1, 1), 1.0)
	
	return pillar

func _create_square_outline(center: Vector2, half_size: float) -> PackedVector2Array:
	var points = PackedVector2Array()
	points.append(center + Vector2(-half_size, -half_size))
	points.append(center + Vector2(half_size, -half_size))
	points.append(center + Vector2(half_size, half_size))
	points.append(center + Vector2(-half_size, half_size))
	return points

func get_obstacle_data() -> Dictionary:
	return {
		"pits": pits_data,
		"pillars": pillars_data
	}

func _is_position_safe(pos: Vector2) -> bool:
	# Check against pits
	for pit in pits_data:
		if pos.distance_to(pit.position) < pit.radius + 50:
			return false
	
	# Check against pillars
	for pillar in pillars_data:
		if pos.distance_to(pillar.position) < pillar.radius + 50:
			return false
	
	return true
