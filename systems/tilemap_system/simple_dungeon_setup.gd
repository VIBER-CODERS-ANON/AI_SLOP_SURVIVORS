extends Node

static func setup_dungeon(game_controller: Node) -> void:
	push_error("DUNGEON SETUP CALLED - This is not an error, just a debug message!")
	print(">>> Setting up dungeon floor...")
	
	# Get our dungeon systems
	var tile_manager = game_controller.get_node_or_null("TileManager")
	var dungeon_tilemap = game_controller.get_node_or_null("DungeonTileMap")
	
	print(">>> TileManager: ", tile_manager)
	print(">>> DungeonTileMap: ", dungeon_tilemap)
	
	if not tile_manager or not dungeon_tilemap:
		push_error("Missing dungeon system nodes!")
		return
	
	# Move tilemap to correct z-index and ensure visibility
	dungeon_tilemap.z_index = -5  # Below entities but above background
	dungeon_tilemap.visible = true
	dungeon_tilemap.modulate = Color.WHITE
	
	# Set tile manager reference
	dungeon_tilemap.tile_manager = tile_manager
	
	# We're using PixelLab tiles for the dungeon floor
	# The old DungeonGenerator has been removed as it was causing checkerboard pattern issues
	
	# Clear any existing tiles
	if dungeon_tilemap.has_method("clear_all_tiles"):
		dungeon_tilemap.clear_all_tiles()
	elif dungeon_tilemap.has_method("clear"):
		dungeon_tilemap.clear()
	else:
		# Fallback - clear layer 0
		dungeon_tilemap.clear_layer(0)
	
	# Check if we're dealing with a DungeonTileMap or regular TileMap
	print(">>> Tilemap type: ", dungeon_tilemap.get_class())
	
	# For DungeonTileMap, we need to bypass its custom tile system
	# and use the standard TileMap directly
	var tilemap_base = dungeon_tilemap as TileMap
	
	# Load the HIGH-QUALITY Diablo dungeon tileset
	PixelLabTilesetLoader.load_diablo_tileset(tilemap_base)
	
	print(">>> HIGH-QUALITY DIABLO TILESET LOADED!")
	
	# Generate proper Wang tile dungeon with seamless transitions
	# Arena is 3000x3000, with 32px tiles that's about 94x94 tiles
	var arena_tile_size = Vector2i(94, 94)
	PixelLabTilesetLoader.generate_wang_tile_dungeon(tilemap_base, arena_tile_size, 0.25)

	# Center the tilemap in the arena so the player isn't standing on empty space
	var tile_px_size := Vector2(32, 32)
	var half_tiles_px := Vector2(arena_tile_size.x, arena_tile_size.y) * tile_px_size * 0.5
	tilemap_base.position = -half_tiles_px
	
	print(">>> SEAMLESS DUNGEON FLOOR COMPLETE!")

	# Fallback: if nothing was drawn (e.g., missing/transparent tileset), draw a simple stone floor
	var used_after = tilemap_base.get_used_cells(0)
	if used_after.size() == 0:
		print("⚠️ No tiles placed by PixelLab tileset. Using procedural fallback floor.")
		# Build a tiny 2x2 stone atlas and fill the map
		var fallback_texture := create_brutal_tileset_texture()
		if not tilemap_base.tile_set:
			tilemap_base.tile_set = TileSet.new()
		tilemap_base.tile_set.tile_size = Vector2i(32, 32)
		if tilemap_base.tile_set.has_source(0):
			tilemap_base.tile_set.remove_source(0)
		var fallback_src := TileSetAtlasSource.new()
		fallback_src.texture = fallback_texture
		fallback_src.texture_region_size = Vector2i(32, 32)
		for yy in range(4):
			for xx in range(4):
				fallback_src.create_tile(Vector2i(xx, yy))
		tilemap_base.tile_set.add_source(fallback_src, 0)
		for y in range(arena_tile_size.y):
			for x in range(arena_tile_size.x):
				# Pick a tile from the 4x4 atlas in a deterministic pattern
				var idx := (x + y * 3) % 16
				var atlas_xy := Vector2i(idx % 4, int(idx / 4.0))
				tilemap_base.set_cell(0, Vector2i(x, y), 0, atlas_xy)
	
	# Ensure tilemap is visible and properly configured
	dungeon_tilemap.visible = true
	dungeon_tilemap.z_index = -10  # Above background (-20) but below entities
	dungeon_tilemap.modulate = Color.WHITE
	
	# Debug: Check if tilemap has tiles
	var used_cells = dungeon_tilemap.get_used_cells(0)
	print(">>> DUNGEON FLOOR COMPLETE! Placed ", used_cells.size(), " tiles")
	print(">>> DungeonTileMap tile_set: ", dungeon_tilemap.tile_set)
	print(">>> DungeonTileMap visible: ", dungeon_tilemap.visible)
	print(">>> DungeonTileMap z_index: ", dungeon_tilemap.z_index)
	print(">>> DungeonTileMap modulate: ", dungeon_tilemap.modulate)

