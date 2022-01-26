extends Reference
class_name TextDatabase

## ID property for the entry. Each entry has an unique ID, starting from 0.
var id_name = "id"

## Name property for an entry, i.e. you can find entry name under this property. Used as key when converting to Dictionary.
var entry_name = "name"

## Any entry must have every property from this array.
## A property might be a String or an Array [name, type]. If the latter is used, the type of property in entry will be checked. See also is_typed.
var mandatory_properties: Array

## List of valid properties for an entry. If a property is not on this list and on any other list, it's considered invalid. See also is_validated.
## Like in mandatory_properties, you can use String or Array.
var valid_properties: Array

## An entry will automatically get assigned a value from this Dictionary if it doesn't have any of the keys.
var default_values: Dictionary

## If true, property types will be validated when possible (including checking against default properties). Automatically set to true if any mandatory or valid property has a type provided.
## If is_strict is true, int values will fail for float fields
var is_typed: bool
var is_strict: bool

## If true, properties in the entry will be checked against 'mandatory' and 'valid' lists and raise an error if the property is not recognized. Automatically set to true if valid_properties list is not empty.
var is_validated: bool

## Helper for adding mandatory properties.
func add_mandatory_property(property: String, type: int = TYPE_MAX):
	if type == TYPE_MAX:
		assert(not __property_exists(property), "Property '%s' already exists in mandatory properties." % property)
		mandatory_properties.append(property)
	else:
		assert(not __property_exists(property), "Property '%s' already exists in mandatory properties." % property) ## TODO: sprawdzać samą nazwę
		mandatory_properties.append([property, type])

## Helper for adding valid properties.
func add_valid_property(property: String, type: int = TYPE_MAX):
	if type == TYPE_MAX:
		assert(not __property_exists(property), "Property '%s' already exists in valid properties." % property)
		valid_properties.append(property)
	else:
		assert(not __property_exists(property), "Property '%s' already exists in valid properties." % property)
		valid_properties.append([property, type])

## Helper for adding valid properties with defaults.
func add_valid_property_with_default(property: String, default, typed := true):
	add_valid_property(property, typeof(default) if typed else TYPE_MAX)
	default_values[property] = default

## Helper for adding default properties.
func add_default_value(property: String, value):
	default_values[property] = value

## Virtual. Called right after creation. Can be used to setup lists etc.
func _initialize() -> void:
	pass

## Virtual. Called for every entry before it is processed (validated, checked for mandatory entries etc.).
func _preprocess_entry(entry: Dictionary) -> void:
	pass

## Virtual. If is_validated is true, this will be called in addition to regular validation. Useful for providing special rules that aren't possible by default.
func _additional_validate(entry: Dictionary, property: String) -> bool:
	return true

## Virtual. If is_validated is true, this will be called if regular validation fails. Can be used for custom entries that follow non-standard format.
func _reserve_validate(entry: Dictionary, property: String) -> bool:
	return false

## Virtual. Called for every entry after it is processed.
func _postprocess_entry(entry: Dictionary) -> void:
	pass

## Returns the database as an array.
func get_array() -> Array:
	return __data

## Returns the database as a Dictionary, where entry_name is used for key. Fails if entry_name is empty. Use skip_unnamed to automatically skip unnamed entries.
func get_dictionary(skip_unnamed := false) -> Dictionary:
	if entry_name.empty():
		push_error("Can't create Dictionary if data is unnamed.")
		return {}

	if __data_dirty:
		__dict.clear()
		for entry in __data:
			if not entry_name in entry:
				assert(not skip_unnamed, "Entry has no name, can't create Dictionary key.")
				continue
			__dict[entry[entry_name]] = entry
		__data_dirty = false
	
	return __dict

## Number of entries.
func size() -> int:
	return __data.size()

## Returns whether the property is valid.
func is_property_valid(entry: Dictionary, property: String, value = null) -> bool:
	if not OS.has_feature("debug"):
		return true
	
	if value == null:
		value = entry[property]
	
	var valid: bool = property == entry_name or property == id_name or property in mandatory_properties or property in valid_properties
	if not valid and is_typed:
		for prop in mandatory_properties:
			if prop[0] == property:
				valid = true
				break
	
	if not valid and is_typed:
		for prop in valid_properties:
			if prop[0] == property:
				assert(__match_type(typeof(value), prop[1]), "Invalid type of property '%s' in entry '%s'." % [property, entry.get(entry_name)])
				valid = true
				break
	
	return valid and _additional_validate(entry, property) or _reserve_validate(entry, property)

