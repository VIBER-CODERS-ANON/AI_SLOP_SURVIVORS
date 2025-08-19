extends TileMap
class_name DungeonTileMap

## Main tilemap node for rendering and managing the dungeon floor
## Handles multiple layers, tile interactions, and visual effects

signal hazard_damage_dealt(damage: float, world_position: Vector2)

## Tile layers
enum {
	LAYER_BASE = 0,
	LAYER_OVERLAY = 1,
	LAYER_EFFECTS = 2,
	LAYER_PARTICLES = 3
}

## Reference to tile manager
@onready var tile_manager: TileManager = null  # Will be set by game controller

## Tilemap data storage [Vector2i -> TileResource]
var tile_data: Dictionary = {}

## Active particle effects [Vector2i -> Node2D]
var active_particles: Dictionary = {}

## Players/entities on hazardous tiles
var entities_on_hazards: Dictionary = {}

## Tile atlas source ID
var atlas_source_id: int = 0

func _ready() -> void:
	# Configure tilemap settings
	tile_set = TileSet.new()
	
	# Use proper tile size - 32x32 for PixelLab tilesets
	if tile_manager:
		tile_set.tile_size = tile_manager.tile_size
	else:
		tile_set.tile_size = Vector2i(32, 32)  # Standard PixelLab tile size
	
	# Layers are already set up in TileMap, just configure them
	rendering_quadrant_size = 16  # Optimize rendering
	
	# Debug print
	print("ð® DungeonTileMap ready! TileSet: ", tile_set, " Visible: ", visible, " Z-index: ", z_index)

func setup_tileset_source(tileset_texture: Texture2D) -> void:
	## Sets up the tileset atlas source with the provided texture
	if not tile_set:
		tile_set = TileSet.new()
		tile_set.tile_size = tile_manager.tile_size
	
	# Remove old source if exists
	if tile_set.has_source(atlas_source_id):
		tile_set.remove_source(atlas_source_id)
	
	# Create new atlas source
	var atlas_source := TileSetAtlasSource.new()
	atlas_source.texture = tileset_texture
	atlas_source.texture_region_size = Vector2i(32, 32)  # PixelLab tiles are always 32x32
	
	# Create tiles in the atlas (4x4 grid = 16 tiles)
	for y in range(4):
		for x in range(4):
			atlas_source.create_tile(Vector2i(x, y))
			
			# Set up collision for walls
			var tile_index := y * 4 + x
			if tile_manager.tilesets.has(tile_manager.active_tileset):
				var tile_resource: TileResource = tile_manager.tilesets[tile_manager.active_tileset].get(tile_index)
				if tile_resource and tile_resource.collision_enabled:
					var atlas_tile_data := atlas_source.get_tile_data(Vector2i(x, y), 0)
					atlas_tile_data.add_collision_polygon(0)
					atlas_tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
						Vector2(-16, -16), Vector2(16, -16), 
						Vector2(16, 16), Vector2(-16, 16)
					]))
	
	tile_set.add_source(atlas_source, atlas_source_id)
	
	# Debug: Print texture info
	print("ð¨ Tileset texture: ", tileset_texture, " Size: ", tileset_texture.get_size() if tileset_texture else Vector2.ZERO)
	print("ð¨ TileSet sources: ", tile_set.get_source_count())

func place_tile(grid_position: Vector2i, tile_resource: TileResource, layer: int = LAYER_BASE) -> void:
	## Places a tile at the specified grid position
	if not tile_resource:
		return
	
	# Store tile data
	tile_data[grid_position] = tile_resource
	
	# Find atlas coordinates for this tile
	var atlas_coords := _get_atlas_coords_for_tile(tile_resource)
	if atlas_coords == Vector2i(-1, -1):
		push_error("DungeonTileMap: No atlas coordinates found for tile: " + tile_resource.tile_id)
		return
	
	# Debug first tile
	if tile_data.size() == 1:
		print("ð Placing first tile: ", tile_resource.tile_id, " at ", grid_position, " with atlas coords ", atlas_coords)
	
	# Set the tile
	set_cell(layer, grid_position, atlas_source_id, atlas_coords)
	
	# Add visual effects if needed
	if tile_resource.emission_strength > 0:
		_add_emission_effect(grid_position, tile_resource)
	
	if tile_resource.particle_scene:
		_spawn_particle_effect(grid_position, tile_resource)

