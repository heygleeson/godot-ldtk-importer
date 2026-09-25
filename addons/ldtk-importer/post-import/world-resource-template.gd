@tool

# World Post-Import Template for LDTK-Importer.

func post_import(world: LDTKWorldData) -> LDTKWorldData:
	# Behaviour goes here
	print("World: ", world)
	return world
