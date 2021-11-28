extends Reference
class_name TextDatabase

var entry_name = "name"
var id_name = "id"

var mandatory_properties: Array
var valid_properties: Array
var default_properties: Dictionary

var __data: Array
var __data_dirty: bool
var __dict: Dictionary
var __last_id: int
var __properties_validated: bool
var __is_typed: bool

func _init():
	_initialize()

func __assert_validity() -> bool:
	assert(!id_name.empty(), "'id_name' can't be empty String."
	for property in mandatory_properties:
		if property is String:
			pass
		elif property is Array:
			__is_typed = true
			assert(property[0] is String, str("Invalid mandatory property: '", property, "'"))
			assert(property[1] is int and property[1] >= 0 and property[1] < TYPE_MAX, str("Invalid mandatory property: '", property, "'"))
		else:
			assert(false, str("Invalid mandatory property: '", property, "'"))
	
	for property in valid_properties:
		if property is String:
			pass
		elif property is Array:
			__is_typed = true
			assert(property[0] is String, str("Invalid mandatory property: '", property, "'"))
			assert(property[1] is int and property[1] >= 0 and property[1] < TYPE_MAX, str("Invalid mandatory property: '", property, "'"))
		else:
			assert(false, str("Invalid mandatory property: '", property, "'"))

func __find_property(property: String, list: Array) -> bool:
	
	return false

func load_from_path(path: String):
	if not __properties_validated:
		if not __assert_validity():
			return
		__properties_validated = true
	
	var data: Array
	
	match path.get_extension():
		"json":
			var file := File.new()
			file.open(path, file.READ)
			data = parse_json(file.get_as_text())
			file.close()

			assert(data, str("Parse failed, invalid JSON file: ", path))
			assert(data is Array, "Invalid data type. Only JSON arrays are supported.")

			for i in data.size():
				assert(data[i] is Dictionary, "Invalid data type. JSON array must contain only Dictionaries.")
				data[i][id_name] = __last_id
				__last_id += 1
		"cfg":
			var file := ConfigFile.new()
			var error := file.load(path)
			if error != OK:
				push_error("Parse failed, invalid ConfigFile. Error code: " + str(error))
				return
			
			data = __config_file_to_array(file)
		_:
			push_error("Unrecognized extension ." + path.get_extension() + ", can't extract data.")
			return
	
	for entry in data:
		_preprocess_entry(entry)

		if not entry_name.empty() and not entry_name in entry:
			push_warning(str("Entry has no name key (", entry_name, "): ", entry))
		
		for property in mandatory_properties:
			var property_name: String

			if property is Array:
				property_name = property[0]
			else:
				property_name = property
			
			if property_name in entry:
				if __is_typed and property is Array:
					assert(typeof(entry[property_name]) == property[1], "Invalid type of property '", property, "' in entry '", entry.get(entry_name), "'")
			else:
				assert(false, str("Missing mandatory property '", property, "' in entry '", entry.get(entry_name), "'"))
		
		if not valid_properties.empty():
			for property in entry:
				var valid: bool = property == entry_name or property == id_name or property in mandatory_properties or property in valid_properties or property in default_properties
				if not valid and __is_typed:
					for prop in mandatory_properties:
						if prop[0] == property:
							valid = true
							break
				
				if not valid and __is_typed:
					for prop in valid_properties:
						if prop[0] == property:
							assert(typeof(entry[property_name]) == property[1], "Invalid type of property '", property, "' in entry '", entry.get(entry_name), "'")
							valid = true
							break

				valid = valid or _custom_validate(entry, property)
				assert(valid, str("Invalid property '", property, "' in entry '", entry[entry_name], "'"))
		
		for property in default_properties:
			if not property in entry:
				entry[property] = default_properties[property]
		
		_postprocess_entry(entry)
	
	__data.append_array(data)
	__data_dirty = true

func get_array() -> Array:
	return __data

func get_dictionary() -> Dictionary:
	if entry_name.empty():
		push_error("Can't create Dictionary if data is unnamed."
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
	assert(storage, "Invalid custom script: " + storage_script)
	storage.load_from_path(path)
	return storage