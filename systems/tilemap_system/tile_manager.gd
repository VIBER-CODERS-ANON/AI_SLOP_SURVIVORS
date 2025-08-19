class_name TileManager
extends Node

## Singleton manager for all tile resources and tileset operations
## Handles loading tiles from PixelLab, managing tile resources, and providing tile data

signal tileset_loaded(tileset_name: String)
signal tile_resources_updated()

## Dictionary of all loaded tile resources by ID
var tile_resources: Dictionary = {}

## Dictionary of tilesets by name
var tilesets: Dictionary = {}

## Currently active tileset
var active_tileset: String = "dungeon_base"

## Tile size in pixels
var tile_size: Vector2i = Vector2i(32, 32)  # Standard PixelLab tile size

func _ready() -> void:
	set_process(false)
	_initialize_default_tiles()

func _initialize_default_tiles() -> void:
	# Create some default tile resources for testing
	var stone_tile := TileResource.new("default_stone", TileResource.TileType.FLOOR_STONE)
	stone_tile.tile_name = "Ancient Stone Floor"
	stone_tile.generation_weight = 5.0
	tile_resources[stone_tile.tile_id] = stone_tile
	
	var blood_tile := TileResource.new("default_blood", TileResource.TileType.FLOOR_BLOOD)
	blood_tile.tile_name = "Blood-Stained Floor"
	blood_tile.generation_weight = 2.0
	tile_resources[blood_tile.tile_id] = blood_tile
	
	var wall_tile := TileResource.new("default_wall", TileResource.TileType.WALL_STONE)
	wall_tile.tile_name = "Dungeon Wall"
	wall_tile.generation_weight = 0.0  # Walls are placed by generation logic
	tile_resources[wall_tile.tile_id] = wall_tile

func load_tileset_from_pixellab(tileset_data: Dictionary) -> void:
	## Loads a tileset from PixelLab MCP data
	var tileset_name: String = tileset_data.get("name", "unnamed_tileset")
	var tiles_array: Array = tileset_data.get("tiles", [])
	
	if tiles_array.is_empty():
		push_error("TileManager: No tiles in tileset data")
		return
	
	var new_tileset := {}
	
	for i in range(tiles_array.size()):
		var tile_data: Dictionary = tiles_array[i]
		var tile_id: String = "%s_tile_%d" % [tileset_name, i]
		
		# Determine tile type based on index and tileset properties
		var tile_type := _determine_tile_type(i, tileset_data)
		var tile_resource := TileResource.new(tile_id, tile_type)
		
		# Load texture from base64 if available
		if tile_data.has("image_base64"):
			tile_resource.texture = _load_texture_from_base64(tile_data["image_base64"])
		
		# Set generation properties based on corner configuration
		tile_resource.generation_weight = _calculate_generation_weight(i)
		
		tile_resources[tile_id] = tile_resource
		new_tileset[i] = tile_resource
	
	tilesets[tileset_name] = new_tileset
	tileset_loaded.emit(tileset_name)
	tile_resources_updated.emit()

func _determine_tile_type(index: int, tileset_data: Dictionary) -> TileResource.TileType:
	## Determines tile type based on tileset configuration and index
	var _lower_desc: String = tileset_data.get("lower_description", "").to_lower()
	var upper_desc: String = tileset_data.get("upper_description", "").to_lower()
	
	# Binary representation of corners (index 0-15)
	var has_upper_terrain := index > 0
	
	if "blood" in upper_desc or "gore" in upper_desc:
		if has_upper_terrain:
			return TileResource.TileType.FLOOR_GORE if "gore" in upper_desc else TileResource.TileType.FLOOR_BLOOD
	
	return TileResource.TileType.FLOOR_STONE

func _calculate_generation_weight(corner_config: int) -> float:
	## Calculate generation weight based on corner configuration
	## Tiles with fewer corners are more common
	var corner_count := 0
	for i in range(4):
		if corner_config & (1 << i):
			corner_count += 1
	
	return 5.0 - (corner_count * 1.0)

func _load_texture_from_base64(base64_string: String) -> Texture2D:
	## Converts base64 string to Texture2D
	var image := Image.new()
	var buffer := Marshalls.base64_to_raw(base64_string)
	
	# Try loading as PNG first, then other formats
	var error := image.load_png_from_buffer(buffer)
	if error != OK:
		error = image.load_jpg_from_buffer(buffer)
		if error != OK:
			push_error("TileManager: Failed to load texture from base64")
			return null
	
	return ImageTexture.create_from_image(image)

func get_tile_resource(tile_id: String) -> TileResource:
	return tile_resources.get(tile_id)

func get_tiles_by_type(tile_type: TileResource.TileType) -> Array[TileResource]:
	var matching_tiles: Array[TileResource] = []
	for tile in tile_resources.values():
		if tile.tile_type == tile_type:
			matching_tiles.append(tile)
	return matching_tiles

func get_random_tile_of_type(tile_type: TileResource.TileType) -> TileResource:
	var tiles := get_tiles_by_type(tile_type)
	if tiles.is_empty():
		return null
	
	# Weight-based selection
	var total_weight := 0.0
	for tile in tiles:
		total_weight += tile.generation_weight
	
	var random_value := randf() * total_weight
	var current_weight := 0.0
	
	for tile in tiles:
		current_weight += tile.generation_weight
		if random_value <= current_weight:
			return tile
	
	return tiles[-1]  # Fallback

func create_tileset_texture(tileset_name: String) -> Texture2D:
	## Creates a combined texture atlas from a tileset for use in TileMap
	var tileset_data: Dictionary = tilesets.get(tileset_name, {})
	if not tileset_data:
		push_error("TileManager: Tileset '%s' not found" % tileset_name)
		return null
	
	# Create atlas texture (4x4 grid for 16 tiles)
	var atlas_size := Vector2i(tile_size.x * 4, tile_size.y * 4)
	var atlas_image := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	
	for i in range(16):
		var tile_resource: TileResource = tileset_data.get(i)
		if tile_resource and tile_resource.texture:
			var tile_image := tile_resource.texture.get_image()
			var x := (i % 4) * tile_size.x
			var y := int(i / 4.0) * tile_size.y
			atlas_image.blit_rect(tile_image, Rect2i(0, 0, tile_size.x, tile_size.y), Vector2i(x, y))
	
	return ImageTexture.create_from_image(atlas_image)