## Creates a TextDatabase from the given script and loads file(s) under provided path.
static func load(storage_script: String, path: String) -> TextDatabase:
	var storage := load(storage_script).new() as TextDatabase
	assert(storage, "Invalid custom script: %s" % storage_script)
	storage.load_from_path(path)
	return storage

## Loads data from the given path. Can be called multiple times on different files and the new data will be appended to the database with incrementing IDs.
## If the path is a directory, all files from that directory will be loaded, in alphabetical order.
func load_from_path(path: String):
	var dir := Directory.new()
	if dir.open(path) == OK:
		var file_list: Array
		
		dir.list_dir_begin(true)
		var file := dir.get_next()
		while file:
			if not dir.current_is_dir():
				file_list.append("%s/%s" % [dir.get_current_dir(), file])
			file = dir.get_next()
		
		file_list.sort()
		for file_path in file_list:
			load_from_path(file_path)
		
		return
	
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
			assert(error == OK, "Parse failed, invalid ConfigFile. Error code: %s" % error)
			
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
					assert(__match_type(typeof(entry[property_name]), property[1]), "Invalid type of property '%s' in entry '%s'." % [property_name, entry.get(entry_name)])
			else:
				assert(false, "Missing mandatory property '%s' in entry '%s'." % [property, entry.get(entry_name)])
		
		if is_validated:
			for property in entry:
				assert(is_property_valid(entry, property), "Invalid property '%s' in entry '%s'." % [property, entry[entry_name]])
		
		for property in default_values:
			if not property in entry:
				entry[property] = default_values[property]
		
		_postprocess_entry(entry)
	
	__data.append_array(data)
	__data_dirty = true

var __data: Array
var __data_dirty: bool
var __dict: Dictionary
var __last_id: int
var __properties_validated: bool

func _init():
	_initialize()

func __assert_validity():
	if not OS.has_feature("debug"):
		return
	
	assert(!id_name.empty(), "'id_name' can't be empty String.")
	
	for property in mandatory_properties:
		__validate_property(property)
	
	for property in valid_properties:
		__validate_property(property)
	
	if not valid_properties.empty():
		is_validated = true
	
	for property in default_values:
		assert(property is String, "Default value key '%s' is not a String." % property)
		var value = default_values[property]
		
		var valid: bool
		for property2 in mandatory_properties:
			if property2 is Array:
				if property2[0] == property:
					valid = true
					assert(not is_typed or __match_type(typeof(value), property2[1]), "Default value '%s' has wrong type." % property)
			else:
				valid = valid or property == property2
		
		for property2 in valid_properties:
			if property2 is Array:
				if property2[0] == property:
					valid = true
					assert(not is_typed or __match_type(typeof(value), property2[1]), "Default value '%s' has wrong type." % property)
			else:
				valid = valid or property == property2
		
		assert(not is_validated or valid, "Default value '%s' is not recognized." % property)

func __validate_property(property):
	if not OS.has_feature("debug"):
		return
	
	if property is String:
		pass
	elif property is Array:
		is_typed = true
		assert(property.size() >= 2, "Invalid typed property: '%s'. Typed property must be an array of size 2." % property[0])
		assert(property[0] is String, "Invalid typed property: '%s'. First array element must by name." % property[0])
		assert(property[1] is int and property[1] >= 0 and property[1] < TYPE_MAX, "Invalid typed mandatory property: '%s'. Second array element must be valid TYPE_* enum value." % property[0])
	else:
		assert(false, "Invalid property: '%s'. Property must be String or Array [name, type]." % property)

func __match_type(type1: int, type2: int) -> bool:
	if is_strict:
		return type1 == type2
	else:
		return type1 == type2 or (type1 == TYPE_INT and type2 == TYPE_REAL)

func __property_exists(property: String) -> bool:
	for p in mandatory_properties:
		if p is String and p == property:
			return true
		elif p is Array and p[0] == property:
			return true

	for p in valid_properties:
		if p is String and p == property:
			return true
		elif p is Array and p[0] == property:
			return true
	
	return false

func __config_file_to_array(data: ConfigFile) -> Array:
	var array: Array
	for section in data.get_sections():
		var entry := {id_name: __last_id}
		if not entry_name.empty():
			entry[entry_name] = section
		__last_id += 1
		
		for value in data.get_section_keys(section):
			entry[value] = data.get_value(section, value)
		
		array.append(entry)
	
	return array