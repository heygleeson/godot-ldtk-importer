@tool

static func run(element: Variant, script_path: String) -> Variant:
	var element_type = typeof(element)

	if not script_path.is_empty():
		var script = load(script_path)
		if not script or not script is GDScript:
			printerr("Post-Import: '%s' is not a GDScript" % [script_path])
			return ERR_INVALID_PARAMETER

		script = script.new()
		if not script.has_method("post_import"):
			printerr("Post-Import: '%s' does not have a post_import() method" % [script_path])
			return ERR_INVALID_PARAMETER

		element = script.post_import(element)

		if element == null or typeof(element) != element_type:
			printerr("Post-Import: Invalid scene returned from script.")
			return ERR_INVALID_DATA

	return element
