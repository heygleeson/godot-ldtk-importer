@tool

const EXAMPLE = preload("res://ldtk-entity-configure/entity-dict-resource/example.tres")

func post_import(level: LDTKLevel) -> LDTKLevel:
	var entity_importer : EntityImporter = EntityImporter.new()
	level.add_child(entity_importer)
	entity_importer.name = "EntityImporter"
	var entity_layer : LDTKEntityLayer = level.get_node_or_null("Entities")
	
	# Instead of calling import while it's not intialized. Create a toggle to import at runtime and set it here
	if entity_layer:
		entity_importer.entity_dict = EXAMPLE
		entity_importer.import(entity_layer)
	else:
		print("Error: No Entity Layer Found in Scene Tree")
	
	return level
