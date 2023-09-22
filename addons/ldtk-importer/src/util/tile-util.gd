@tool

# Get Rect of Tile for an AtlasSource using LDTK tileset data
static func get_tile_region(
		coords: Vector2i,
		grid_size: int,
		padding: int,
		spacing: int,
		grid_w: int
) -> Rect2i:
	var pixel_coords = grid_to_px(coords, grid_size, padding, spacing)
	return Rect2i(pixel_coords, Vector2i(grid_size, grid_size))

# Convert grid coords to pixel coords
static func grid_to_px(
		grid_coords: Vector2i,
		grid_size: int,
		padding: int,
		spacing: int
) -> Vector2i:
	var x: int = padding + grid_coords.x * (grid_size + spacing)
	var y: int = padding + grid_coords.y * (grid_size + spacing)

	return Vector2i(x, y)

# Converts px coords to grid coords
static func px_to_grid(
		px_coords: Vector2i,
		grid_size: Vector2i,
		padding: Vector2i = Vector2i.ZERO,
		spacing: Vector2i = Vector2i.ZERO
) -> Vector2i:
	var x: int = floor((px_coords.x - padding.x) / (grid_size.x + spacing.x))
	var y: int = floor((px_coords.y - padding.y) / (grid_size.y + spacing.y))

	return Vector2i(x, y)

# Convert TileId to grid coords
static func tileid_to_grid(tile_id: int, grid_w: int) -> Vector2i:
	var y := int(tile_id / grid_w)
	var x := tile_id - grid_w * y

	return Vector2i(x, y)

static func index_to_grid(index: int, grid_w: int) -> Vector2i:
	var x: int = floor(index % grid_w)
	var y: int = floor(index / grid_w)

	return Vector2i(x, y)
