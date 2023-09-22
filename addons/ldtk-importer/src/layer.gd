@tool

const Util = preload("util/util.gd")
const LayerUtil = preload("util/layer-util.gd")
const TileUtil = preload("util/tile-util.gd")

static func create_layers(
		level_data: Dictionary,
		layer_dict: Dictionary,
		tilesets: Dictionary,
		definitions: Dictionary
) -> Array:

	var layer_nodes := []

	for key in layer_dict:
		# Create TileMap
		var tilemap := TileMap.new()
		tilemap.name = "Tilemaps" + str(key) + "x" + str(key)
		tilemap.cell_quadrant_size = key
		tilemap.set_texture_filter(CanvasItem.TEXTURE_FILTER_NEAREST)
		var tileset = tilesets.get(key, null)
		tilemap.tile_set = tileset
		var tile_layer_index := 0

		var layer_instances: Dictionary = layer_dict[key]
		var layer_instance_count = layer_instances.size()
		var layer_instance_keys = layer_instances.keys()

		# Add layers in reverse order
		for index in range(layer_instance_count - 1, -1, -1):
			var layer_data: Dictionary = layer_instances[layer_instance_keys[index]]
			var layer_def = definitions.layers[layer_data.layerDefUid]

			var match_data := {
				"type": layer_data.__type,
				"tileset": layer_data.get("__tilesetDefUid", null) != null
			}

			var node_created := false
			match match_data:
				{"type": "Entities", ..}:
					var entityDefs = definitions.entities
					var layer = create_entity_layer(layer_data, layer_def, entityDefs)
					layer.z_index = tile_layer_index
					layer_nodes.push_front(layer)

				{"type": "IntGrid", "tileset": false}:
					node_created = create_intgrid_layer(tilemap, tile_layer_index, layer_data, layer_def)
					if node_created: tile_layer_index += 1

				{"type": "IntGrid", "tileset": true}:
					node_created = create_intgrid_layer(tilemap, tile_layer_index, layer_data, layer_def)
					if node_created: tile_layer_index += 1
					node_created = create_tile_layer(tilemap, tile_layer_index, layer_data, layer_def)
					if node_created: tile_layer_index += 1

				{"type": "Tiles", "tileset": true}, {"type": "AutoLayer", "tileset": true}:
					node_created = create_tile_layer(tilemap, tile_layer_index, layer_data, layer_def)
					if node_created: tile_layer_index += 1

				_:
					push_warning("LDtk: Tried importing an unsupported layer type", match_data)

		layer_nodes.push_front(tilemap)

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
		tilemap: TileMap,
		tile_layer_index: int,
		layer_data: Dictionary,
		layer_def: Dictionary
) -> bool:
	# Retrieve IntGrid values - these do not always match their array index
	var values: Array = layer_def.intGridValues.map(
		func(item): return item.value
	)

	if tile_layer_index > 0:
		tilemap.add_layer(-1)

	# Set layer properties on the Tilemap
	var layer_name := str(layer_data.__identifier) + "-values"
	var layer_index := tilemap.get_layers_count() -1
	tilemap.set_layer_name(layer_index, layer_name)
	tilemap.set_layer_modulate(layer_index, Color(1, 1, 1, layer_data.__opacity))
	tilemap.set_layer_enabled(layer_index, false)

	if (Util.options.verbose_output):
		print("Creating IntGrid Layer: ", layer_name)

	# Get tile data
	var tiles: Array = layer_data.intGridCsv
	var tile_source_id: int = layer_data.layerDefUid
	var tile_source := tilemap.tile_set.get_source(tile_source_id)
	var columns: int = layer_data.__cWid

	# Place tiles
	for index in range(0, tiles.size()):
		var value = tiles[index]
		var value_index: int = values.find(value)
		if value_index != -1:
			var cell_coords := TileUtil.index_to_grid(index, columns)
			var tile_coords := Vector2i(value_index, 0)
			tilemap.set_cell(layer_index, cell_coords, tile_source_id, tile_coords)

	return true

static func create_tile_layer(
		tilemap: TileMap,
		tile_layer_index: int,
		layer_data: Dictionary,
		layer_def: Dictionary
) -> bool:
	if tile_layer_index > 0:
		tilemap.add_layer(-1)

	# Set layer properties on the Tilemap
	var layer_name := str(layer_data.__identifier)
	var layer_index := tilemap.get_layers_count() -1
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
	var tile_source: TileSetAtlasSource

	if tilemap.tile_set.has_source(tile_source_id):
		tile_source = tilemap.tile_set.get_source(tile_source_id)
	else:
		push_error("TileSetAtlasSource missing")
		return false

	var tile_size := Vector2i(tile_source.texture_region_size)

	var grid_size := Vector2i(layer_data.__gridSize, layer_data.__gridSize)
	var grid_offset := Vector2i(layer_data.__pxTotalOffsetX, layer_data.__pxTotalOffsetY)

	# Place tiles
	for tile in tiles:
		var cell_px := Vector2i(tile.px[0], tile.px[1])
		var tile_px := Vector2i(tile.src[0], tile.src[1])
		var cell_grid := TileUtil.px_to_grid(cell_px, grid_size, grid_offset)
		var tile_grid := TileUtil.px_to_grid(tile_px, tile_size, Vector2i.ZERO)

		# Tile does not exist
		if not tile_source.has_tile(tile_grid):
			continue

		# Handle flipped tiles
		var alternative_tile: int = 0
		var tile_flip := int(tile.f)
		if (tile_flip != 0):
			if (tile_source.get_alternative_tiles_count(tile_grid) == 1):
				# Create full set of alternative tiles for this tile
				for i in range(1,4):
					var new_tile = tile_source.create_alternative_tile(tile_grid, i)
					var tile_data = tile_source.get_tile_data(tile_grid, new_tile)
					match i:
						1: # Flip X
							tile_data.set_flip_h(true)
						2: # Flip Y
							tile_data.set_flip_v(true)
						3: # Flip Both
							tile_data.set_flip_h(true)
							tile_data.set_flip_v(true)

			if (tile_source.has_alternative_tile(tile_grid, tile_flip)):
				alternative_tile = tile_flip

		tilemap.set_cell(tile_layer_index, cell_grid, tile_source_id, tile_grid, alternative_tile)

	return true
