extends Reference
class_name TextDatabase

## Name property for an entry, i.e. you can find entry name under this property. Used as key when converting to Dictionary.
var entry_name = "name"

## ID property for the entry. Each entry has an unique ID, starting from 0.
var id_name = "id"

## Any entry must have every property from this array.
## A property might be a String or an Array [name, type]. If the latter is used, the type of property in entry will be checked. See also is_typed.
var mandatory_properties: Array

## List of valid properties for an entry. If a property is not on this list and on any other list, it's considered invalid. See also is_validated.
## Like in mandatory_properties, you can use String or Array.
var valid_properties: Array

## An entry will automatically get assigned a value from this Dictionary if it doesn't have any of the keys.
var default_properties: Dictionary

## If true, property types will be validated when possible (including checking against default properties). Automatically set to true if any mandatory or valid property has a type provided.
var is_typed: bool

## If true, properties in the entry will be checked against any provided list and raise an error if the property is not recognized.
var is_validated: bool

## Called right after creation. Can be used to setup non-constant properties etc.
func _initialize() -> void:
	pass

## Called for every entry before it is processed (validated, checked for mandatory entries etc.).
func _preprocess_entry(entry: Dictionary) -> void:
	pass

## If is_validated is true, this will be called if regular validation fails. Can be used for custom entries that follow non-standard format.
func _custom_validate(entry: Dictionary, property: String) -> bool:
	return false

## Called for every entry after it is processed.
func _postprocess_entry(entry: Dictionary) -> void:
	pass

## Returns the database as an array.
func get_array() -> Array:
	return __data

## Returns the database as a Dictionary, where entry_name is used for key. Fails if entry_name is empty and skips unnamed entries.
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

## Creates a TextDatabase from the given script and loads file under provided path. If the path is a directory, all files from that directory will be loaded, in alphabetical order.
static func load(storage_script: String, path: String) -> TextDatabase:
	var storage := load(storage_script).new() as TextDatabase
	assert(storage, "Invalid custom script: %s" % storage_script)
	
	var dir := Directory.new()
	if dir.open(path) == OK:
		dir.list_dir_begin(true)
		var file := dir.get_next()
		while file:
			storage.load_from_path("%s/%s" % [dir.get_current_dir(), file])
			file = dir.get_next()
	else:
		storage.load_from_path(path)
	
	return storage

var __data: Array
var __data_dirty: bool
var __dict: Dictionary
var __last_id: int
var __properties_validated: bool

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
		
		if is_validated:
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

func _init():
	_initialize()

func __assert_validity():
	assert(!id_name.empty(), "'id_name' can't be empty String.")
	for property in mandatory_properties:
		__validate_property(property)
	
	for property in valid_properties:
		__validate_property(property)
	
	if valid_properties.empty():
		is_validated = true

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