func _get_atlas_coords_for_tile(tile_resource: TileResource) -> Vector2i:
	## Gets the atlas coordinates for a tile resource
	# Simple mapping based on tile type
	match tile_resource.tile_id:
		"default_stone":
			return Vector2i(0, 0)
		"default_blood":
			return Vector2i(2, 1)  # Blood splatter tile
		"default_gore":
			return Vector2i(3, 2)   # Heavy gore tile
		"default_wall":
			return Vector2i(0, 3)   # Dark wall tile
		"default_lava":
			return Vector2i(3, 3)   # Lava tile
		_:
			# For any other tile, use a basic pattern
			match tile_resource.tile_type:
				TileResource.TileType.FLOOR_STONE:
					return Vector2i(0, 0)
				TileResource.TileType.FLOOR_BLOOD:
					return Vector2i(2, 1)
				TileResource.TileType.FLOOR_GORE:
					return Vector2i(3, 2)
				TileResource.TileType.WALL_STONE:
					return Vector2i(0, 3)
				TileResource.TileType.LAVA:
					return Vector2i(3, 3)
				_:
					return Vector2i(0, 0)  # Default to stone

func _add_emission_effect(grid_position: Vector2i, tile_resource: TileResource) -> void:
	## Adds emission/glow effect to a tile
	var world_pos := map_to_local(grid_position)
	
	# Create a simple glow sprite
	var glow := Sprite2D.new()
	glow.texture = preload("res://icon.svg")  # Replace with proper glow texture
	glow.modulate = tile_resource.emission_color
	glow.modulate.a = tile_resource.emission_strength
	glow.position = world_pos
	glow.scale = Vector2(0.5, 0.5)
	glow.z_index = -1
	add_child(glow)
	
	# Add pulsing animation
	var tween := create_tween()
	tween.set_loops(-1)  # Infinite loops
	
	# Store tween reference for cleanup
	glow.set_meta("tween", tween)
	
	# Kill tween when glow is freed
	glow.tree_exiting.connect(func(): 
		if tween and tween.is_valid():
			tween.kill()
	)
	
	tween.tween_property(glow, "modulate:a", tile_resource.emission_strength * 0.5, 2.0)
	tween.tween_property(glow, "modulate:a", tile_resource.emission_strength, 2.0)

func _spawn_particle_effect(grid_position: Vector2i, tile_resource: TileResource) -> void:
	## Spawns particle effects for a tile
	if not tile_resource.particle_scene:
		return
	
	var world_pos := map_to_local(grid_position)
	var particles := tile_resource.particle_scene.instantiate()
	particles.position = world_pos
	add_child(particles)
	active_particles[grid_position] = particles

func get_tile_at_world_position(world_position: Vector2) -> TileResource:
	## Gets the tile resource at a world position
	var grid_pos := local_to_map(to_local(world_position))
	return tile_data.get(grid_pos)

func is_position_walkable(world_position: Vector2) -> bool:
	## Checks if a world position is walkable
	var tile := get_tile_at_world_position(world_position)
	return tile != null and tile.walkable

func get_movement_speed_at_position(world_position: Vector2) -> float:
	## Gets the movement speed modifier at a position
	var tile := get_tile_at_world_position(world_position)
	if tile:
		return tile.movement_speed_modifier
	return 1.0

func register_entity_on_tile(entity: Node2D) -> void:
	## Registers an entity for hazard damage checking
	var tile := get_tile_at_world_position(entity.global_position)
	if tile and tile.hazardous:
		entities_on_hazards[entity] = tile

func unregister_entity(entity: Node2D) -> void:
	## Unregisters an entity from hazard checking
	entities_on_hazards.erase(entity)

func _physics_process(delta: float) -> void:
	## Process hazardous tile damage
	for entity in entities_on_hazards:
		if is_instance_valid(entity):
			var tile: TileResource = entities_on_hazards[entity]
			if tile.damage_per_second > 0:
				# Deal damage (assuming entity has take_damage method)
				if entity.has_method("take_damage"):
					entity.take_damage(tile.damage_per_second * delta)
					hazard_damage_dealt.emit(tile.damage_per_second * delta, entity.global_position)
		else:
			entities_on_hazards.erase(entity)

func _on_tileset_loaded(tileset_name: String) -> void:
	## Called when a new tileset is loaded
	var tileset_texture := tile_manager.create_tileset_texture(tileset_name)
	if tileset_texture:
		setup_tileset_source(tileset_texture)

func clear_all_tiles() -> void:
	## Clears all tiles from all layers
	for layer in range(get_layers_count()):
		clear_layer(layer)
	
	tile_data.clear()
	
	# Clean up particles
	for particles in active_particles.values():
		if is_instance_valid(particles):
			particles.queue_free()
	active_particles.clear()
	
	entities_on_hazards.clear()
