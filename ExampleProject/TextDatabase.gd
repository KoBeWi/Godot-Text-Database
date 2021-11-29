extends Reference
class_name TextDatabase

var entry_name = "name"
var id_name = "id"

var mandatory_properties: Array
var valid_properties: Array
var default_properties: Dictionary
var is_typed: bool

var __data: Array
var __data_dirty: bool
var __dict: Dictionary
var __last_id: int
var __properties_validated: bool

func _init():
	_initialize()

func __assert_validity():
	assert(!id_name.empty(), "'id_name' can't be empty String.")
	for property in mandatory_properties:
		__validate_property(property)
	
	for property in valid_properties:
		__validate_property(property)

func __validate_property(property):
	if property is String:
		pass
	elif property is Array:
		is_typed = true
		assert(property.size() >= 2, "Invalid typed property: '%s'. Typed property must be an array of size 2." % property)
		assert(property[0] is String, "Invalid typed property: '%s'. First array element must by name." % property)
		assert(property[1] is int and property[1] >= 0 and property[1] < TYPE_MAX, "Invalid typed mandatory property: '%s'. Second array element must be valid TYPE_* enum value." % property)
	else:
		assert(false, "Invalid property: '%s'. Property must be String or Array [name, type]." % property)

func load_from_path(path: String):
	if not __properties_validated:
		__assert_validity()
		__properties_validated = true
	
	var data: Array
	
	match path.get_extension():
		"json":
			var file := File.new()
			file.open(path, file.READ)
			var json = parse_json(file.get_as_text())
			file.close()

			assert(json, "Parse failed, invalid JSON file: %s" % path)
			assert(json is Array, "Invalid data type. Only JSON arrays are supported.")
			data = json

			for i in data.size():
				assert(data[i] is Dictionary, "Invalid data type. JSON array must contain only Dictionaries.")
				data[i][id_name] = __last_id
				__last_id += 1
		"cfg":
			var file := ConfigFile.new()
			var error := file.load(path)
			if error != OK:
				push_error("Parse failed, invalid ConfigFile. Error code: %s" % error)
				return
			
			data = __config_file_to_array(file)
		_:
			push_error("Unrecognized extension '.%s', can't extract data." % path.get_extension())
			return
	
	for entry in data:
		_preprocess_entry(entry)

		if not entry_name.empty() and not entry_name in entry:
			push_warning("Entry has no name key (%s): %s" % [entry_name, entry])
		
		for property in mandatory_properties:
			var property_name: String

			if property is Array:
				property_name = property[0]
			else:
				property_name = property
			
			if property_name in entry:
				if is_typed and property is Array:
					assert(typeof(entry[property_name]) == property[1], "Invalid type of property '%s' in entry '%s'." % [property, entry.get(entry_name)])
			else:
				assert(false, "Missing mandatory property '%s' in entry '%s'." % [property, entry.get(entry_name)])
		
		if not valid_properties.empty():
			for property in entry:
				var valid: bool = property == entry_name or property == id_name or property in mandatory_properties or property in valid_properties or property in default_properties
				if not valid and is_typed:
					for prop in mandatory_properties:
						if prop[0] == property:
							valid = true
							break
				
				if not valid and is_typed:
					for prop in valid_properties:
						if prop[0] == property:
							assert(typeof(entry[property]) == prop[1], "Invalid type of property '%s' in entry '%s'." % [property, entry.get(entry_name)])
							valid = true
							break

				valid = valid or _custom_validate(entry, property)
				assert(valid, "Invalid property '%s' in entry '%s'." % [property, entry[entry_name]])
		
		for property in default_properties:
			if not property in entry:
				entry[property] = default_properties[property]
			else:
				assert(typeof(entry[property]) == typeof(default_properties[property]), "Invalid type of property '%s' in entry '%s'." % [property, entry.get(entry_name)])
		
		_postprocess_entry(entry)
	
	__data.append_array(data)
	__data_dirty = true

func get_array() -> Array:
	return __data

func get_dictionary() -> Dictionary:
	if entry_name.empty():
		push_error("Can't create Dictionary if data is unnamed.")
		return {}

	if __data_dirty:
		__dict.clear()
		for entry in __data:
			if not entry_name in entry:
				assert(false, "Entry has no name, can't create Dictionary key.")
				continue
			__dict[entry[entry_name]] = entry
		__data_dirty = false
	
	return __dict

func __config_file_to_array(data: ConfigFile) -> Array:
	var array: Array
	for section in data.get_sections():
		var entry := {}
		if not entry_name.empty():
			entry[entry_name] = section
		entry[id_name] = __last_id
		__last_id += 1
		
		for value in data.get_section_keys(section):
			entry[value] = data.get_value(section, value)
		
		array.append(entry)
	
	return array

func _initialize() -> void:
	pass

func _preprocess_entry(entry: Dictionary) -> void:
	pass

func _custom_validate(entry: Dictionary, property: String) -> bool:
	return false

func _postprocess_entry(entry: Dictionary) -> void:
	pass

static func load(storage_script: String, path: String) -> TextDatabase:
	var storage := load(storage_script).new() as TextDatabase
	assert(storage, "Invalid custom script: %s" % storage_script)
	storage.load_from_path(path)
	return storage
