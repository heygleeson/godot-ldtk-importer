@tool

const EntityPlaceHolder = preload("../components/ldtk-entity.tscn")
const FieldUtil = preload("field-util.gd")

# Counter reset per level, used when creating EntityPlacholders
static var placeholder_counts := {}

static func get_layer_definition(layer_def_uid: int, world_data: Dictionary) -> Dictionary :
	for layer_def in world_data.defs.layers:
		if layer_def.uid == layer_def_uid:
			return {
				"type": layer_def.type,
				"identifier": layer_def.identifier,
				"uid": layer_def.uid,
				"gridSize": layer_def.gridSize,
				"offset": Vector2i(layer_def.pxOffsetX, layer_def.pxOffsetY),
				"parallax": Vector2(layer_def.parallaxFactorX, layer_def.parallaxFactorY),
				"parallaxScaling": layer_def.parallaxScaling,
				"tilePivot": Vector2i(layer_def.tilePivotX, layer_def.tilePivotY),
				"intGridValues": layer_def.intGridValues
			}

	# Return Empty
	return {}

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

	# Set Properties
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

