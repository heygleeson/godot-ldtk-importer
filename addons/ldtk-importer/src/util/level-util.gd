@tool

const Util = preload("util.gd")

static func get_world_position(
		world_data: Dictionary,
		level_data: Dictionary
) -> Vector2i:

	var layout = world_data.worldLayout

	if layout == "GridVania" or layout == "Free":
		return Vector2i(level_data.worldX, level_data.worldY)
	elif layout == "LinearHorizontal" or layout == "LinearVertical":
		# List level uids in order.
		var level_uids: Array = world_data.levels.map(
			func(item):
				return item.uid
		)
		# Find level index
		var index = level_uids.find(level_data.uid)
		if index == 0:
			return Vector2i(0,0)

		if layout == "LinearHorizontal":
			var x: int = world_data.levels.slice(0, index).reduce(
				func (accum, current):
					return accum + current.pxWid
			, 0)
			return Vector2i(x, 0)
		else:
			var y: int = world_data.levels.slice(0, index).reduce(
				func (accum, current):
					return accum + current.pHei
			, 0)
			return Vector2i(0, y)
	else:
		push_warning("World layout not supported", world_data.worldLayout)
		return Vector2i.ZERO


static func get_external_level(
		level_data: Dictionary,
		base_dir: String
) -> Dictionary:

	var level_file = base_dir + "/" + level_data.externalRelPath
	var new_level_data = Util.parse_file(level_file)
	if not new_level_data == null:
		if Util.options.verbose_output:
			print("Parsed External Level: ", level_file)
		return new_level_data

	return level_data
