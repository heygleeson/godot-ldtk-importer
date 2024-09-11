@tool

const Util = preload("util/util.gd")

static func run(element: Variant, script_path: String) -> Variant:
	var element_type = typeof(element)

	if not script_path.is_empty():
		var script = load(script_path)
		if not script or not script is GDScript:
			printerr("Post-Import: '%s' is not a GDScript" % [script_path])
			return ERR_INVALID_PARAMETER

		script = script.new()
		if not script.has_method("post_import"):
			printerr("Post-Import: '%s' does not have a post_import() method" % [script_path])
			return ERR_INVALID_PARAMETER

		element = script.post_import(element)

		if element == null or typeof(element) != element_type:
			printerr("Post-Import: Invalid scene returned from script.")
			return ERR_INVALID_DATA

	return element

static func run_tileset_post_import(tilesets: Array, script_path: String) -> Array:
	if (Util.options.verbose_output):
		print("\n::POST-IMPORT Tilesets")
	return run(tilesets, Util.options.tileset_post_import)

static func run_level_post_import(level: LDTKLevel, script_path: String) -> LDTKLevel:
	if (Util.options.verbose_output):
		print("\n::POST-IMPORT LEVEL: ", level.name)
	return run(level, Util.options.level_post_import)

static func run_entity_post_import(level: LDTKLevel, script_path: String) -> LDTKLevel:
	var layers = level.get_children()
	for layer in layers:
		if layer is not LDTKEntityLayer:
			continue

		if (Util.options.verbose_output):
			var entityLayerName = layer.get_parent().name + "." + layer.name
			print("\n::POST-IMPORT ENTITIES: ", entityLayerName)

		layer = run(layer, script_path)
	return level

static func run_world_post_import(world: LDTKWorld, script_path: String) -> LDTKWorld:
	if (Util.options.verbose_output):
			print("\n::POST-IMPORT WORLD: ", world.name)
	return run(world, Util.options.world_post_import)
