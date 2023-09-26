@tool

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

