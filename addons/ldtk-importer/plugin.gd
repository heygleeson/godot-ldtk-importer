@tool
extends EditorPlugin

var ldtk_plugin

func _enter_tree() -> void:
	ldtk_plugin = preload("ldtk-importer.gd").new()
	add_import_plugin(ldtk_plugin)

func _exit_tree() -> void:
	remove_import_plugin(ldtk_plugin)
	ldtk_plugin= null

