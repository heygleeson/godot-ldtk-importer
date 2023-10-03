@tool

const Util = preload("util/util.gd")
const PostImport = preload("post-import.gd")

static func create_world(name: String, levels: Array) -> LDTKWorld:

	var world = LDTKWorld.new()
	world.name = name

	# Update World_Rect
	var x1 = world.rect.position.x
	var x2 = world.rect.end.x
	var y1 = world.rect.position.y
	var y2 = world.rect.end.y

	var worldDepths := {}

	for level in levels:
		if Util.options.separate_world_layers:
			var worldDepthLayer
			var z_index = level.z_index
			if not z_index in worldDepths:
				worldDepthLayer = LDTKWorldLayer.new()
				worldDepthLayer.name = "WorldLayer_" + str(z_index)
				worldDepthLayer.depth = z_index
				world.add_child(worldDepthLayer)
				worldDepthLayer.set_owner(world)
				worldDepths[z_index] = worldDepthLayer
			else:
				worldDepthLayer = worldDepths[z_index]
			worldDepthLayer.add_child(level)
		else:
			world.add_child(level)

		level.set_owner(world)

		x1 = min(x1, level.position.x)
		y1 = min(y1, level.position.y)
		x2 = max(x2, level.position.x + level.size.x)
		y2 = max(y2, level.position.y + level.size.y)

		if (Util.options.entities_post_import):
			var layers = level.get_children()
			for layer in layers:
				if not layer is LDTKEntityLayer:
					continue

				if (Util.options.verbose_output):
					var entityLayerName = layer.get_parent().name + "." + layer.name
					print("\n::POST-IMPORT ENTITIES: ", entityLayerName)

				layer = PostImport.run(layer, Util.options.entities_post_import)

		if (Util.options.level_post_import):
			if (Util.options.verbose_output):
				print("\n::POST-IMPORT LEVEL: ", level.name)
			level = PostImport.run(level, Util.options.level_post_import)

		for node in level.get_children():
			Util.recursive_set_owner(node, world)

	# Sort WorldLayers based on depth
	if not worldDepths.is_empty():
		var keys = worldDepths.keys()
		keys.sort_custom(func(a,b): return a < b)
		for i in range(keys.size()):
			world.move_child(worldDepths[keys[i]], i)

	world.rect.position = Vector2i(x1, y1)
	world.rect.end = Vector2i(x2, y2)

	# Post-Import
	if (Util.options.world_post_import):
		if (Util.options.verbose_output):
			print("\n::POST-IMPORT WORLD: ", world.name)
		world = PostImport.run(world, Util.options.world_post_import)

	return world

static func create_multi_world(
	name: String,
	worlds: Array[LDTKWorld]
) -> LDTKWorld:

	var multi_world = LDTKWorld.new()
	multi_world.name = name

	worlds.sort_custom(func(a,b): return a.depth < b.depth)

	for world in worlds:
		multi_world.add_child(world)
		Util.recursive_set_owner(world, multi_world)

	return multi_world

# Unused
static func save_worlds(worlds: Array[LDTKWorld], base_dir: String) -> Array:
	var gen_files := []
	var save_path = base_dir + 'worlds/'
	var directory = DirAccess.open(base_dir)
	directory.make_dir_recursive(save_path)

	for world in worlds:
		var packed_world = PackedScene.new()
		packed_world.pack(world)

		var file_name = world.name
		var file_path = "%s%s.%s" % [save_path, file_name, "tscn"]

		var err = ResourceSaver.save(packed_world, file_path)
		if err == OK:
			gen_files.push_back(file_path)

	return gen_files
