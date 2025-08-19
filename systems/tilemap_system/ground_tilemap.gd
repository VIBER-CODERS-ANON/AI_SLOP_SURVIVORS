extends TileMap
class_name GroundTileMap

## Simple, robust ground tilemap for dungeon floors
## Builds a 4x4 atlas from a provided texture, or generates a fallback

const DEFAULT_TILE_SIZE: Vector2i = Vector2i(16, 16)
var _single_tile_mode: bool = false

func _ready() -> void:
	# Default configuration
	if tile_set == null:
		tile_set = TileSet.new()
	# Default tile size; can be overridden by setup methods
	tile_set.tile_size = DEFAULT_TILE_SIZE
	z_index = -15
	visible = true
	modulate = Color(1, 1, 1, 1)

func setup_from_texture(tileset_texture: Texture2D) -> void:
	if tileset_texture == null:
		tileset_texture = _try_load_raw_image("res://assets/tilesets/pixellab_dungeon_tileset.png")
		if tileset_texture == null:
			tileset_texture = _generate_fallback_texture()

	if tile_set == null:
		tile_set = TileSet.new()
	tile_set.tile_size = DEFAULT_TILE_SIZE

	# Replace source 0
	if tile_set.has_source(0):
		tile_set.remove_source(0)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = tileset_texture
	atlas.texture_region_size = tile_set.tile_size

	# Create all 16 tiles (4x4)
	for y in range(4):
		for x in range(4):
			atlas.create_tile(Vector2i(x, y))

	tile_set.add_source(atlas, 0)
	_single_tile_mode = false

func setup_single_tile_from_path(path: String) -> void:
	# Load as a resource for export compatibility
	var tex = load(path) as Texture2D
	if tex == null:
		# Fallback to generated
		var fallback_tex := _generate_fallback_texture()
		_setup_single_tile_from_texture(fallback_tex, fallback_tex.get_size())
		return
	_setup_single_tile_from_texture(tex, tex.get_size())

func _setup_single_tile_from_texture(texture: Texture2D, region_size: Vector2i) -> void:
	if tile_set == null:
		tile_set = TileSet.new()
	tile_set.tile_size = region_size
	if tile_set.has_source(0):
		tile_set.remove_source(0)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = texture
	atlas.texture_region_size = region_size
	atlas.create_tile(Vector2i(0, 0))
	tile_set.add_source(atlas, 0)
	_single_tile_mode = true

func setup_from_path(path: String) -> void:
	var tex: Texture2D = load(path)
	if tex == null:
		tex = _try_load_raw_image(path)
	setup_from_texture(tex)

func fill_grid(size_in_tiles: Vector2i, center: bool = true) -> void:
	# Optional centering: put origin at top-left unless center requested
	if center:
		var ts := _get_tile_px()
		position = -Vector2(size_in_tiles.x, size_in_tiles.y) * Vector2(ts) * 0.5

	# Place a variant pattern for subtle variation
	for y in range(size_in_tiles.y):
		for x in range(size_in_tiles.x):
			var atlas_xy := Vector2i(0, 0) if _single_tile_mode else Vector2i(((x * 7 + y * 3) % 16) % 4, int(((x * 7 + y * 3) % 16) / 4.0))
			set_cell(0, Vector2i(x, y), 0, atlas_xy)

func _generate_fallback_texture() -> Texture2D:
	# Bright, readable stone so we always see something
	var ts := _get_tile_px()
	var atlas_size := Vector2i(ts.x * 4, ts.y * 4)
	var image := Image.create(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)

	var base := Color(0.45, 0.45, 0.5)
	var highlight := Color(0.75, 0.75, 0.85)
	var shadow := Color(0.35, 0.35, 0.4)
	var grout := Color(0.18, 0.18, 0.2)

	for tile_idx in range(16):
		var ox := (tile_idx % 4) * ts.x
		var oy := int(tile_idx / 4.0) * ts.y
		for y in range(ts.y):
			for x in range(ts.x):
				var col := base
				# Stone grid with varied block sizes
				var bs := 4 + (tile_idx % 3) * 2
				var mortar := (x % bs == 0) or (y % bs == 0)
				if mortar:
					col = grout
				else:
					var n := sin(float(x + tile_idx) * 0.25) * cos(float(y - tile_idx) * 0.2)
					col = base.lerp(highlight, 0.35 + n * 0.15)
					if ((x + y) % 9) == 0:
						col = shadow
				image.set_pixel(ox + x, oy + y, col)

	return ImageTexture.create_from_image(image)

func _try_load_raw_image(path: String) -> Texture2D:
	var image := Image.new()
	var err := image.load(path)
	if err == OK:
		return ImageTexture.create_from_image(image)
	return null

func _get_tile_px() -> Vector2i:
	return tile_set.tile_size if tile_set and tile_set.tile_size != Vector2i() else DEFAULT_TILE_SIZE
