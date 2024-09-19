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

static func run_tileset_post_import(tilesets: Dictionary, script_path: String) -> Dictionary:
	Util.timer_start(Util.DebugTime.POST_IMPORT)
	Util.print("tileset_post_import", str(tilesets), 1)
	tilesets = run(tilesets, Util.options.tileset_post_import)
	Util.timer_finish("Tileset Post-Import: Complete", 1)
	return tilesets

static func run_level_post_import(level: LDTKLevel, script_path: String) -> LDTKLevel:
	Util.timer_start(Util.DebugTime.POST_IMPORT)
	Util.print("level_post_import", level.name, 2)
	level = run(level, Util.options.level_post_import)
	Util.timer_finish("Level Post-Import: Complete", 2)
	return level

static func run_entity_post_import(level: LDTKLevel, script_path: String) -> LDTKLevel:
	Util.timer_start(Util.DebugTime.POST_IMPORT)
	var layers = level.get_children()
	for layer in layers:
		if layer is not LDTKEntityLayer:
			continue

		var entityLayerName = layer.get_parent().name + "." + layer.name
		Util.print("entity_post_import", entityLayerName, 3)
		layer = run(layer, script_path)

	Util.timer_finish("Entity Post-Import: Complete", 3)
	return level

static func run_world_post_import(world: LDTKWorld, script_path: String) -> LDTKWorld:
	Util.timer_start(Util.DebugTime.POST_IMPORT)
	Util.print("world_post_import", world.name, 1)
	world = run(world, Util.options.world_post_import)
	Util.timer_finish("World Post-Import: Complete", 1)
	return world