static func create_brutal_tileset_texture() -> Texture2D:
	# Create a dark, brutal tileset texture
	var tile_size = 32
	var atlas_size = Vector2i(tile_size * 4, tile_size * 4)  # 4x4 grid for 16 tiles
	var image = Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	
	# Define brutal colors
	var colors = {
		"stone": Color(0.15, 0.15, 0.2),      # Dark blue-gray stone
		"blood": Color(0.4, 0.05, 0.05),      # Dark dried blood
		"gore": Color(0.6, 0.1, 0.0),         # Fresh gore
		"wall": Color(0.05, 0.05, 0.08),      # Almost black walls
		"lava": Color(0.8, 0.2, 0.0)          # Molten lava
	}
	
	# Create tiles with different blood/gore patterns based on corner configuration
	for i in range(16):
		var x_offset = (i % 4) * tile_size
		var y_offset = int(i / 4.0) * tile_size
		
		# Count how many corners have upper terrain (blood/gore)
		var corner_count = 0
		for bit in range(4):
			if i & (1 << bit):
				corner_count += 1
		
		# Base color depends on corner count
		var base_color: Color
		if corner_count == 0:
			base_color = colors.stone
		elif corner_count <= 2:
			base_color = colors.stone.lerp(colors.blood, corner_count * 0.3)
		else:
			base_color = colors.blood.lerp(colors.gore, (corner_count - 2) * 0.5)
		
		# Fill tile with base color and add texture
		for y in range(tile_size):
			for x in range(tile_size):
				var pixel_color = base_color
				
				# Add noise for texture
				var noise = randf() * 0.15 - 0.075
				pixel_color = pixel_color + Color(noise, noise, noise, 0)
				
				# Add cracks and details based on position
				if (x + y) % 8 == 0:
					pixel_color = pixel_color.darkened(0.2)
				
				# Add blood splatters for tiles with gore
				if corner_count > 2 and randf() < 0.1:
					pixel_color = colors.gore.darkened(randf() * 0.3)
				
				# Darken edges
				if x == 0 or x == tile_size - 1 or y == 0 or y == tile_size - 1:
					pixel_color = pixel_color.darkened(0.3)
				
				image.set_pixel(x_offset + x, y_offset + y, pixel_color)
	
	var texture = ImageTexture.create_from_image(image)
	print(">>> Created brutal tileset texture: ", texture.get_size())
	return texture

static func render_dungeon_to_tilemap(dungeon_data: Dictionary, tilemap: DungeonTileMap, tile_manager: TileManager, game_controller: Node):
	# Get the grid data
	var grid = dungeon_data.grid
	
	# Render each tile
	for y in range(grid.size()):
		for x in range(grid[y].size()):
			var tile_data = grid[y][x]
			var grid_pos = Vector2i(x - 8, y - 8)  # Center the dungeon (16/2.0)
			
			# Create appropriate tile resource based on type
			var tile_resource: TileResource
			
			match tile_data.base_tile:
				TileResource.TileType.FLOOR_STONE:
					# Floor tiles - pick based on blood overlay
					if tile_data.overlay_tile == TileResource.TileType.FLOOR_BLOOD:
						tile_resource = tile_manager.tile_resources.get("default_blood", 
							tile_manager.tile_resources.get("default_stone"))
					elif tile_data.overlay_tile == TileResource.TileType.FLOOR_GORE:
						# Create gore tile if not exists
						if not tile_manager.tile_resources.has("default_gore"):
							var gore_tile = TileResource.new("default_gore", TileResource.TileType.FLOOR_GORE)
							gore_tile.tile_name = "Gore-Covered Floor"
							gore_tile.generation_weight = 1.0
							tile_manager.tile_resources["default_gore"] = gore_tile
						tile_resource = tile_manager.tile_resources.get("default_gore")
					else:
						tile_resource = tile_manager.tile_resources.get("default_stone")
				TileResource.TileType.WALL_STONE:
					tile_resource = tile_manager.tile_resources.get("default_wall")
				TileResource.TileType.LAVA:
					# Create lava tile if not exists
					if not tile_manager.tile_resources.has("default_lava"):
						var lava_tile = TileResource.new("default_lava", TileResource.TileType.LAVA)
						lava_tile.tile_name = "Molten Lava"
						lava_tile.generation_weight = 0.5
						tile_manager.tile_resources["default_lava"] = lava_tile
					tile_resource = tile_manager.tile_resources.get("default_lava")
				_:
					tile_resource = tile_manager.tile_resources.get("default_stone")
			
			if tile_resource:
				tilemap.place_tile(grid_pos, tile_resource, DungeonTileMap.LAYER_BASE)
