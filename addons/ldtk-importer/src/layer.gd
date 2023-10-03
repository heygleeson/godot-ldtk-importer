@tool

const Util = preload("util/util.gd")
const LayerUtil = preload("util/layer-util.gd")
const TileUtil = preload("util/tile-util.gd")

static func create_layers(
		level_data: Dictionary,
		layer_instances: Array,
		definitions: Dictionary
) -> Array:

	var layer_nodes := []
	var layer_index: int = 0

	for layer_instance in layer_instances:
		var layer_def: Dictionary = definitions.layers[layer_instance.layerDefUid]
		var layer_type: String = layer_instance.__type

		match layer_type:
			"Entities":
				var layer = create_entity_layer(layer_instance, layer_def, definitions.entities)
				layer_nodes.push_front(layer)

			"IntGrid":
				var layer = create_intgrid_layer(layer_instance, layer_def)
				layer_nodes.push_front(layer)

			"Tiles", "AutoLayer":
				var layer = create_tile_layer(layer_instance, layer_def)
				layer_nodes.push_front(layer)

			_:
				push_warning("[LDtk] Tried importing an unsupported layer type: ", layer_type)

	return layer_nodes

static func create_entity_layer(
		layer_data: Dictionary,
		layer_def: Dictionary,
		entity_defs: Dictionary
) -> Node2D:

	var layer = LDTKEntityLayer.new()
	layer.name = layer_data.__identifier

	if (Util.options.verbose_output):
		print("Creating Entity Layer: ", layer.name)

	# Create a dummy child node so EntityRef fields get a correct NodePath
	# I need to find a better way to do this, but there are lots of funny behaviours to deal with.
	var pathResolver = Node2D.new()
	pathResolver.name = "NodePathResolver"
	layer.add_child(pathResolver)
	Util.path_resolvers.append(pathResolver)

	var entities: Array = LayerUtil.parse_entity_instances(
			layer_data.entityInstances,
			entity_defs,
			pathResolver
	)

	# Add instance references
	layer.definition = layer_def
	layer.entities = entities

	if (Util.options.use_entity_placeholders):
		LayerUtil.placeholder_counts.clear()
		for entity in entities:
				var placeholder = LayerUtil.create_entity_placeholder(layer, entity)
				Util.update_instance_reference(placeholder.iid, placeholder)

	return layer

static func create_intgrid_layer(
		layer_data: Dictionary,
		layer_def: Dictionary
) -> TileMap:

	var has_tileset := layer_data.__tilesetDefUid != null

	# Create TileMap
	var tilemap: TileMap = LayerUtil.create_layer_tilemap(layer_data)

	# Retrieve IntGrid values - these do not always match their array index
	var values: Array = layer_def.intGridValues.map(
		func(item): return item.value
	)

	# Set layer properties on the Tilemap
	var layer_name := str(layer_data.__identifier) + "-values"
	var layer_index := tilemap.get_layers_count() -1
	tilemap.set_layer_name(layer_index, layer_name)
	tilemap.set_layer_modulate(layer_index, Color(1, 1, 1, layer_data.__opacity))
	tilemap.set_layer_enabled(layer_index, not has_tileset)

	if (Util.options.verbose_output):
		print("Creating IntGrid Layer: ", layer_name)

	# Get tile data
	var tiles: Array = layer_data.intGridCsv
	var tile_source_id: int = layer_data.layerDefUid
	var columns: int = layer_data.__cWid

	# Place IntGrid value tiles
	for index in range(0, tiles.size()):
		var value = tiles[index]
		var value_index: int = values.find(value)
		if value_index != -1:
			var cell_coords := TileUtil.index_to_grid(index, columns)
			var tile_coords := Vector2i(value_index, 0)
			tilemap.set_cell(layer_index, cell_coords, tile_source_id, tile_coords)

	# Place IntGrid tileset tiles
	if has_tileset:
		tilemap.add_layer(-1)
		layer_name = str(layer_data.__identifier) + "-tiles"
		layer_index = tilemap.get_layers_count() - 1
		tilemap.set_layer_name(layer_index, layer_name)
		tilemap.set_layer_modulate(layer_index, Color(1, 1, 1, layer_data.__opacity))

		# Get tile data
		if (layer_data.__type == "Tiles"):
			tiles = layer_data.gridTiles
		else:
			tiles = layer_data.autoLayerTiles

		tile_source_id = layer_data.__tilesetDefUid
		var grid_size := Vector2(layer_data.__gridSize, layer_data.__gridSize)

		__place_tiles(tilemap, tiles, tile_source_id, grid_size, layer_index)

	return tilemap

