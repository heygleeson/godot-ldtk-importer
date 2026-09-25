@tool
extends EditorPlugin

var ldtk_plugin
var ldtk_resource_plugin
var config = ConfigFile.new()


func _enter_tree() -> void:
	ldtk_plugin = preload("ldtk-importer.gd").new()
	ldtk_resource_plugin = preload("ldtk-resource-importer.gd").new()
	add_import_plugin(ldtk_plugin)
	add_import_plugin(ldtk_resource_plugin)

	var config = ConfigFile.new()
	var err = config.load("res://addons/ldtk-importer/plugin.cfg")
	var version = config.get_value("plugin", "version", "0.0")

	print_rich(
		(
			"[color=#ffcc00]█ Godot-LDtk-Importer █[/color] %s | [url=https://gleeson.dev]@gleeson.dev[/url] | [url=https://github.com/heygleeson/godot-ldtk-importer]View on Github[/url]"
			% [version]
		)
	)


func _exit_tree() -> void:
	remove_import_plugin(ldtk_plugin)
	remove_import_plugin(ldtk_resource_plugin)
	ldtk_plugin = null
	ldtk_resource_plugin = null
