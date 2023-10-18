@tool
@icon("ldtk-entity-layer.svg")
class_name LDTKWorldLayer
extends Node2D

@export var depth: int:
	set(d):
		depth = d
		z_index = depth
