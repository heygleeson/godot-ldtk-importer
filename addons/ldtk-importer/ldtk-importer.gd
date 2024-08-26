@tool
extends EditorImportPlugin

const LDTK_LATEST_VERSION = "1.5.3"

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
	return IMPORT_ORDER_SCENE

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
		{
			"name": "pack_levels",
			"default_value": false,
		},
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
	var external_levels: bool = world_data.externalLevels
	var world_iid: String = world_data.iid

	var world: LDTKWorld
	if world_data.worldLayout == null:
		var world_nodes: Array[LDTKWorld] = []
		var world_instances: Array = world_data.worlds
		# Build each world instance
		for world_instance in world_instances:
			var world_instance_name: String = world_instance.identifier
			var world_instance_iid: String = world_instance.iid
			var levels := Level.build_levels(world_instance, definitions, base_dir, external_levels)
			Util.log_time("\nBuilt Levels: " + world_instance_name)
			var world_node := World.create_world(world_instance_name, world_instance_iid, levels, base_dir)
			Util.log_time("\nBuilt World: " + world_instance_name)
			world_nodes.append(world_node)

		world = World.create_multi_world(world_name, world_iid, world_nodes)
	else:
		var levels := Level.build_levels(world_data, definitions, base_dir, external_levels)
		Util.log_time("Built Levels")

		# Save Levels (after Level Post-Import)
		if (Util.options.pack_levels):
			var packed_levels := []
			var levels_path := base_dir + 'levels/'
			var directory = DirAccess.open(base_dir)

			# Resolve references
			Util.resolve_references()
			Util.clean_references()
			Util.clean_resolvers()

			for level in levels:
				var level_path = save_level(level, levels_path, gen_files)
				var packed_level = load(level_path).instantiate()
				packed_levels.append(packed_level)

			Util.log_time("Saved Levels")
			world = World.create_world(world_name, world_iid, packed_levels, base_dir)
		else:
			world = World.create_world(world_name, world_iid, levels, base_dir)
			# Resolve references
			Util.resolve_references()
			Util.clean_references()
			Util.clean_resolvers()

		Util.log_time("Built World")

	# Save World as PackedScene
	var err = save_world(save_path, world, gen_files)

	Util.log_time("Saved World Scene")
	Util.finish_time()

	return err

func save_world(save_path: String, world: LDTKWorld, gen_files: Array[String]) -> Error:
	var packed_world = PackedScene.new()
	packed_world.pack(world)
	Util.log_time("Packed World Scene")

	var world_path = "%s.%s" % [save_path, _get_save_extension()]
	var err = ResourceSaver.save(packed_world, world_path)
	if err == OK:
		gen_files.append(world_path)
	return err

static func save_levels(
	levels: Array[LDTKLevel],
	save_path: String,
	gen_files: Array[String]
) -> Array[String]:

	for level in levels:
		pass

	return gen_files

static func save_level(level: LDTKLevel, save_path: String, gen_files: Array[String]) -> String:
	for child in level.get_children():
		Util.recursive_set_owner(child, level)

	var packed_level = PackedScene.new()
	packed_level.pack(level)
	var level_path = "%s%s.%s" % [save_path, level.name, "tscn"]

	var err = ResourceSaver.save(packed_level, level_path)
	if err == OK:
		gen_files.append(level_path)

	Util.log_time("Saved Level: " + level_path)
	return level_path
