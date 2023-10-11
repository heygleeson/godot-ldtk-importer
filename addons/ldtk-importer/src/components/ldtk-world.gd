@tool
@icon("ldtk-world.svg")
class_name LDTKWorld
extends Node2D

@export var iid: String
@export var rect: Rect2i
@export var references: Dictionary
@export var resolvers: Array
@export var level_scenes: Dictionary = {}

var __levels_active: Dictionary = {}

# ----
func _enter_tree() -> void:
	__levels_active = level_scenes.duplicate()
	for key in __levels_active:
		__levels_active[key] = find_child(key) != null

func _exit_tree() -> void:
	pass

func _get_property_list() -> Array[Dictionary]:
	var properties: Array[Dictionary] = []
	properties.append({"name": "Levels", "type": TYPE_NIL, "usage": PROPERTY_USAGE_CATEGORY})
	for level_name in level_scenes:
		properties.append({"name": level_name, "type": TYPE_BOOL})
	return properties

func _get(property: StringName) -> Variant:
	if property in level_scenes:
		if not __levels_active.has(property):
			print("level not exist. setting...")
			__levels_active[property] = find_child(property) != null
		return __levels_active[property]

	return null

func _set(property: StringName, value: Variant) -> bool:
	if property in level_scenes:
		__levels_active[property] = value
		if (value):
			load_level(property)
		else:
			unload_level(property)

	return false

# ---
func load_level(level_name: String) -> void:
	if not is_inside_tree():
		return

	if level_name in level_scenes:
		if not find_child(level_name):
			print("Loading Level: ", level_name)
			var level_scene = level_scenes[level_name]
			var level = load(level_scene).instantiate()
			add_child(level)
			level.set_owner(self)
			set_editable_instance(level, true)

func unload_level(level_name: String) -> void:
	if not is_inside_tree():
		return

	if level_name in level_scenes:
		var level = find_child(level_name)
		if level:
			print("Loading Level: ", level_name)
			level.queue_free()

