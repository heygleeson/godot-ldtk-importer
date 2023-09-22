@tool

const Util = preload("util.gd")
const TileUtil = preload("tile-util.gd")

static var hitUnresolved := false

static func create_fields(fields: Array, entity: Variant = null) -> Dictionary:
	var dict := {}

	for field in fields:
		var key: String = field.__identifier
		dict[key] = parse_field(field)
		if hitUnresolved:
			if dict[key] is Array:
				for index in range(dict[key].size()):
					Util.add_unresolved_reference(dict[key], index, entity)
			else:
				Util.add_unresolved_reference(dict, key, entity)
			hitUnresolved = false

	return dict

static func parse_field(field: Dictionary) -> Variant:
	var value: Variant = field.__value
	if value == null:
		return null

	var type := field.__type as String

	# Handle Enum String
	var localEnum: String
	if type.contains("LocalEnum"):
		var regex = RegEx.new()
		regex.compile("(?<=\\.)\\w+")
		localEnum = regex.search(type).get_string()

		if type.begins_with("Array"):
			type = "Array<LocalEnum>"
		else:
			type = "LocalEnum"

	# Match Field Type
	match type:
		"Int":
			return int(value) as int
		"Color":
			return Color.from_string(value, Color.MAGENTA) as Color
		"Point":
			return __parse_point(value.cx, value.cy) as Vector2
		"Tile":
			return __parse_tile(value) as AtlasTexture
		"EntityRef":
			hitUnresolved = true
			return value.entityIid as String
		"LocalEnum":
			return __parse_enum(localEnum, value) as String
		# ------------------------------------------------------------------- #
		"Array<Int>":
			return value
		"Array<Color>":
			return value.map(
				func (color):
					return Color.from_string(color, Color.MAGENTA)
			)
		"Array<Point>":
			return value.map(
				func (point):
					return Vector2i(point.cx, point.cy)
			)
		"Array<Tile>":
			return value.map(
				func(tile) -> AtlasTexture:
					return __parse_tile(tile)
			)
		"Array<EntityRef>":
			hitUnresolved = true
			return value.map(
				func (ref) -> String:
					return ref.entityIid
			)
		"Array<LocalEnum>":
			var enums: Array[String] = []
			for index in range(value.size()):
				var parsed_enum = __parse_enum(localEnum, value[index])
				enums.append(parsed_enum)
			return enums
		_:
			return value

static func __parse_point(x: int, y: int) -> Vector2:
	# NOTE: would convert gridcoords to pixelcoords here, but needs more data
	# LDTKEntity currently converts it using LayerDefinition.
	return Vector2(x,y)

static func __parse_enum(enum_str: String, value: String) -> String:
	var result: String = "%s.%s" % [enum_str, value]
	return result

static func __parse_tile(value: Dictionary) -> AtlasTexture:
	var texture := AtlasTexture.new()
	var atlas: TileSetAtlasSource = Util.tilemap_refs[int(value.tilesetUid)]

	if atlas == null:
		push_error("Could not find atlas ", value.tilesetUid, ", returning empty texture")
		return texture

	texture.atlas = atlas.texture

	var coords = TileUtil.px_to_grid(
			Vector2i(value.x, value.y),
			atlas.texture_region_size,
			atlas.margins,
			atlas.separation
	)
	texture.region = atlas.get_tile_texture_region(coords) as Rect2i
	return texture
