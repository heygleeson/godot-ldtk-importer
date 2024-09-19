@tool

const Util = preload("util/util.gd")
const TileUtil = preload("util/tile-util.gd")
const FieldUtil = preload("util/field-util.gd")
const PostImport = preload("post-import.gd")

enum AtlasTextureType {CompressedTexture2D, CanvasTexture}

static func build_tilesets(
		definitions: Dictionary,
		base_dir: String,
		tileset_overrides: Dictionary
) -> Array:
	Util.timer_start(Util.DebugTime.TILES)
	var tilesets := {}
	var tileset_sources := {}

	# Reduce Layer Defs to find all unique layer grid sizes and create TileSets for each.
	var layer_def_uids: Array = definitions.layers.keys()

	tilesets = layer_def_uids.reduce(
		func(accum: Dictionary, current: float):
			var layer_def = definitions.layers[current]
			var grid_size: int = layer_def.gridSize

			if not accum.has(grid_size):
				accum[grid_size] = get_tileset(grid_size, base_dir)

			# Create TileSetSource for IntGrids
			if (Util.options.integer_grid_tilesets):
				if layer_def.type == "IntGrid" and layer_def.intGridValues.size() > 0:
					var intgrid_uid = layer_def.uid
					var intgrid_source = create_intgrid_source(layer_def)
					tileset_sources[intgrid_uid] = intgrid_source
					Util.add_tileset_reference(intgrid_uid, intgrid_source)
			return accum
	, tilesets)

	# Create TileSetSources for each Tileset Def
	var tileset_def_uids = definitions.tilesets.keys()
	for uid in tileset_def_uids:
		var tileset_def: Dictionary = definitions.tilesets[uid]
		var source: TileSetSource = create_new_tileset_source(tileset_def, base_dir)
		tileset_sources[uid] = source
		Util.add_tileset_reference(tileset_def.uid, source)

	# Add TileSetSources to TileSets
	# NOTE: We also add Sources to mismatched TileSet sizes (if a layer uses that TilesetDef as an override)
	for id in tilesets.keys():
		var tileset: TileSet = tilesets[id]
		var size: int = tileset.tile_size.x

		for uid in tileset_sources.keys():
			var source: TileSetAtlasSource = tileset_sources[uid]
			if source == null: continue
			var source_size: int = source.texture_region_size.x

			# Check if override exists.
			var has_override: bool = false
			if (tileset_overrides.has(size)):
				if (tileset_overrides[size].has(int(uid))):
					has_override = true

			# Include Source if size matches grid (or is an override found for this grid size)
			if size == source_size or has_override:
				if tileset.has_source(uid):
					source = tileset.get_source(uid)
				else:
					source = source.duplicate()
					tileset.add_source(source, uid)

				if (Util.options.tileset_custom_data):
					if definitions.tilesets.has(uid):
						var tileset_def: Dictionary = definitions.tilesets[uid]
						add_tileset_custom_data(tileset_def, tileset, source, tileset_def.__cWid)

	# Post-Import
	if (Util.options.tileset_post_import):
		tilesets = PostImport.run_tileset_post_import(tilesets, Util.options.tileset_post_import)

	# Store tilesets in Util
	Util.tilesets = tilesets

	Util.timer_finish("Tilesets Created", 1)

	# Save tilesets
	Util.timer_start(Util.DebugTime.SAVE)
	var files = save_tilesets(tilesets, base_dir)
	Util.timer_finish("Tilesets Saved", 1)

	for key in tilesets.keys():
		# reload tileset (improves performance)
		var tileset = tilesets[key]
		if tileset == null: continue
		if not files.has(key): continue
		tilesets[key] = ResourceLoader.load(files[key])

	return files.values()

static func get_tileset(tile_size: int,base_dir: String) -> TileSet:
	var tileset_name := "tileset_%spx" % [str(tile_size)]
	var path := base_dir + "tilesets/" + tileset_name + ".res"

	if not (Util.options.force_tileset_reimport):
		if ResourceLoader.exists(path):
			var tileset = ResourceLoader.load(path)
			if tileset is TileSet:
				return tileset

	# Create new TileSet
	var tileset := TileSet.new()
	tileset.resource_name = tileset_name
	tileset.tile_size = Vector2i(tile_size, tile_size)

	if (Util.options.verbose_output):
		Util.print("item_info", "Created new TileSet: \"%s\"" % [tileset_name], 1)

	return tileset

