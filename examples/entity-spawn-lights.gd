@tool

const Light = preload("res://examples/light.tscn")

func post_import(entity_layer: LDTKEntityLayer) -> LDTKEntityLayer:
	var spawn_count: int = 0

	for entity in entity_layer.entities:
		# Perform operations here
		if entity.identifier == "LightTest":
			spawn_count += 1
			var light = Light.instantiate()
			light.position = entity.position
			light.scale = Vector2(entity.size) / Vector2(64,64)
			light.color = entity.smart_color
			light.energy = entity.fields.Energy
			if spawn_count > 1:
				light.name += str(spawn_count)
			entity_layer.add_child(light)
		pass

	return entity_layer
