@tool
@icon("ldtk-world.svg")
class_name LDTKWorld
extends Node2D

@export var iid: String
@export var rect: Rect2i
@export var levels: Array[LDTKLevel]

func _init() -> void:
	child_entered_tree.connect(_on_child_entered)

func _on_child_entered(child: Node) -> void:
	if child is LDTKLevel:
		levels.append(child)
