@icon("ldtk-entity.svg")
@tool
class_name LDTKEntity
extends Node2D

## Placeholder Node for importing LDTK maps.
## Used to demonstrate import functionality - please write an Entity Post-Import script to spawn
## your own instances when using this in your project.

@export var iid := ""
@export var identifier := "EntityPlaceholder"
@export var fields := {}
@export var pivot := Vector2.ZERO
@export var size := Vector2.ZERO
@export var smart_color := Color.hex(0xffcc0088)
@export var definition := {}

var _refs := []
var _points := []
var _drawPaths := false

func _ready() -> void:
	_points.append(Vector2.ZERO)
	for key in fields:
		if fields[key] is NodePath:
			_refs.append(fields[key])
		elif fields[key] is Vector2i:
			_points.append(fields[key])
		elif fields[key] is Array:
			for value in fields[key]:
				if value is NodePath:
					_refs.append(value)
				elif value is Vector2i:
					_points.append(value)
				else:
					break
	_drawPaths = _refs.size() > 0 or _points.size() > 0
	_points = _parse_points(_points)
	queue_redraw()

func _draw() -> void:
	if definition.is_empty():
		return

	match definition.renderMode:
		"Ellipse":
			if definition.hollow:
				draw_arc((size * 0.5) + size * -pivot, size.x * 0.5, 0, TAU, 24, smart_color, 1.0)
			else:
				draw_circle((size * 0.5) + size * -pivot, size.x * 0.5, smart_color)
		"Rectangle":
			if definition.hollow:
				draw_rect(Rect2(size * -pivot, size), smart_color, false, 1.0)
			else:
				draw_rect(Rect2(size * -pivot, size), smart_color, true)
		"Cross":
			draw_line(Vector2.ZERO, size, smart_color, 3.0)
			draw_line(Vector2(0, size.y), Vector2(size.x, 0), smart_color, 3.0)

	if _drawPaths:
		for path in _refs:
			if not path is NodePath:
				continue
			var node = get_node(path)
			if node != null:
				draw_dashed_line(Vector2.ZERO, node.global_position - global_position, smart_color)

		var previousPoint = _points[0]
		for point in _points:
			if point == previousPoint:
				continue
			draw_dashed_line(Vector2(previousPoint), Vector2(point), smart_color, 1.0, 4.0)
			draw_arc(point, 4.0, 0, TAU, 5, smart_color, 1.0)
			previousPoint = point

func _parse_points(points: Array) -> Array:
	var origin = get_parent().global_position - global_position
	var gridSize = get_parent().definition.gridSize
	var cellOffset = gridSize * Vector2(0.5, 0.5)
	for index in range(1, points.size()):
		var pixelCoord = points[index] * gridSize
		points[index] = origin + pixelCoord + cellOffset
	return points
