@tool
extends Resource
class_name LDTKResolver

# Raw LDTK Values
@export var reference: Dictionary
@export var node: Node
@export var value: NodePath

func init(object, property, node) -> void:
	reference = object[property] as Dictionary
	if node is Node:
		self.node = node

func _ready() -> void:
	call_deferred("resolve")

func resolve() -> NodePath:
	if node == null:
		return NodePath()

	var entityIid = reference.entityIid
	var path: NodePath
	var target: Node

	# 1 - Check entityIid in current LDTKEntityLayer
	var layer = node.get_parent()
	if not layer is LDTKEntityLayer:
		return NodePath()

	var layer_entityrefs = layer.references
	if entityIid in layer_entityrefs:
		path = layer_entityrefs[entityIid]
		target = layer.get_node(path)
		value = node.get_path_to(target)
		return value

	# 2 - Check layer in LDTKLevel
	var level = layer.get_parent()
	if not level is LDTKLevel:
		return NodePath()

	var level_entityrefs = level.references
	if entityIid in level_entityrefs:
		path = level_entityrefs[entityIid]
		target = level.get_node(path)
		value = node.get_path_to(target)
		return value

	# 3 - Check if parent is LDTKWorld - check level is loaded
	var world = level.get_parent()
	while (world is LDTKWorld or world is LDTKWorldLayer):
		var world_entityrefs = world.references
		if entityIid in world_entityrefs:
			path = world_entityrefs[entityIid]
			target = world.get_node(path)
			value = node.get_path_to(target)
			return value

		# Ascend hierarchy for next iteration
		world = world.get_parent()

	return NodePath()

func can_resolve() -> bool:
	return true
