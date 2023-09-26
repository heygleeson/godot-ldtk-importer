@tool

static func build_definitions(world_data: Dictionary) -> Dictionary:
	var definitions := {
		"enums": resolve_enum_definitions(world_data.defs.enums),
		"entities": resolve_entity_definitions(world_data.defs.entities),
		"layers": resolve_layer_definitions(world_data.defs.layers),
		"tilesets": resolve_tileset_definitions(world_data.defs.tilesets),
		"level_fields": resolve_level_field_definitions(world_data.defs.levelFields),
	}
	return definitions

static func resolve_layer_definitions(layer_defs: Array) -> Dictionary:
	var resolved_layer_defs := {}

	for layer_def in layer_defs:
		resolved_layer_defs[layer_def.uid] = {
			"uid": layer_def.uid,
			"type": layer_def.type,
			"identifier": layer_def.identifier,
			"gridSize": layer_def.gridSize,
			"offset": Vector2i(layer_def.pxOffsetX, layer_def.pxOffsetY),
			"parallax": Vector2(layer_def.parallaxFactorX, layer_def.parallaxFactorY),
			"parallaxScaling": layer_def.parallaxScaling,
			"intGridValues": layer_def.intGridValues
		}

	return resolved_layer_defs

static func resolve_entity_definitions(entity_defs: Array) -> Dictionary:
	var resolved_entity_defs := {}

	for entity_def in entity_defs:
		resolved_entity_defs[entity_def.uid] = {
			"identifier": entity_def.identifier,
			"color": Color.from_string(entity_def.color, Color.MAGENTA),
			"renderMode": entity_def.renderMode,
			"hollow": entity_def.hollow,
			"tags": entity_def.tags,
			"field_defs": resolve_entity_field_defs(entity_def.fieldDefs)
		}

	return resolved_entity_defs

static func resolve_entity_field_defs(field_defs: Array) -> Dictionary:
	var resolved_entity_field_defs := {}

	for field_def in field_defs:
		resolved_entity_field_defs[int(field_def.uid)] = {
			"identifier": field_def.identifier,
			"type": field_def.__type,
		}

	return resolved_entity_field_defs

static func resolve_tileset_definitions(tileset_defs: Array) -> Dictionary:
	var resolved_tileset_defs := {}

	for tileset_def in tileset_defs:
		resolved_tileset_defs[tileset_def.uid] = {
			"uid": tileset_def.uid,
			"identifier": tileset_def.identifier,
			"relPath": tileset_def.relPath,
			"gridSize": tileset_def.tileGridSize,
			"pxWid": tileset_def.pxWid,
			"pxHei": tileset_def.pxHei,
			"spacing": tileset_def.spacing,
			"padding": tileset_def.padding,
			"tags": tileset_def.tags,
			"enumTagUid": tileset_def.tagsSourceEnumUid,
			"enumTags": tileset_def.enumTags,
			"customData": tileset_def.customData
		}

	return resolved_tileset_defs

static func resolve_enum_definitions(enum_defs: Array) -> Dictionary:
	var resolved_enum_defs := {}

	for enum_def in enum_defs:
		var uid = enum_def.uid
		var values := []
		for value in enum_def.values:
			values.append({
				"value": value.id,
				"color": Color.from_string(str(value.color), Color.MAGENTA),
				"tileRect": value.tileRect
			})
		resolved_enum_defs[uid] = values

	return resolved_enum_defs

static func resolve_level_field_definitions(level_field_defs: Array) -> Dictionary:
	var resolved_level_field_defs := {}

	for level_field_def in level_field_defs:
		resolved_level_field_defs[level_field_def.uid] = {
			"identifier": level_field_def.identifier,
			"type": level_field_def.__type
		}

	return resolved_level_field_defs
