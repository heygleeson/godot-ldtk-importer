@tool

# Copy over and rotate extra tiledata
static func copy_and_modify_tile_data(
	tile_data: TileData,
	orig_tile_data: TileData,
	physics_layers_cnt: int,
	iteration_count: int,
):
	# Copy over physics
	for pli in range(physics_layers_cnt):
		var polygon_cnt = orig_tile_data.get_collision_polygons_count(pli)
		for pi in range(polygon_cnt):
			tile_data.add_collision_polygon(pli)
			var points: PackedVector2Array = orig_tile_data.get_collision_polygon_points(pli, pi)
			for point_idx in range(points.size()):
				var point: Vector2 = points[point_idx]
				
				if iteration_count & 1:
					point = Vector2(-point.x, point.y)
				if iteration_count & 2:
					point = Vector2(point.x, -point.y)
				
				points[point_idx] = point
			tile_data.set_collision_polygon_points(pli, pi, points)

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
