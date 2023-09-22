@tool

const Util = preload("util/util.gd")
const TileUtil = preload("util/tile-util.gd")
const PostImport = preload("post-import.gd")

enum AtlasTextureType {CompressedTexture2D, CanvasTexture}

static func build_tilesets(
		definitions: Dictionary,
		base_dir: String
) -> Dictionary:

	# Create Tileset for each unique grid size
	var tileset_def_uids = definitions.tilesets.keys()

	var tilesets = tileset_def_uids.reduce(
		func(accum: Dictionary, current: float):
			var tileset_def = definitions.tilesets[current]
			var grid_size: int = tileset_def.gridSize
			if not accum.has(grid_size):
				accum[grid_size] = get_tileset(grid_size, base_dir)
			var source: TileSetSource = create_tileset_source(
					tileset_def,
					accum[grid_size],
					base_dir
			)

			if source == null:
				push_warning("TileSetSource creation failed!")
			elif source.texture == null:
				push_warning("TileSetSource Texture failed")

			return accum
	, {})

	# Add Tilesets for IntGrids
	var layer_def_uids = definitions.layers.keys()

	tilesets = layer_def_uids.reduce(
		func(accum: Dictionary, current: float):
			var layer_def = definitions.layers[current]
			if layer_def.type == "IntGrid" and layer_def.intGridValues.size() > 0:
				var grid_size: int = layer_def.gridSize
				if not accum.has(grid_size):
					accum[grid_size] = get_tileset(grid_size, base_dir)
				create_intgrid_source(layer_def, accum[grid_size])
			return accum
	, tilesets)

	# Post-Import
	if (Util.options.tileset_post_import):
		if (Util.options.verbose_output):
			print("\n::POST-IMPORT Tilesets")
		tilesets = PostImport.run(tilesets, Util.options.tileset_post_import)

	return tilesets

static func get_tileset(
		tile_size: int,
		base_dir: String
) -> TileSet:

	var tileset_name = "tileset" + str(tile_size) + "x" + str(tile_size)
	var path: String = base_dir + "tilesets/" + tileset_name + ".res"

	if not (Util.options.force_tileset_reimport):
		if ResourceLoader.exists(path):
			var tileset = ResourceLoader.load(path)
			if tileset is TileSet:
				if (Util.options.verbose_output):
					print("Found TileSet: ", path)
				return tileset

	# Create new tileset
	var tileset := TileSet.new()
	tileset.resource_name = tileset_name
	tileset.tile_size = Vector2i(tile_size, tile_size)

	if (Util.options.verbose_output):
		print("Built new tileset: ", tileset_name)

	return tileset

# Create an AtlasSource using tileset definition
static func create_tileset_source(
		definition: Dictionary,
		tileset: TileSet,
		base_dir: String
) -> TileSetSource:

	# Get tileset texture
	if definition.relPath == null:
		return null

	var filepath: String = base_dir + definition.relPath
	var texture := load(filepath)
	if texture == null:
		return null

	var image: Image = texture.get_image()

	var tile_size: int = definition.gridSize
	var margin = definition.padding
	var separation = definition.spacing
	var grid_w: int = (definition.pxWid - margin) / (tile_size + separation)
	var grid_h: int = (definition.pxHei - margin) / (tile_size + separation)

	var source: TileSetAtlasSource

	# Check if AtlasSource already exists on TileSet
	if tileset.has_source(definition.uid):
		source = tileset.get_source(definition.uid)
	else:
		source = TileSetAtlasSource.new()
		if (Util.options.verbose_output):
			print("Adding source: %s on tileset %s" % [definition.uid, tileset.resource_name])
		tileset.add_source(source, definition.uid)

	# Convert texture from CompressedTexture2D to CanvasTexture
	if (Util.options.atlas_texture_type == AtlasTextureType.CanvasTexture):
		var canvas_texture = CanvasTexture.new()
		canvas_texture.diffuse_texture = texture
		texture = canvas_texture

	# Update Properties
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
				#source.remove_tile(coords)
				pass

	# Add custom data to tiles
	if (Util.options.tileset_custom_data):
		add_tileset_custom_data(definition, tileset, source, grid_w)

	# Add definition UID to references
	Util.add_tilemap_reference(definition.uid, source)

	return source

static func add_tileset_custom_data(
		definition: Dictionary,
		tileset: TileSet,
		source :TileSetAtlasSource,
		grid_w: int
) -> void:

	if not definition.has("enumTags"):
		return

	var enumTags: Array = definition.enumTags
	var customData: Array = definition.customData

	if not customData.is_empty():
		if tileset.get_custom_data_layer_by_name("LDTK Custom"):
			tileset.add_custom_data_layer(0)
			tileset.set_custom_data_layer_name(0, "LDTK Custom")
			tileset.set_custom_data_layer_type(0, TYPE_STRING)

		for entry in customData:
			var coords := TileUtil.tileid_to_grid(entry.tileId, grid_w)
			var tile_data: TileData = source.get_tile_data(coords, 0)
			if not tile_data == null:
				tile_data.set_custom_data("LDTK Custom", entry.data)

# Create an AtlasSource from IntGrid data
static func create_intgrid_source(
		definition: Dictionary,
		tileset: TileSet
) -> TileSetAtlasSource:

	var source: TileSetAtlasSource
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

	# Check if AtlasSource already exists on TileSet
	if tileset.has_source(definition.uid):
		source = tileset.get_source(definition.uid)
	else:
		source = TileSetAtlasSource.new()

	source.resource_name = definition.identifier + "_Tiles"
	source.texture = texture
	source.texture_region_size = Vector2i(grid_size, grid_size)

	# Create Tiles
	for index in range(0, values.size()):
		#var value: Dictionary = values[index]
		var coords := Vector2i(index, 0)
		if not source.has_tile(coords):
			source.create_tile(coords)

	if (Util.options.tileset_custom_data):
		add_tileset_custom_data(definition, tileset, source, grid_size)

	if not tileset.has_source(definition.uid):
		if (Util.options.verbose_output):
			print("Adding source: %s on tileset %s" % [definition.uid, tileset.resource_name])
		tileset.add_source(source, definition.uid)

	return source

# Save TileSets as Resources
static func save_tilesets(tilesets: Dictionary, base_dir: String) -> Array:
	var save_path = base_dir + "tilesets/"
	var gen_files := []
	var directory = DirAccess.open(base_dir)
	directory.make_dir_recursive(save_path)

	for key in tilesets.keys():
		var tileset: Resource = tilesets.get(key)
		if tileset.get_source_count() == 0:
			continue

		var file_name = tileset.resource_name
		var file_path = "%s%s.%s" % [save_path, file_name, "res"]
		var err = ResourceSaver.save(tileset, file_path)
		if err == OK:
			gen_files.push_back(file_path)

	return gen_files
