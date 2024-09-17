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

const TYPE_STRING = [
		"Nil", "Bool", "Int", "Float", "String", "Vec2", "Vec2i", "Rect2", "Rect2i", "Vec3",
		"Vec3i", "Transform2D", "Vec4", "Vec4i", "Plane", "Quarternion", "AABB", "Basis",
		"Transform3D", "Projection", "Color", "StringName", "NodePath", "RID", "Object",
		"Callable", "Signal", "Dictionary", "Array", "PackedArray", "PackedInt32Array",
		"PackedInt64Array", "PackedFloat32Array", "PackedFloat64Array", "PackedVec2Array",
		"PackedVec3Array", "PackedColorArray", "Max"
]

static var options := {}

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

	time_history.append({"category": category, "time": t})
	return d

static func timer_finish(message: String, indent: int = 0, print: bool = true) -> int:
	if time_history.size() == 0:
		push_error("Unbalanced DebugTime stack")
	var last: Dictionary = time_history.pop_back()
	var t: int = Time.get_ticks_msec()
	var d: int = t - last.time
	last_time = t
	DebugTime.log_time(last.category, d)

	if time_history.size() > 0:
		time_history[-1].time = t

	if (print and options.verbose_output):
		print_time("item_info_time", message, d, indent)
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

static func print(type: String, message: String, indent: int = 0) -> void:
	if PRINT_SNIPPET.has(type):
		var snippet: String = PRINT_SNIPPET[type]
		snippet = snippet.indent(str("\t").repeat(indent))
		print_rich(snippet % [message])
	else:
		print_rich(message)

static func print_time(type: String, message: String, time: int = -1, indent: int = 0) -> void:
	if PRINT_SNIPPET.has(type):
		var snippet: String = PRINT_SNIPPET[type]
		snippet = snippet.indent(str("\t").repeat(indent))
		print_rich(snippet % [message, time])
	else:
		print_rich(message)

#endregion

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

# References
static var tilesets := {}
static var tileset_refs := {}
static var instance_refs := {}
static var unresolved_refs := []
static var path_resolvers := []

static func update_instance_reference(iid: String, instance: Variant) -> void:
	#if instance_refs.has(iid):
		#if (options.verbose_output):
			#print("  Overwriting InstanceRef: %s -> '%s'" % [iid.substr(0,8), instance.name])
	instance_refs[iid] = instance

static func add_tileset_reference(uid: int, atlas: TileSetAtlasSource) -> void:
	#if tileset_refs.has(uid):
		#if (options.verbose_output):
			#print("  Overwriting TileSetAtlasSourceRef: %s -> '%s'" % [uid, atlas.resource_name])
	#else:
		#if (options.verbose_output):
			#print("  Creating TileSetAtlasSourceRef: %s -> '%s'" % [uid, atlas.resource_name])
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

static func resolve_references() -> void:
	var solved_refcount := 0

	for ref in unresolved_refs:
		var iid: String = ref.iid
		var object: Variant = ref.object # Expected: Node, Dict or Array
		var property: Variant = ref.property # Expected: String or Int
		var node: Variant = ref.node # Expected: Node, but needs to accept null

		#if (options.verbose_output):
			#print("Ref: %s" % [iid.substr(0,8)])

		if instance_refs.has(iid):
			var instance = instance_refs[iid]

			if instance is Node and node is Node:
				# Check if they are in the same tree
				if instance.owner != null and node.owner != null:
					var path = node.get_path_to(instance)
					if path:
						object[property] = path
			else:
				object[property] = instance

			#if (options.verbose_output):
				#print("'%s' = %s -> %s" % [property, iid.substr(0,8), object[property]])

			solved_refcount += 1
		else:
			print("%s not found as a reference" % [iid.substr(0,8)])

	var leftover_refcount: int = unresolved_refs.size() - solved_refcount
	if leftover_refcount > 0:
		push_warning("Could not resolve ", leftover_refcount, " references, most likely non-existent entities.")

static func clean_references() -> void:
	tileset_refs.clear()
	instance_refs.clear()
	unresolved_refs.clear()

static func clean_resolvers() -> void:
	for resolver in path_resolvers:
		resolver.free()
	path_resolvers.clear()
