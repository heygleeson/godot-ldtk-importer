@icon("ldtk-level.svg")
@tool
class_name LDTKLevel
extends Node2D

@export var iid: String
@export var size: Vector2i
@export var fields: Dictionary
@export var neighbours: Array
@export var bg_color: Color
@export var references: Dictionary
@export var unresolved_references: Array

# ---
func _ready() -> void:
	# Merge
	for child in get_children():
		if child is LDTKEntityLayer:
			# Add References
			var child_path = get_path_to(child)
			for key in child.references:
				# NOTE: This is an ugly NodePath rebuild.
				var node_path = NodePath(String(child_path) + "/" + String(child.references[key]))
				references[key] = node_path
				#print("Merge Path: '%s' -> '%s'" % [child.references[key], node_path])

			# Add Unresolved References
			unresolved_references.append_array(child.unresolved_references)

	_resolve_references()
	queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), bg_color, false, 2.0)

# ---
func add_reference(iid: String, node: Node) -> void:
	references[iid] = node

func _resolve_references():
	for reference in unresolved_references:

		## reference.ref
		## entityIid:
		## layerIid:
		## levelIid:
		## worldIid:


		#if references.has(ref.iid):
			## Instance is in this level
			#var obj = ref.obj
			#var prop = ref.property
			#var node = ref.node
			#var instance = references[ref.iid]
			#if instance is Node and node is Node:
				#obj[prop] = node.get_path_to(instance) # NodePath
			#else:
				#obj[prop] = instance # Array/Dict reference
		#else:
			## Do nothing here, we'll need to pass it up
			#pass
