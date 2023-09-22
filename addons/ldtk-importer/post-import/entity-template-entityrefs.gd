@tool

## Entity Post Import Example, showcasing how to handle EntityRefs.

const Util = preload("res://addons/ldtk-importer/src/util/util.gd")
const SceneTest = preload("res://node_test.tscn")

func post_import(entity_layer: LDTKEntityLayer) -> LDTKEntityLayer:
	var entities: Array = entity_layer.entities
	for entity in entities:
		# Create entity node (simple example)
		var scene = SceneTest.instantiate()
		entity_layer.add_child(scene)

		# Update 'iid' to reference this entity node
		Util.update_instance_reference(entity.iid, scene)

		# Add unresolved reference (e.g. EntityRef field)
		if "Entity_ref" in entity.fields:
			var ref = entity.fields.Entity_ref
			if ref != null:
				scene.ref = ref
				Util.add_unresolved_reference(scene, "ref")

	return entity_layer
