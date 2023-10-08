@tool

const Util = preload("util.gd")
const EntityPlaceHolder = preload("../components/ldtk-entity.tscn")
const FieldUtil = preload("field-util.gd")

# Counter reset per level, used when creating EntityPlacholders
static var placeholder_counts := {}

static func parse_entity_instances(
		entities: Array,
		entity_defs: Dictionary,
		pathResolver: Node2D
) -> Array:

	return 	entities.map(
		func(entity):
			var definition = entity_defs[entity.defUid]
			return {
				"iid": entity.iid,
				"identifier": entity.__identifier,
				"smart_color": Color.from_string(entity.__smartColor, Color.WHITE),
				"size": Vector2i(entity.width, entity.height),
				"position": Vector2i(entity.px[0], entity.px[1]),
				"pivot": Vector2(entity.__pivot[0], entity.__pivot[1]),
				"fields": FieldUtil.create_fields(entity.fieldInstances, pathResolver),
				"definition": definition,
			}
	)

static func create_entity_placeholder(layer: Node2D, data: Dictionary) -> LDTKEntity:
	var placeholder = EntityPlaceHolder.instantiate()

	var count = __placeholder_count(data.identifier)

	if count > 1:
		placeholder.name = data.identifier + str(count)
	else:
		placeholder.name = data.identifier

	# Set properties
	for prop in data.keys():
		placeholder[prop] = data[prop]

	layer.add_child(placeholder)
	return placeholder

static func __placeholder_count(name: String) -> int:
	if not name in placeholder_counts:
		placeholder_counts[name] = 1
	else:
		placeholder_counts[name] += 1
	return placeholder_counts[name]

static func create_layer_tilemap(layer_data: Dictionary) -> TileMap:
	var grid_size = int(layer_data.__gridSize)

	var tilemap := TileMap.new()
	tilemap.name = layer_data.__identifier
	tilemap.set_texture_filter(CanvasItem.TEXTURE_FILTER_NEAREST)
	tilemap.tile_set = Util.tilesets.get(grid_size, null)
	var offset = Vector2(layer_data.__pxTotalOffsetX, layer_data.__pxTotalOffsetY)
	tilemap.position = offset

	return tilemap

static func set_overlapping_tile(
		tilemap : TileMap,
		layer_index: int,
		cell_grid: Vector2i,
		tile_source_id: int,
		tile_grid: Vector2i,
		alternative_tile: int,
) -> void:

	var base_name: String = tilemap.get_layer_name(layer_index)
	var layer_count: int = tilemap.get_layers_count()

	# Get similar layers, sorted by z index
	var similar_layers := []
	for i in range(layer_count):
		if tilemap.get_layer_name(i) == base_name:
			similar_layers.append(i)

	similar_layers.sort_custom(
		func(a,b):
			return tilemap.get_layer_z_index(a) < tilemap.get_layer_z_index(b)
	)

	var found_empty := false
	for i in similar_layers:
		if not tilemap.get_cell_tile_data(i, cell_grid):
			tilemap.set_cell(i, cell_grid, tile_source_id, tile_grid, alternative_tile)
			found_empty = true
			break

	if not found_empty:
		var highest_z = tilemap.get_layer_z_index(similar_layers[-1])
		# Create new layer
		tilemap.add_layer(-1)
		var new_index = layer_count
		tilemap.set_layer_name(new_index, base_name)
		tilemap.set_layer_z_index(new_index, highest_z)
		tilemap.set_layer_modulate(new_index, tilemap.get_layer_modulate(layer_index))
		# Set cell
		tilemap.set_cell(new_index, cell_grid, tile_source_id, tile_grid, alternative_tile)

