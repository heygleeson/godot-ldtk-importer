@tool
extends EntityImporter
class_name EntityImporterWithUtil

@export var level : int = 1
@export var paint_container : Node2D

@export_category("Adjust Nodes")
@export_tool_button("Delete Children", "Node2D") var delete = delete_children
@export_tool_button("Organize Nodes", "Node2D") var ON = organize_nodes
@export var entities_per_section := 5

func _set_entity_layer(value):
	if not Engine.is_editor_hint():
		return
	
	super(value)
	if value != null:
		organize_nodes()

func organize_nodes():
	# Get all children that need organizing (excluding paint_container and PoolingSpawner)
	var children_to_organize : Array = get_children()  
	
	# Organize remaining children into containers
	for i in range(0, children_to_organize.size(), entities_per_section):
		var container = Node2D.new()
		container.name = "Section_%d" % (i / entities_per_section + 1)
		add_child(container)
		container.set_owner(get_tree().edited_scene_root)
		
		# Determine the end index for this batch
		var end_index = min(i + entities_per_section, children_to_organize.size())
		
		# Reparent the batch of nodes
		for n in range(i, end_index):
			var child = children_to_organize[n]
			child.reparent(container)


func delete_children():
	for child in get_children():
		child.queue_free()
