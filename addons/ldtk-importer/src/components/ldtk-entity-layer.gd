@tool
@icon("ldtk-entity-layer.svg")
class_name LDTKEntityLayer
extends Node2D

@export var definition: Dictionary
@export var entities: Array
@export var references: Dictionary
@export var unresolved_references: Array

func add_reference(iid: String, node: NodePath) -> void:
	references[iid] = node

func add_unresolved_ref(object: Variant, property: Variant, node: Variant = object) -> void:
	var ref = object[property]
	unresolved_references.append({
		"object": object,
		"property": property,
		"ref": ref,
		"node": node
	})