# Create an AtlasSource using tileset definition
static func create_new_tileset_source(definition: Dictionary, base_dir: String) -> TileSetSource:
	# No source texture defined
	if definition.relPath == null:
		Util.print("item_fail", "No texture defined for tileset '%s'" % [definition.identifier])
		push_error("Tileset Definition '%s' has no source texture. Please fix this in your LDtk project file." % [definition.identifier])
		return null

	# Check if relPath is an absolute directory
	var filepath: String
	if definition.relPath.contains(":"):
		push_warning("Absolute path detected for texture resource '%s'. This is not recommended. Please include this file in the Godot project." % [definition.identifier])
		filepath = definition.relPath
	else:
		filepath = base_dir + definition.relPath

	var texture := load(filepath)

	# Cannot load texture
	if texture == null:
		push_error("Cannot access source texture: %s. Please include this file in the Godot project." % [filepath])
		return null

	var image: Image = texture.get_image()

	# Convert texture from CompressedTexture2D to CanvasTexture
	if (Util.options.atlas_texture_type == AtlasTextureType.CanvasTexture):
		var canvas_texture = CanvasTexture.new()
		canvas_texture.diffuse_texture = texture
		texture = canvas_texture

	var tile_size: int = definition.gridSize
	var margin: int = definition.padding
	var separation: int = definition.spacing
	var grid_w: int = definition.__cWid
	var grid_h: int = definition.__cHei

	var source := TileSetAtlasSource.new()

	# Apply TileSet properties
	if source.texture == null or source.texture.get_class() != texture.get_class():
		source.texture = texture

	source.resource_name = definition.identifier
	source.margins = Vector2i(margin, margin)
	source.separation = Vector2i(separation, separation)
	source.texture_region_size = Vector2(tile_size, tile_size)
	source.use_texture_padding = false

	# Create/remove tiles in non-empty/empty cells.
	for y in range(0, grid_h):
		for x in range(0, grid_w):
			var coords := Vector2i(x,y)
			var tile_region := TileUtil.get_tile_region(coords, tile_size, margin, separation, grid_w)
			var tile_image := image.get_region(tile_region)

			if not tile_image.is_invisible():
				if source.get_tile_at_coords(coords) == Vector2i(-1,-1):
					source.create_tile(coords)
				elif not source.get_tile_at_coords(coords) == Vector2i(-1,-1):
					# TODO: Make this an import flag
					source.remove_tile(coords)

	# Add definition UID to references
	Util.add_tileset_reference(definition.uid, source)

	return source

static func add_tileset_custom_data(
		definition: Dictionary,
		tileset: TileSet,
		source: TileSetAtlasSource,
		grid_w: int
) -> void:

	if not definition.has("enumTags"):
		return

	var customData: Array = definition.customData
	var custom_name: String = "LDTK Custom"
	clear_custom_data(tileset, custom_name)

	if not customData.is_empty():
		ensure_custom_layer(tileset, custom_name)
		for entry in customData:
			var coords := TileUtil.tileid_to_grid(entry.tileId, grid_w)
			var tile_data: TileData = source.get_tile_data(coords, 0)
			if not tile_data == null:
				tile_data.set_custom_data(custom_name, entry.data)

	var custom_enum_name: String = "LDTK Custom Enum"
	clear_custom_data(tileset, custom_enum_name)

	var enumTags: Array = definition.enumTags
	if not enumTags.is_empty():
		ensure_custom_layer(tileset, custom_enum_name, TYPE_ARRAY)

		for enumTag in enumTags:
			for tileId in enumTag.tileIds:
				var coords := TileUtil.tileid_to_grid(tileId, grid_w)
				var tile_data: TileData = source.get_tile_data(coords, 0)
				if not tile_data == null:
					# Add to already existing tags
					var tile_tags: Array = tile_data.get_custom_data(custom_enum_name)
					tile_tags.append(enumTag.enumValueId)
					tile_data.set_custom_data(custom_enum_name, tile_tags)

