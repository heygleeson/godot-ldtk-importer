@tool
extends EditorImportPlugin

const LDTK_LATEST_VERSION = "1.3.4"

enum Presets {DEFAULT}

const Util = preload("src/util/util.gd")
const World = preload("src/world.gd")
const Level = preload("src/level.gd")
const Tileset = preload("src/tileset.gd")
const DefinitionUtil = preload("src/util/definition_util.gd")

func _get_importer_name():
	return "ldtk.import"

func _get_visible_name():
	return "LDTK Scene"

func _get_priority():
	return 1.0

func _get_import_order():
	return 100

func _get_resource_type():
	return "PackedScene"

func _get_recognized_extensions():
	return ["ldtk"]

func _get_save_extension():
	return "scn"

func _get_preset_count():
	return Presets.size()

func _get_preset_name(index):
	match index:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_options(path, index):
	return [
		# --- World --- #
		{"name": "World", "default_value":"", "usage": PROPERTY_USAGE_GROUP},
		{
			"name": "separate_world_layers",
			"default_value": false,
		},
		# --- Levels --- #
		{"name": "Level", "default_value":"", "usage": PROPERTY_USAGE_GROUP},

		# --- Tileset --- #
		{"name": "Tileset", "default_value":"", "usage": PROPERTY_USAGE_GROUP},
		{
			"name": "force_tileset_reimport",
			"default_value": false,
		},
		{
			"name": "tileset_custom_data",
			"default_value": false,
		},
		{
			"name": "atlas_texture_type",
			"default_value": 0,
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": "CompressedTexture2D,CanvasTexture",
		},
		# --- Entities --- #
		{"name": "Entity", "default_value":"", "usage": PROPERTY_USAGE_GROUP},
		{
			"name": "use_entity_placeholders",
			"default_value": false,
		},
		# --- Post Import --- #
		{"name": "Post Import", "default_value":"", "usage": PROPERTY_USAGE_GROUP},
		{
			"name": "tileset_post_import",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.gd;GDScript"
		},
		{
			"name": "entities_post_import",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.gd;GDScript"
		},
		{
			"name": "level_post_import",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.gd;GDScript"
		},
		{
			"name": "world_post_import",
			"default_value": "",
			"property_hint": PROPERTY_HINT_FILE,
			"hint_string": "*.gd;GDScript"
		},
		# --- Debug --- #
		{"name": "Debug", "default_value":"", "usage": PROPERTY_USAGE_GROUP},
		{
			"name": "verbose_output", "default_value": false
		},
		{
			"name": "verbose_post_import", "default_value": false
		},
	]

func _get_option_visibility(path, option_name, options):
	match option_name:
		_:
			return true
	return true

func _import(
		source_file: String,
		save_path: String,
		options: Dictionary,
		platform_variants: Array[String],
		gen_files: Array[String]
) -> Error:

	Util.start_time()

	# Add Options to static var in "Util", accessible from any script.
	Util.options = options

	# Parse source_file
	var base_dir := source_file.get_base_dir() + "/"
	var file_name := source_file.get_file()
	var world_name := file_name.split(".")[0]

	var world_data := Util.parse_file(source_file)
	if (Util.options.verbose_output):
		Util.log_time("Parse File")

	# Check Version
	if Util.check_version(world_data.jsonVersion, LDTK_LATEST_VERSION):
		print("LDTK VERSION OK")
	else:
		return ERR_PARSE_ERROR

	# Generate Definitions
	var definitions := DefinitionUtil.build_definitions(world_data)
	if (Util.options.verbose_output):
		Util.log_time("Build Definitions")

	# Generate TileSets
	var tilesets := Tileset.build_tilesets(definitions, base_dir)
	if (Util.options.verbose_output):
		Util.log_time("Built Tilesets")

	# Create Levels
	var levels := Level.build_levels(world_data, definitions, tilesets, base_dir)
	if (Util.options.verbose_output):
		Util.log_time("Built Levels")

	# Create World
	var world := World.create_world(world_name, levels)
	if (Util.options.verbose_output):
		Util.log_time("Built World")

	# Save Tilesets as Resources
	var tileset_paths := Tileset.save_tilesets(tilesets, base_dir)
	gen_files.append_array(tileset_paths)
	if (Util.options.verbose_output):
		Util.log_time("Saved Tilesets")

	# Save World as PackedScene
	var packed_world = PackedScene.new()
	packed_world.pack(world)
	if (Util.options.verbose_output):
		Util.log_time("Packed World Scene")

	var world_path = "%s.%s" % [save_path, _get_save_extension()]
	var err = ResourceSaver.save(packed_world, world_path)
	if (Util.options.verbose_output):
		Util.log_time("Saved World Scene")

	Util.finish_time()
	return err
