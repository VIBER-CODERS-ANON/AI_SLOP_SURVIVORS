extends Node

## Loads the REAL PixelLab tileset properly into Godot

static func setup_pixellab_tileset(dungeon_tilemap) -> void:
	print("🎮 Loading REAL PixelLab tileset!")
	
	# Load the actual tileset texture (PixelLab generates at 32x32)
	var tileset_texture = load("res://assets/tilesets/brutal_dungeon_tileset.png")
	if not tileset_texture:
		push_error("Failed to load tileset! Creating fallback...")
		tileset_texture = _create_pixellab_style_tileset()
	else:
		print("✅ Loaded PixelLab tileset - using native 32x32 tiles")
	
	# Setup the tileset using DungeonTileMap's method
	dungeon_tilemap.setup_tileset_source(tileset_texture)
	
	print("✅ PixelLab tileset loaded successfully!")

static func _create_pixellab_style_tileset() -> Texture2D:
	# Create a PixelLab-style tileset as fallback
	# 4x4 grid, 32x32 tiles = 128x128 total
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# TRUE Diablo 2 Cathedral colors
	var colors = {
		"stone_base": Color(0.40, 0.38, 0.36),     # Light gray stone (D2 Act 1 Cathedral)
		"stone_light": Color(0.45, 0.43, 0.41),    # Highlight on stones
		"stone_dark": Color(0.35, 0.33, 0.31),     # Stone shadows
		"mortar": Color(0.25, 0.23, 0.21),         # Dark mortar between tiles
		"blood_old": Color(0.15, 0.03, 0.01),      # Very dark dried blood
		"blood_fresh": Color(0.25, 0.05, 0.02),    # Slightly fresher blood
		"crack": Color(0.20, 0.18, 0.16),          # Stone damage/cracks
		"dirt": Color(0.30, 0.28, 0.26)            # Dirt/grime accumulation
	}
	
	# Generate each tile based on Wang tile corner configuration
	for tile_idx in range(16):
		var tile_x = tile_idx % 4
		var tile_y = int(tile_idx / 4.0)
		var base_x = tile_x * 32
		var base_y = tile_y * 32
		
		# Decode corner configuration
		var has_blood_tl = (tile_idx & 1) != 0    # Top-left
		var has_blood_tr = (tile_idx & 2) != 0    # Top-right
		var has_blood_bl = (tile_idx & 4) != 0    # Bottom-left
		var has_blood_br = (tile_idx & 8) != 0    # Bottom-right
		
		# Fill the tile
		for y in range(32):
			for x in range(32):
				var px = base_x + x
				var py = base_y + y
				
				# Start with stone base
				var color = colors.stone_base
				
				# Create irregular stone pattern (like D2)
				# Different sized stones for variety
				var stone_pattern = int(x / 8.0 + y / 8.0) % 3
				var is_mortar = false
				
				if stone_pattern == 0:  # Large stones (8x8)
					is_mortar = (x % 8 == 0) or (y % 8 == 0)
				elif stone_pattern == 1:  # Medium stones (6x6)
					is_mortar = (x % 6 == 0) or (y % 6 == 0)
				else:  # Small stones (4x4)
					is_mortar = (x % 4 == 0) or (y % 4 == 0)
				
				if is_mortar:
					color = colors.mortar
				else:
					# Stone surface with wear
					var wear = sin(x * 0.2 + y * 0.3) * 0.04
					color = colors.stone_base.lerp(colors.stone_light, wear + 0.5)
					
					# Add some darker spots for depth
					if (x + y * 2) % 13 == 0:
						color = colors.stone_dark
					
					# Occasional dirt/grime
					if sin(x * 0.15 - y * 0.25) > 0.8:
						color = color.lerp(colors.dirt, 0.3)
				
				# Apply blood based on corners
				var in_blood_zone = false
				var blood_strength = 0.0
				
				# Check which quadrant we're in and apply blood accordingly
				if x < 16 and y < 16 and has_blood_tl:  # Top-left quadrant
					var dist = Vector2(x - 0, y - 0).length()
					blood_strength = max(blood_strength, 1.0 - (dist / 22.0))
					in_blood_zone = true
				
				if x >= 16 and y < 16 and has_blood_tr:  # Top-right quadrant
					var dist = Vector2(x - 31, y - 0).length()
					blood_strength = max(blood_strength, 1.0 - (dist / 22.0))
					in_blood_zone = true
				
				if x < 16 and y >= 16 and has_blood_bl:  # Bottom-left quadrant
					var dist = Vector2(x - 0, y - 31).length()
					blood_strength = max(blood_strength, 1.0 - (dist / 22.0))
					in_blood_zone = true
				
				if x >= 16 and y >= 16 and has_blood_br:  # Bottom-right quadrant
					var dist = Vector2(x - 31, y - 31).length()
					blood_strength = max(blood_strength, 1.0 - (dist / 22.0))
					in_blood_zone = true
				
				# Apply blood coloring (subtle, like D2)
				if in_blood_zone and blood_strength > 0:
					# Make blood more subtle and patchy
					var blood_pattern = sin(x * 0.6 + y * 0.4) + cos(x * 0.3 - y * 0.5)
					
					if blood_pattern > 0.3:  # Only apply blood in certain areas
						blood_strength *= 0.5  # Make it more subtle
						blood_strength = clamp(blood_strength, 0.0, 0.6)
						
						if blood_strength > 0.05:
							# Darken the stone rather than make it red
							color = color.darkened(blood_strength * 0.8)
							# Add slight red tint
							color = color.lerp(colors.blood_old, blood_strength * 0.4)
				
				# Set pixel
				image.set_pixel(px, py, color)
	
	return ImageTexture.create_from_image(image)
