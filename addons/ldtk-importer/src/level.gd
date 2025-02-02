@tool

const Util = preload("util/util.gd")
const LevelUtil = preload("util/level-util.gd")
const FieldUtil = preload("util/field-util.gd")
const PostImport = preload("post-import.gd")
const Layer = preload("layer.gd")

static var base_directory: String

static func build_levels(
		world_data: Dictionary,
		definitions: Dictionary,
		base_dir: String,
		external_levels: bool
) -> Array[LDTKLevel]:

	Util.timer_start(Util.DebugTime.GENERAL)
	base_directory = base_dir
	var levels: Array[LDTKLevel] = []

	# Calculate level positions
	var level_positions: Array
	match world_data.worldLayout:
		"LinearHorizontal":
			var x = 0
			for level in world_data.levels:
				level_positions.append(Vector2i(x, 0))
				x += level.pxWid
		"LinearVertical":
			var y := 0
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

	# Create levels
	for level_index in range(world_data.levels.size()):
		Util.timer_start(Util.DebugTime.GENERAL)
		var level_data
		var position: Vector2i = level_positions[level_index]
		level_data = world_data.levels[level_index]

		if external_levels:
			level_data = LevelUtil.get_external_level(level_data, base_dir)

		var level = create_level(level_data, position, definitions)
		Util.timer_finish("Built Level", 2)

		if (Util.options.entities_post_import):
			level = PostImport.run_entity_post_import(level, Util.options.entities_post_import)

		if (Util.options.level_post_import):
			level = PostImport.run_level_post_import(level, Util.options.level_post_import)

		levels.append(level)

	Util.timer_finish("Built %s Levels" % levels.size(), 1)
	return levels

enum BackgroundMode {
	UNSCALED,
	COVER_DIRTY,
	COVER,
	REPEAT,
	FIT_INSIDE
}

static func get_background_mode(mode_str: String) -> BackgroundMode:
	match mode_str:
		"Unscaled":
			return BackgroundMode.UNSCALED
		"CoverDirty":
			return BackgroundMode.COVER_DIRTY
		"Cover":
			return BackgroundMode.COVER
		"Repeat":
			return BackgroundMode.REPEAT
		"FitInside":
			return BackgroundMode.FIT_INSIDE
		_:
			push_error("Unknown background mode: %s" % mode_str)
			return BackgroundMode.FIT_INSIDE

static func setup_background_sprite(
	sprite: Sprite2D,
	level: LDTKLevel,
	bg_mode: String,
	texture_size: Vector2,
	bg_data: Dictionary
) -> void:
	var mode := get_background_mode(bg_mode)
	var level_size := Vector2(level.size)
	
	# Extract positioning data
	var pos: Array = bg_data.topLeftPx
	var ldtk_scale: Array = bg_data.scale
	var crop: Array = bg_data.cropRect
	
	# Base setup
	sprite.centered = false
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	sprite.region_enabled = true
	
	match mode:
		BackgroundMode.REPEAT:
			sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			sprite.scale = Vector2.ONE
			sprite.position = Vector2.ZERO
			# Use level dimensions for region rect in repeat mode
			sprite.region_rect = Rect2(Vector2.ZERO, level_size)
			
		_:  # All other modes
			# Apply the initial position and crop from LDTK
			sprite.position = Vector2(pos[0], pos[1])
			sprite.region_rect = Rect2(crop[0], crop[1], crop[2], crop[3])
			
			match mode:
				BackgroundMode.UNSCALED:
					sprite.scale = Vector2(ldtk_scale[0], ldtk_scale[1])
					
				BackgroundMode.FIT_INSIDE:
					var scale := level_size.x / texture_size.x
					sprite.scale = Vector2(scale, scale)
					
				BackgroundMode.COVER:
					var scale_x := level_size.x / texture_size.x
					var scale_y := level_size.y / texture_size.y
					var scale := maxf(scale_x, scale_y)
					sprite.scale = Vector2(scale, scale)
					
				BackgroundMode.COVER_DIRTY:
					sprite.scale = Vector2(
						level_size.x / texture_size.x,
						level_size.y / texture_size.y
					)

static func create_level(
		level_data: Dictionary,
		position: Vector2i,
		definitions: Dictionary
) -> LDTKLevel:
	var level_name: String = level_data.identifier
	var level := LDTKLevel.new()
	level.name = level_name
	level.iid = level_data.iid
	level.world_position = position
	level.size = Vector2i(level_data.pxWid, level_data.pxHei)
	level.bg_color = level_data.__bgColor
	level.z_index = level_data.worldDepth

	if (Util.options.verbose_output): Util.print("block", level_name, 1)
	Util.update_instance_reference(level_data.iid, level)

	var neighbours = level_data.__neighbours

	if not Util.options.pack_levels:
		for neighbour in neighbours:
			Util.add_unresolved_reference(neighbour, "levelIid", level)

	level.neighbours = neighbours

	# Create background image
	if level_data.bgRelPath != null:
		var path := "%s/%s" % [base_directory, level_data.bgRelPath]
		var sprite := Sprite2D.new()
		sprite.name = "BG Image"
		sprite.texture = load(path)
		var texture_size := sprite.texture.get_size()
		setup_background_sprite(
			sprite,
			level,
			level_data.bgPos,
			texture_size,
			level_data.__bgPos
		)
		level.add_child(sprite)

	# Create fields
	level.fields = FieldUtil.create_fields(level_data.fieldInstances, level)

	var layer_instances = level_data.layerInstances
	if not layer_instances is Array:
		push_error("level '%s' has no layer instances." % [level_name])
		return level

	# Create layers
	var layers = Layer.create_layers(level_data, layer_instances, definitions)
	for layer in layers:
		level.add_child(layer)

	return level
