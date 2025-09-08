## Flexible Entity Post-Import Template for LDTK-Importer
@tool
extends Node2D
class_name EntityImporter

# Configuration
@export var entity_layer: LDTKEntityLayer: set = _set_entity_layer
@export var entity_dict : EntityDictionary#:
@export var troubleshoot : bool = false

# Runtime
var scene_mappings: Dictionary # Scene Mappings from entity_dict, set in import
var _instance_references: Dictionary = {}	# iid -> Node

func _set_entity_layer(value: LDTKEntityLayer) -> void:
	entity_layer = value
	if Engine.is_editor_hint() and entity_layer != null:
		call_deferred("import", entity_layer)
		pass

func import(entity_layer: LDTKEntityLayer) -> LDTKEntityLayer:
	scene_mappings = entity_dict.scene_mappings
	
	_clear_import_data()
	
	# First pass: Create all instances
	for entity in entity_layer.entities:
		if not entity is Dictionary:
			continue
			
		_process_entity(entity)
	
	# Second pass: Configure relationships
	for entity in entity_layer.entities:
		if not entity is Dictionary:
			continue
			
		_configure_entity(entity)
	
	return entity_layer

func _clear_import_data() -> void:
	_instance_references.clear()
	
	# Clear existing children
	for child in get_children():
		child.queue_free()

func _process_entity(entity: Dictionary) -> void:
	var identifier : String = entity["identifier"]
	
	var scene : PackedScene = scene_mappings[identifier]
	
	if not scene:
		print("Missing scene mapping for: ", identifier)
		return
	
	var instance : Node = scene.instantiate()
	if not instance:
		return
		
	instance.global_position = entity["position"]
	add_child(instance)
	instance.name = identifier
	instance.set_owner(get_tree().edited_scene_root)
	
	_instance_references[entity["iid"]] = instance

func _configure_entity(entity: Dictionary) -> void:
	var iid = entity["iid"]
	var instance = _instance_references[iid]
	if not instance:
		return
	
	var fields = entity["fields"]
	_auto_configure_node(instance, fields)

func _auto_configure_node(node: Node, fields: Dictionary) -> void:
	# Get all valid properties with metadata
	var property_list = node.get_property_list()
	var property_info = {}
	for prop in property_list:
		property_info[prop["name"].to_lower()] = prop
	
	# Apply fields that exist on the node
	for field_name in fields:
		var property_name = field_name.to_lower()
		if not property_name in property_info:
			print("Property '%s' not found on node '%s'" % [property_name, node.name])
			continue
			
		var value = fields[field_name]
		var prop_info = property_info[property_name]
		
		# Skip if value is null (unless the property explicitly allows null)
		if value == null:
			if troubleshoot: print("Value for property '%s' is null, skipping" % property_name)
			continue
		
		# Handle enum properties
		if _is_enum_property(prop_info):
			value = _convert_to_enum_value(node, prop_info, value)
		
		# Handle NodePath references
		elif prop_info["type"] == TYPE_NODE_PATH:
			var ref_node = get_entity_by_iid(value)
			if ref_node:
				value = node.get_path_to(ref_node)
			else:
				print("Failed to resolve reference for NodePath property '%s'" % property_name)
				continue
		
		# Handle Vector2 specifically
		elif prop_info["type"] == TYPE_VECTOR2:
			value = Vector2(value[0], value[1])
		
		elif prop_info["type"] == TYPE_ARRAY:
			if value[0] in _instance_references.keys():
				var corrected_array = []
				for v in value:
					var ref_node = get_entity_by_iid(v)
					if ref_node:
						corrected_array.append(node.get_path_to(ref_node))
					else:
						print("Failed to resolve reference for NodePath property '%s'" % property_name)
						continue
				value = corrected_array
		
		if troubleshoot: print("Setting property %s (type %s) on %s to %s" % [property_name, prop_info["type"], node.name, value])
		
		node.set(property_name, value)
		

func _is_enum_property(prop_info: Dictionary) -> bool:
	# Check if property is an enum (either has enum hint or is integer with custom setter)
	return prop_info["hint"] == PROPERTY_HINT_ENUM or \
	(prop_info["type"] == TYPE_INT and prop_info["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE)

func _convert_to_enum_value(node: Node, prop_info: Dictionary, value) -> Variant:
	# If we already have an integer, use it directly
	if typeof(value) == TYPE_INT:
		return value
	
	# Handle enum strings in format "EnumType.VALUE"
	if typeof(value) == TYPE_STRING:
		if "." in value:
			var parts = value.split(".")
			if parts.size() == 2:
				value = parts[1]  # Use just the value part
		
		# Try to get enum dictionary from property hint
		if prop_info["hint"] == PROPERTY_HINT_ENUM:
			var enum_keys = prop_info["hint_string"].split(",")
			var enum_index = enum_keys.find(value)
			if enum_index != -1:
				return enum_index
		
		# Try to get enum from script constants
		var script = node.get_script()
		if script:
			# Check all script constants for a matching enum
			var constants = script.get_script_constant_map()
			for constant_name in constants:
				var constant_value = constants[constant_name]
				if constant_value is Dictionary:
					if value in constant_value:
						return constant_value[value]
	
	# Fallback to integer conversion
	if typeof(value) == TYPE_STRING and value.is_valid_int():
		return value.to_int()
	
	return value

func get_entity_by_iid(iid: String) -> Node:
	return _instance_references.get(iid)
