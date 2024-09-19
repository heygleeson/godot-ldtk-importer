@tool

const DebugTime = preload("time-util.gd")

enum LDTK_VERSION {
	FUTURE,
	v1_5,
	v1_4,
	v1_3,
	v1_2,
	v1_0,
	UNSUPPORTED
}
static var file_version = LDTK_VERSION.UNSUPPORTED

# Stores import flags (used throughout the importer)
static var options := {}

static func parse_file(source_file: String) -> Dictionary:
	var json := FileAccess.open(source_file, FileAccess.READ)
	if json == null:
		push_error("\nFailed to open file: ", source_file)
		return {}
	var data := JSON.parse_string(json.get_as_text())
	return data

static func check_version(version: String, latest_version: String) -> bool:
	if version.begins_with("0."):
		push_error("LDTK version out of date. Please update LDtk to ", latest_version)
		file_version = LDTK_VERSION.UNSUPPORTED
		return false

	var major_minor = version.substr(0, 3)
	match major_minor:
		"1.0", "1.1":
			file_version = LDTK_VERSION.v1_0
		"1.2":
			file_version = LDTK_VERSION.v1_2
		"1.3":
			file_version = LDTK_VERSION.v1_3
		"1.4":
			file_version = LDTK_VERSION.v1_4
		"1.5":
			file_version = LDTK_VERSION.v1_5
		_:
			push_warning("LDtk file version is newer than what is supported. Errors may occur.")
			file_version = LDTK_VERSION.FUTURE
	return true

static func recursive_set_owner(node: Node, owner: Node) -> void:
	node.set_owner(owner)
	for child in node.get_children():
		# Child is NOT an instantiated scene - this would otherwise cause errors
		if child.scene_file_path == "":
			recursive_set_owner(child, owner)
		else:
			child.set_owner(owner)

#region Performance Measurement

static var last_time: int = 0
static var time_history: Array[Dictionary] = []

static func timer_start(category: int = 0) -> int:
	var t: int = Time.get_ticks_msec()
	var d: int = t - last_time
	last_time = t

	if time_history.size() > 0:
		# Entering subcategory - log prev category up to here
		var last: Dictionary = time_history[-1]
		DebugTime.log_time(last.category, d)

	time_history.append({"category": category, "time": t, "init": t})
	return t

static func timer_finish(message: String, indent: int = 0, doPrint: bool = true) -> int:
	if time_history.size() == 0:
		push_error("Unbalanced DebugTime stack")
	var last: Dictionary = time_history.pop_back()
	var t: int = Time.get_ticks_msec()
	var d: int = t - last.time
	last_time = t
	DebugTime.log_time(last.category, d)

	if time_history.size() > 0:
		time_history[-1].time = t

	if (doPrint and options.verbose_output):
		# Print 'gross' duration for this block
		var d2: int = t - last.init
		print_time("item_info_time", message, d2, indent)
	return d

static func timer_reset() -> void:
	last_time = 0
	time_history.clear()
	DebugTime.clear_time()

#endregion

#region Debug Output

const PRINT_SNIPPET := {
	"import_start": "[bgcolor=#ffcc00][color=black][LDTK][/color][/bgcolor][color=#ffcc00] Start Import: [color=#fe8019][i]'%s'[/i][/color]",
	"import_finish": "[bgcolor=#ffcc00][color=black][LDTK][/color][/bgcolor][color=#ffcc00] Finished Import. [color=slategray](Total Time: %sms)[/color]",
	"item_ok" : "[color=#b8bb26]• %s ✔[/color]",
	"item_fail": "[color=#fb4934]• %s ✘[/color]",
	"item_info": "[color=#8ec07c]• %s [/color]",
	"item_save": "[color=#ffcc00]• %s [/color]",
	"item_post_import": "[color=tomato]‣ %s[/color]",
	"block": "[color=#ffcc00]█[/color] [color=#fe8019]%s[/color]",
	"item_ok_time": "[color=#b8bb26]• %s ✔[/color]\t[color=slategray](%sms)[/color]",
	"item_fail_time": "[color=#fb4934]• %s ✘[/color]\t[color=slategray](%sms)[/color]",
	"item_info_time": "[color=#8ec07c]• %s [/color]\t[color=slategray](%sms)[/color]",
	"world_post_import": "[color=tomato]‣ World Post-Import: %s[/color]",
	"level_post_import": "[color=tomato]‣ Level Post-Import: %s[/color]",
	"tileset_post_import": "[color=tomato]‣ Tileset Post-Import: %s[/color]",
	"entity_post_import": "[color=tomato]‣ Entity Post-Import: %s[/color]",
}

