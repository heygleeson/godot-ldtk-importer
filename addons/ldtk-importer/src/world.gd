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
			Util.recursive_set_owner(node, world, null)

	world.rect.position = Vector2i(x1, y1)
	world.rect.end = Vector2i(x2, y2)

	# Post-Import
	if (Util.options.world_post_import):
		if (Util.options.verbose_output):
			print("\n::POST-IMPORT WORLD: ", world.name)
		world = PostImport.run(world, Util.options.world_post_import)

	# Resolve references
	Util.resolve_references()
	Util.clean_references()

	return world
