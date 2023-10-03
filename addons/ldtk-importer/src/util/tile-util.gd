@tool

# Flip a vector based on a bitset
static func _flip_vector_array_with_bitset(
		vecs: PackedVector2Array,
		bitset: int
) -> PackedVector2Array:
	var new_vecs = PackedVector2Array(vecs)
	for point_idx in range(vecs.size()):
		var new_vec = Vector2(vecs[point_idx])
		if bitset & 1:
			new_vec.x = -new_vec.x
		if bitset & 2:
			new_vec.y = -new_vec.y
		new_vecs[point_idx] = new_vec
	return new_vecs

# Copy over and rotate extra tiledata
static func copy_and_modify_tile_data(
		tile_data: TileData,
		orig_tile_data: TileData,
		physics_layers_cnt: int,
		navigation_layers_cnt: int,
		occluder_layers_cnt: int,
		bitset: int,
) -> void:
	# Copy over physics
	for pli in range(physics_layers_cnt):
		var polygon_cnt = orig_tile_data.get_collision_polygons_count(pli)
		if polygon_cnt == 0:
			# We have no polygon for this layer
			continue
		for pi in range(polygon_cnt):
			tile_data.add_collision_polygon(pli)
			var points: PackedVector2Array = _flip_vector_array_with_bitset(orig_tile_data.get_collision_polygon_points(pli, pi), bitset)
			tile_data.set_collision_polygon_points(pli, pi, points)
		tile_data.set_constant_angular_velocity(pli, orig_tile_data.get_constant_angular_velocity(pli))
		var linvel = Vector2(orig_tile_data.get_constant_linear_velocity(pli))
		if bitset & 1:
			linvel.x = -linvel.x
		if bitset & 2:
			linvel.y = -linvel.y
		tile_data.set_constant_linear_velocity(pli, linvel)

	# Copy over navigation
	for navi in range(navigation_layers_cnt):
		var nav_polygon: NavigationPolygon = orig_tile_data.get_navigation_polygon(navi)
		if nav_polygon == null:
			# We have no polygon for this layer
			continue
		var new_polygon = NavigationPolygon.new()
		for outline_idx in range(nav_polygon.get_outline_count()):
			var vertices = _flip_vector_array_with_bitset(nav_polygon.get_outline(outline_idx), bitset)
			new_polygon.add_outline(vertices)
		new_polygon.make_polygons_from_outlines()
		tile_data.set_navigation_polygon(navi, new_polygon)

	# Copy over occluder
	for occi in range(occluder_layers_cnt):
		var occluder: OccluderPolygon2D = orig_tile_data.get_occluder(occi)
		if occluder == null:
			# We have no polygon for this layer
			continue
		var new_occluder: OccluderPolygon2D = OccluderPolygon2D.new()
		new_occluder.cull_mode = occluder.cull_mode
		new_occluder.closed = occluder.closed
		new_occluder.polygon = _flip_vector_array_with_bitset(occluder.polygon, bitset)
		tile_data.set_occluder(occi, new_occluder)

	# Flip depending on bitset
	if bitset & 1:
		tile_data.set_flip_h(true)
	if bitset & 2:
		tile_data.set_flip_v(true)

static func create_flipped_alternative_tiles(
		tilemap: TileMap,
		tile_source: TileSetAtlasSource,
		tile_grid: Vector2
) -> void:
	# Create full set of alternative tiles for this tile
	for i in range(1,4):
		var new_tile = tile_source.create_alternative_tile(tile_grid, i)
		copy_and_modify_tile_data(
			tile_source.get_tile_data(tile_grid, new_tile),
			tile_source.get_tile_data(tile_grid, 0),
			tilemap.tile_set.get_physics_layers_count(),
			tilemap.tile_set.get_navigation_layers_count(),
			tilemap.tile_set.get_occlusion_layers_count(),
			i
		)

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
		px_coords: Vector2,
		grid_size: Vector2,
		padding: Vector2 = Vector2.ZERO,
		spacing: Vector2 = Vector2.ZERO
) -> Vector2i:
	var x: int = round((px_coords.x - padding.x) / (grid_size.x + spacing.x))
	var y: int = round((px_coords.y - padding.y) / (grid_size.y + spacing.y))
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