static func nice_print(type: String, message: String, indent: int = 0) -> void:
	if PRINT_SNIPPET.has(type):
		var snippet: String = PRINT_SNIPPET[type]
		snippet = snippet.indent(str("\t").repeat(indent))
		print_rich(snippet % [message])
	else:
		print_rich(message)

static func print(type: String, message: String, indent: int = 0) -> void:
	nice_print(type, message, indent)

static func print_time(type: String, message: String, time: int = -1, indent: int = 0) -> void:
	if PRINT_SNIPPET.has(type):
		var snippet: String = PRINT_SNIPPET[type]
		snippet = snippet.indent(str("\t").repeat(indent))
		print_rich(snippet % [message, time])
	else:
		print_rich(message)

#endregion

#region References
static var tilesets := {}
static var tileset_refs := {}
static var instance_refs := {}
static var unresolved_refs := []
static var path_resolvers := []

static func update_instance_reference(iid: String, instance: Variant) -> void:
	instance_refs[iid] = instance

static func add_tileset_reference(uid: int, atlas: TileSetAtlasSource) -> void:
	tileset_refs[uid] = atlas

# This is useful for handling entity instances, as they might not exist yet when encountered
# or be overwritten at a later stage (e.g. post-import) when importing an LDTK level/world.
static func add_unresolved_reference(
	object: Variant,
	property: Variant,
	node: Variant = object,
	iid: String = str(object[property])
) -> void:

	unresolved_refs.append({
			"object": object,
			"property": property,
			"node": node,
			"iid": iid
	})

static func handle_references() -> void:
	resolve_references()
	clean_references()
	clean_resolvers()

static func resolve_references() -> void:
	var count := unresolved_refs.size()
	if (count == 0 or not options.resolve_entityrefs):
		if (options.verbose_output): nice_print("item_info", "No references to resolve", 1)
		return
	else:
		if (options.verbose_output): nice_print("item_info", "Resolving %s references" % [count], 1)

	var solved_refcount := 0

	for ref in unresolved_refs:
		var iid: String = ref.iid
		var object: Variant = ref.object # Expected: Node, Dict or Array
		var property: Variant = ref.property # Expected: String or Int
		var node: Variant = ref.node # Expected: Node, but needs to accept null

		if instance_refs.has(iid):
			var instance = instance_refs[iid]

			if instance is Node and node is Node:
				# BUG: When using 'Pack Levels', external references cannot be resolved at import time. (e.g. Level_0 -> Level_1)
				# Internal references can resolve, but Godot pushes the error: Parameter "common_parent" is null.
				# Currently it's a choice between a bunch of errors (that suppress other messages), or no resolving.
				if true: #instance.owner != null and node.owner != null:
					var path = node.get_path_to(instance)
					if path:
						object[property] = path
					else:
						nice_print("item_fail", "Cannot resolve ref (out-of-bounds?) '%s' '%s'" % [instance.name, node.name], 1)
						continue
			else:
				object[property] = instance

			solved_refcount += 1

	var leftover_refcount: int = unresolved_refs.size() - solved_refcount
	if leftover_refcount > 0:
		nice_print("item_info", "Could not resolve %s references, most likely non-existent entities." % [leftover_refcount], 1)

static func clean_references() -> void:
	tileset_refs.clear()
	instance_refs.clear()
	unresolved_refs.clear()

static func clean_resolvers() -> void:
	for resolver in path_resolvers:
		resolver.free()
	path_resolvers.clear()

#endregion
