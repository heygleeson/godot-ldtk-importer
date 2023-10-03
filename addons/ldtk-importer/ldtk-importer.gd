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
			"name": "allow_overlapping_tiles",
			"default_value": true,
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

	# Add options to static var in "Util", accessible from any script.
	Util.options = options

	# Parse source_file
	var base_dir := source_file.get_base_dir() + "/"
	var file_name := source_file.get_file()
	var world_name := file_name.split(".")[0]

	var world_data := Util.parse_file(source_file)
	Util.log_time("Parse File")

	# Check version
	if Util.check_version(world_data.jsonVersion, LDTK_LATEST_VERSION):
		print("LDTK VERSION OK")
	else:
		return ERR_PARSE_ERROR

	# Generate definitions
	var definitions := DefinitionUtil.build_definitions(world_data)
	Util.log_time("Build Definitions")

	# Save Tilesets as Resources
	var tileset_paths := Tileset.build_tilesets(definitions, base_dir)
	gen_files.append_array(tileset_paths)
	Util.log_time("Saved Tilesets")

	# Detect Multi-Worlds
	var world
	if world_data.worldLayout == null:
		var world_nodes: Array[LDTKWorld] = []
		var world_instances = world_data.worlds
		for world_instance in world_instances:
			var world_instance_name = world_instance.identifier

			var levels := Level.build_levels(world_instance, definitions, base_dir)
			Util.log_time("\nBuilt Levels: " + world_instance_name)

			var world_node := World.create_world(world_instance_name, levels)
			Util.log_time("\nBuilt World: " + world_instance_name)

			world_nodes.append(world_node)

		# Pack and save worlds
		# Currenty unsupported: Cannot resolve references.
		#var world_paths := World.save_worlds(world_nodes, base_dir)
		#gen_files.append_array(world_paths)
		#world = World.create_multi_world(world_name, world_paths)

		world = World.create_multi_world(world_name, world_nodes)
	else:
		var levels := Level.build_levels(world_data, definitions, base_dir)
		Util.log_time("Built Levels")

		world = World.create_world(world_name, levels)
		Util.log_time("Built World")

	# Resolve references
	Util.resolve_references()
	Util.clean_references()
	Util.clean_resolvers()

	# Save World as PackedScene
	var packed_world = PackedScene.new()
	packed_world.pack(world)
	Util.log_time("Packed World Scene")

	var world_path = "%s.%s" % [save_path, _get_save_extension()]
	var err = ResourceSaver.save(packed_world, world_path)
	Util.log_time("Saved World Scene")
	Util.finish_time()

	return err