static func create_tile_layer(
		layer_data: Dictionary,
		layer_def: Dictionary
) -> TileMap:

	# Create Tilemap
	var tilemap: TileMap = LayerUtil.create_layer_tilemap(layer_data)

	# Set layer properties on the Tilemap
	var layer_name := str(layer_data.__identifier)
	var layer_index := tilemap.get_layers_count() - 1
	tilemap.set_layer_name(layer_index, layer_name)
	tilemap.set_layer_modulate(layer_index, Color(1, 1, 1, layer_data.__opacity))
	tilemap.set_layer_enabled(layer_index, layer_data.visible)
	tilemap.set_layer_z_index(layer_index, layer_index)

	if (Util.options.verbose_output):
		print("Creating Tile Layer: ", layer_name)

	# Get tile data
	var tiles: Array
	if (layer_data.__type == "Tiles"):
		tiles = layer_data.gridTiles
	else:
		tiles = layer_data.autoLayerTiles

	var tile_source_id: int = layer_data.__tilesetDefUid
	var grid_size := Vector2(layer_data.__gridSize, layer_data.__gridSize)

	__place_tiles(tilemap, tiles, tile_source_id, grid_size)

	return tilemap

static func __place_tiles(
		tilemap: TileMap,
		tiles: Array,
		tile_source_id: int,
		grid_size: Vector2,
		layer_index: int = 0
) -> void:

	var tile_source: TileSetAtlasSource
	if tilemap.tile_set.has_source(tile_source_id):
		tile_source = tilemap.tile_set.get_source(tile_source_id)
	else:
		push_error("TileSetAtlasSource missing")
		return

	var tile_size := Vector2(tile_source.texture_region_size)

	# Place tiles
	for tile in tiles:
		var cell_px := Vector2(tile.px[0], tile.px[1])
		var tile_px := Vector2(tile.src[0], tile.src[1])
		var cell_grid := TileUtil.px_to_grid(cell_px, grid_size, Vector2i.ZERO)
		var tile_grid := TileUtil.px_to_grid(tile_px, tile_size, Vector2i.ZERO)

		# Tile does not exist
		if not tile_source.has_tile(tile_grid):
			continue

		# Handle flipped tiles
		var alternative_count := tile_source.get_alternative_tiles_count(tile_grid)
		var alternative_tile: int = 0
		var tile_flip := int(tile.f)
		if (tile_flip != 0):
			if (alternative_count == 1):
				TileUtil.create_flipped_alternative_tiles(tilemap, tile_source, tile_grid)
				alternative_count = tile_source.get_alternative_tiles_count(tile_grid)
			if (tile_source.has_alternative_tile(tile_grid, tile_flip)):
				alternative_tile = tile_flip

		# Handle alpha
		if tile.a < 1:
			var alternative_index := 4
			var alternative_exists := false

			# Find alternate tile with same alpha
			if alternative_count > alternative_index:
				for i in range(alternative_index, alternative_count):
					var data = tile_source.get_tile_data(tile_grid, i)
					if is_equal_approx(data.modulate.a, tile.a):
						# Reverse flip bools back into an int
						var flip = int(data.flip_h) + int(data.flip_v) * 2
						if tile_flip == flip:
							alternative_index = i
							alternative_exists = true
							break

			# Create new tile
			if not alternative_exists:
				if alternative_count == 1:
					# Create flipped alternatives (this preserves alternative order)
					TileUtil.create_flipped_alternative_tiles(tilemap, tile_source, tile_grid)
					alternative_count = tile_source.get_alternative_tiles_count(tile_grid)

				alternative_index = tile_source.create_alternative_tile(tile_grid, alternative_count)
				var new_data = tile_source.get_tile_data(tile_grid, alternative_index)
				TileUtil.copy_and_modify_tile_data(
						new_data,
						tile_source.get_tile_data(tile_grid, 0),
						tilemap.tile_set.get_physics_layers_count(),
						tilemap.tile_set.get_navigation_layers_count(),
						tilemap.tile_set.get_occlusion_layers_count(),
						tile_flip
				)
				new_data.modulate.a = tile.a

			alternative_tile = alternative_index

		if not tilemap.get_cell_tile_data(layer_index, cell_grid):
			tilemap.set_cell(layer_index, cell_grid, tile_source_id, tile_grid, alternative_tile)
		elif (Util.options.allow_overlapping_tiles):
			LayerUtil.set_overlapping_tile(
					tilemap,
					layer_index,
					cell_grid,
					tile_source_id,
					tile_grid,
					alternative_tile
			)
