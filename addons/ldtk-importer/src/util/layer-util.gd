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
	return entities.map(
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
	var placeholder: LDTKEntity = EntityPlaceHolder.instantiate()
	var count: int = __placeholder_count(data.identifier)
	placeholder.name = data.identifier

	if count > 1:
		placeholder.name += str(count)

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

static func create_layer_tilemap(layer_data: Dictionary) -> TileMapLayer:
	var grid_size = int(layer_data.__gridSize)

	var tilemap := TileMapLayer.new()
	tilemap.name = layer_data.__identifier
	tilemap.tile_set = Util.tilesets.get(grid_size, null)
	var offset = Vector2(layer_data.__pxTotalOffsetX, layer_data.__pxTotalOffsetY)
	tilemap.position = offset

	return tilemap

static func create_tilemap_child(tilemap: TileMapLayer) -> TileMapLayer:
	var child := TileMapLayer.new()
	var count := tilemap.get_child_count() + 1
	child.name = tilemap.name + str(count)
	child.tile_set = tilemap.tile_set
	return child
