@tool

## EntityLayer Post-Import: Add Lights
## NOTE: This is currently used by /examples/gridvania.ldtk. Please do not edit directly.
## Creates Light nodes on all 'LightTest' entities.

const Light = preload("res://examples/light.tscn")

# Used to update entity reference
const LDTKUtil = preload("res://addons/ldtk-importer/src/util/util.gd")

func post_import(entity_layer: LDTKEntityLayer) -> LDTKEntityLayer:
	# This is used to supply a index suffix to the node name (e.g. "Light2", "Light3", etc.)
	var spawn_count: int = 0

	# Loop though the 'entities' Dictionary on the EntityLayer
	for entity in entity_layer.entities:
		# Find 'LightTest' entity
		if entity.identifier == "LightTest":
			# Create a new Light instance.
			var light = Light.instantiate()

			# Copy fields over to the new instance.
			light.name = entity.identifier
			light.position = entity.position
			light.scale = Vector2(entity.size) / Vector2(64,64)
			light.color = entity.smart_color
			light.energy = entity.fields.Energy

			# Give it a unique name (using the index suffix)
			spawn_count += 1
			if spawn_count > 1:
				light.name += str(spawn_count)

			# Add instance to the EntityLayer node.
			entity_layer.add_child(light)

			# Update Entity Reference
			LDTKUtil.update_instance_reference(entity.iid, light)

	return entity_layer