# Ensure custom data layer exists by name
static func ensure_custom_layer(
		tileset: TileSet,
		layer_name: String,
		layer_type: int = TYPE_STRING
) -> void:
	if tileset.get_custom_data_layer_by_name(layer_name) != -1:
		return
	var index_to_add = tileset.get_custom_data_layers_count()
	tileset.add_custom_data_layer(index_to_add)
	tileset.set_custom_data_layer_name(index_to_add, layer_name)
	tileset.set_custom_data_layer_type(index_to_add, layer_type)

# Clear custom data by layer name
static func clear_custom_data(tileset: TileSet, layer_name: String) -> void:
	var layer = tileset.get_custom_data_layer_by_name(layer_name)
	if layer == -1:
		return
	tileset.remove_custom_data_layer(layer)

# Create an AtlasSource from IntGrid data
static func create_intgrid_source(definition: Dictionary) -> TileSetAtlasSource:
	var values: Array = definition.intGridValues
	var grid_size: int = definition.gridSize

	# Create texture from IntGrid values
	var width := grid_size * values.size()
	var height := grid_size
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)

	for index in range(0, values.size()):
		var value: Dictionary = values[index]
		var rect := Rect2i(index * grid_size, 0, grid_size, grid_size)
		var color := Color.from_string(value.color, Color.MAGENTA)
		image.fill_rect(rect, color)

	var texture = ImageTexture.create_from_image(image)

	var source := TileSetAtlasSource.new()
	source.resource_name = definition.identifier + "_Tiles"
	source.texture = texture
	source.texture_region_size = Vector2i(grid_size, grid_size)

	# Create tiles
	for index in range(0, values.size()):
		var coords := Vector2i(index, 0)
		if not source.has_tile(coords):
			source.create_tile(coords)

	return source

# Save TileSets as Resources
static func save_tilesets(tilesets: Dictionary, base_dir: String) -> Dictionary:
	var save_path = base_dir + "tilesets/"
	var gen_files := {}
	var directory = DirAccess.open(base_dir)
	if not directory.dir_exists(save_path):
		directory.make_dir_recursive(save_path)

	var tileset_names = tilesets.values().map(func(elem): return elem.resource_name)
	Util.print("item_save", "Saving Tilesets: [color=#fe8019]%s[/color]" % [tileset_names], 1)

	for key in tilesets.keys():
		var tileset: TileSet = tilesets.get(key)
		if tileset.get_source_count() == 0:
			continue

		var file_name = tileset.resource_name
		var file_path = "%s%s.%s" % [save_path, file_name, "res"]
		var err = ResourceSaver.save(tileset, file_path)
		if err == OK:
			gen_files[key] = file_path

	return gen_files

static func get_entity_def_tiles(definitions: Dictionary, tilesets: Dictionary) -> Dictionary:
	# TODO: Loop through EntityDefs, and turn 'Tile' into an Image.
	for def in definitions.entities:
		var entity: Dictionary = definitions.entities[def]
		if (entity.tile == null):
			continue
		# Find associated TileSet
		var texture = FieldUtil.__parse_tile(entity.tile)
		entity.tile = texture

	return definitions

# Collect all layer tileset overrides. Later we'll ensure these sources are included in TileSet resources.
static func get_tileset_overrides(world_data: Dictionary) -> Dictionary:
	var overrides := {}
	for level in world_data.levels:
		for layer in level.layerInstances:
			if layer.overrideTilesetUid == null:
				continue
			var gridSize: int = layer.__gridSize
			var overrideUid: int = layer.overrideTilesetUid
			if overrideUid != null:
				if not overrides.has(gridSize):
					overrides[gridSize] = []
				var gridsize_overrides: Array = overrides[gridSize]
				if not gridsize_overrides.has(overrideUid):
					gridsize_overrides.append(overrideUid)
	return overrides
