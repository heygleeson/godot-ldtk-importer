@tool

enum LDTK_VERSION {
	FUTURE,
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

### Performance Measurement
static var time_start : int
static var time_last : int
static func start_time():
	time_start = Time.get_ticks_msec()
	time_last = time_start
	print("-- LDTK: Start Import --")

static func log_time(message: String):
	var time = Time.get_ticks_msec()
	var time_log = time - time_last
	time_last = time
	print("%s :: %sms" % [message, time_log])

static func finish_time():
	var time = Time.get_ticks_msec()
	var time_finish = time - time_start
	print("-- LDTK: Finished Import -- (%sms)" % [time_finish])

### General
static func parse_file(source_file: String) -> Dictionary:
	var json := FileAccess.open(source_file, FileAccess.READ)
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
		_:
			push_warning("LDtk file version is newer than what is supported. Errors may occur.")
			file_version = LDTK_VERSION.FUTURE
	return true

static func recursive_set_owner(node: Node, owner: Node, root: Node):
	if node.owner != root and node.owner != null:
		return

	node.set_owner(owner)
	for child in node.get_children():
		recursive_set_owner(child, owner, root)

### References
static var tilemap_refs := {}
static var instance_refs := {}
static var unresolved_refs := []
static var path_resolvers := []

static func update_instance_reference(iid: String, instance: Variant) -> void:
	if instance_refs.has(iid):
		if (options.verbose_output):
			print("Overwriting InstanceRef: ", iid.substr(0,8) ," -> ", instance)
	instance_refs[iid] = instance

static func add_tilemap_reference(uid: int, atlas: TileSetAtlasSource) -> void:
	if tilemap_refs.has(uid):
		if (options.verbose_output):
			print("Overwriting TileSetAtlasSourceRef: ", uid ," -> ", atlas)
	tilemap_refs[uid] = atlas

# This is useful for handling entity instances, as they might not exist yet when encountered
# or be overwritten at a later stage (e.g. post-import) when importing an LDTK level/world.
static func add_unresolved_reference(object, property, node = object) -> void:
	var iid = object[property]
	unresolved_refs.append({
			"object": object,
			"property": property,
			"iid": iid,
			"node": node
	})

static func resolve_references() -> void:
	if (options.verbose_output):
		print("Resolving ", unresolved_refs.size(), " entity references...")

	var solved_refcount := 0

	for ref in unresolved_refs:
		var iid: String = ref.iid
		var object: Variant = ref.object # Expected: Node, Dict or Array
		var property: Variant = ref.property # Expected: String or Int
		var node: Variant = ref.node # Expected: Node, but needs to accept null

		if instance_refs.has(iid):
			var instance = instance_refs[iid]
			if instance is Node and node is Node:
				object[property] = node.get_path_to(instance)
			else:
				object[property] = instance

			if (options.verbose_output):
				print("'%s' = %s -> %s" % [property, iid.substr(0,8), object[property]])
			solved_refcount += 1

	var leftover_refcount: int = unresolved_refs.size() - solved_refcount
	if leftover_refcount > 0:
		push_warning("Could not resolve ", leftover_refcount, " references, most likely non-existent entities.")

static func clean_references() -> void:
	tilemap_refs.clear()
	instance_refs.clear()
	unresolved_refs.clear()

	for resolver in path_resolvers:
		resolver.free()
	path_resolvers.clear()
