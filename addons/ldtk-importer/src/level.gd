@tool

const Util = preload("util/util.gd")
const LevelUtil = preload("util/level-util.gd")
const FieldUtil = preload("util/field-util.gd")

const Layer = preload("layer.gd")

static var base_directory: String

static func build_levels(
		world_data: Dictionary,
		definitions: Dictionary,
		tilesets: Dictionary,
		base_dir: String
) -> Array:

	base_directory = base_dir
	var levels := []

	# Calculate Level Positions (for Linear layouts)
	var level_positions : Array
	match world_data.worldLayout:
		"LinearHorizontal":
			var x = 0
			for level in world_data.levels:
				level_positions.append(Vector2i(x, 0))
				x += level.pxWid
		"LinearVertical":
			var y = 0
			for level in world_data.levels:
				level_positions.append(Vector2i(0, y))
				y += level.pxHei
		"GridVania", "Free":
			level_positions = world_data.levels.map(
				func (current):
					return Vector2i(current.worldX, current.worldY)
			)
		_:
			printerr("World Layout not supported: ", world_data.worldLayout)

	var external_levels = world_data.externalLevels

	# Create Levels
	for level_index in range(world_data.levels.size()):
		var level_data
		var position: Vector2i = level_positions[level_index]
		level_data = world_data.levels[level_index]

		if external_levels:
			level_data = LevelUtil.get_external_level(level_data, base_dir)

		var level = create_level(level_data, position, tilesets, definitions)
		levels.append(level)

	return levels

static func create_level(
		level_data: Dictionary,
		position: Vector2i,
		tilesets: Dictionary,
		definitions: Dictionary
) -> LDTKLevel:

	if (Util.options.verbose_output):
		print("\n=== LEVEL: %s ===" % [level_data.identifier])

	var level_name = level_data.identifier
	var level = LDTKLevel.new()
	level.name = level_name
	level.position = position
	level.size = Vector2i(level_data.pxWid, level_data.pxHei)
	level.bg_color = level_data.__bgColor
	level.z_index = level_data.worldDepth

	Util.update_instance_reference(level_data.iid, level)

	# Get neighbours (handle levelIid references)
	var neighbours = level_data.__neighbours
	for neighbour in neighbours:
		Util.add_unresolved_reference(neighbour, "levelIid", level)
	level.neighbours = neighbours

	# Create Background Image
	if level_data.bgRelPath != null:
		var path = "%s/%s" % [base_directory, level_data.bgRelPath]
		var sprite = Sprite2D.new()
		sprite.name = "BG Image"
		sprite.centered = false
		sprite.texture = load(path)
		level.add_child(sprite)

	# Create Fields
	level.fields = FieldUtil.create_fields(level_data.fieldInstances, level)

	# Combine layers with same grid size.
	var layer_instances = level_data.layerInstances
	if not layer_instances is Array:
		push_error("level '%s' has no layer instances." % [level_name])
		return level

	var layer_dict: Dictionary = layer_instances.reduce(
		func (accum, current):
			var grid_size: int = current.__gridSize
			if accum.get(grid_size) == null:
				accum[grid_size] = {}
			accum[grid_size][int(current.layerDefUid)] = current
			return accum
	, {})

	# Create Layers
	var layers = Layer.create_layers(level_data, layer_dict, tilesets, definitions)
	for layer in layers:
		level.add_child(layer)

	return level
