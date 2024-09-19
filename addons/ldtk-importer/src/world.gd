@tool

const Util = preload("util/util.gd")
const PostImport = preload("post-import.gd")

static func create_world(
		name: String,
		iid: String,
		levels: Array,
		base_dir: String
) -> LDTKWorld:

	Util.timer_start(Util.DebugTime.GENERAL)
	var world = LDTKWorld.new()
	world.name = name
	world.iid = iid

	# Update World_Rect
	var x1 = world.rect.position.x
	var x2 = world.rect.end.x
	var y1 = world.rect.position.y
	var y2 = world.rect.end.y

	var worldDepths := {}

	for level in levels:
		level.position = level.world_position

		if Util.options.group_world_layers:
			var worldDepthLayer: LDTKWorldLayer
			var z_index: int = level.z_index if (level is not PackedScene) else 0
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

		x1 = min(x1, level.position.x)
		y1 = min(y1, level.position.y)
		x2 = max(x2, level.position.x + level.size.x)
		y2 = max(y2, level.position.y + level.size.y)

		# Set owner - this ensures nodes get saved correctly
		level.set_owner(world)
		if not (Util.options.pack_levels):
			Util.recursive_set_owner(level, world)

	# Sort WorldLayers based on depth
	if not worldDepths.is_empty():
		var keys = worldDepths.keys()
		keys.sort_custom(func(a,b): return a < b)
		for i in range(keys.size()):
			world.move_child(worldDepths[keys[i]], i)

	world.rect.position = Vector2i(x1, y1)
	world.rect.end = Vector2i(x2, y2)

	Util.timer_finish("World Created", 1)

	# Post-Import
	if (Util.options.world_post_import):
		world = PostImport.run_world_post_import(world, Util.options.world_post_import)

	return world

static func create_multi_world(
		name: String,
		iid: String,
		worlds: Array[LDTKWorld]
) -> LDTKWorld:

	var multi_world = LDTKWorld.new()
	multi_world.name = name
	multi_world.iid = iid

	worlds.sort_custom(func(a, b): return a.depth < b.depth)

	for world in worlds:
		multi_world.add_child(world)
		Util.recursive_set_owner(world, multi_world)

	return multi_world
