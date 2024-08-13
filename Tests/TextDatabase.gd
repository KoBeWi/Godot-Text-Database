extends RefCounted
class_name TextDatabase

## A class for loading and validating data.

## TextDatabase supports cfg and json files. It loads arrays of dictionaries (entries) and validates their properties. The idea is that you write stuff by hand and the TextDatabase ensures you didn't make any mistakes.
## There are 2 types of properties for each entry: mandatory that need to be included in every entry and valid, which are just properties allowed to be in an entry. Properties can be typed.
## Note that none of the data validation is performed in release builds.

## ID property for the entry. Each entry has an unique ID, starting from 0.
var id_name := "id"

## Name property for an entry, i.e. you can find entry name under this property. Used as key when converting to Dictionary.
var entry_name := "name"

## If true, property types will be validated when possible (including checking against default properties). Automatically set to true if any mandatory or valid property has a type provided.
var is_typed: bool

## If false, int values are allowed for float fields.
var is_strict: bool

## If true, properties in the entry will be checked against 'mandatory' and 'valid' lists and raise an error if the property is not recognized. Automatically set to true if any valid property was defined.
var is_validated: bool

## Alternative for using [method _preprocess_entry]. You can assign it a lambda method. Less type-safe, not recommended.
var preprocess_entry: Callable

## Alternative for using [method _additional_validate]. You can assign it a lambda method. Less type-safe, not recommended.
var additional_validate: Callable

## Alternative for using [method _reserve_validate]. You can assign it a lambda method. Less type-safe, not recommended.
var reserve_validate: Callable

## Alternative for using [method _postprocess_entry]. You can assign it a lambda method. Less type-safe, not recommended.
var postprocess_entry: Callable

## Creates the list of valid properties based on a [RefCounted] object instance. [param constructor] should be a method that returns an instance of the target class. It can be its [code]new[/code] method:
## [codeblock]
## var db := TextDatabase.new()
## db.define_from_struct(Item.new)
## [/codeblock]
## Calling this method is required to use [method get_struct_array] and [method get_struct_dictionary].
func define_from_struct(constructor: Callable):
	__struct_constructor = constructor
	if not OS.is_debug_build():
		return

	is_typed = true
	is_validated = true
	
	var struct: RefCounted = __struct_constructor.call()
	for property in struct.get_property_list():
		if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		
		var property_name: String = property["name"]
		add_default_property(property_name, struct.get(property_name))

## Makes an existing property mandatory. Requires [method define_from_struct] to be called first. Used to customize struct properties.
func override_property_mandatory(property: String):
	assert(__struct_constructor.is_valid(), "define_from_struct() needs to be called first to override properties.")
	
	for p in __valid_properties:
		if p[0] == property:
			__mandatory_properties.append(p)
			return
	
	push_error("Failed to override property %s: does not exist.", property)

## Changes the validated type of a property. Requires [method define_from_struct] to be called first. Used to customize struct properties, in case when the actual type can't be stored as text. When overriding type, make sure to assign correct value using [method _postprocess_entry].
func override_property_type(property: String, type: int):
	assert(__struct_constructor.is_valid(), "define_from_struct() needs to be called first to override properties.")
	
	for p in __valid_properties:
		if p[0] == property:
			p[1] = type
			__default_values.erase(property)
			return
	
	push_error("Failed to override property %s: does not exist.", property)

## Adds a valid property with optionally provided type.
func add_valid_property(property: String, type: int = TYPE_MAX):
	assert(not __property_exists(property), "Property '%s' already exists." % property)
	__valid_properties.append([property, type])

## Adds a mandatory property with optionally provided type. The property is also added to valid properties.
func add_mandatory_property(property: String, type: int = TYPE_MAX):
	assert(not __property_exists(property), "Property '%s' already exists." % property)
	__mandatory_properties.append([property, type])
	__valid_properties.append([property, type])

## Adds a valid property with a default value. Enforces type, unless [param typed] is false.
func add_default_property(property: String, default, typed := true):
	add_valid_property(property, typeof(default) if typed else TYPE_MAX)
	__default_values[property] = default

## Virtual. Called right after creation. Can be used to setup database properties or some data required by the database (e.g. dependencies).
## [br][br]If using structs, call [method define_from_struct] here.
func _initialize() -> void:
	pass

## Virtual. Called right after creation and after [method _initialize], in debug builds. Use it to define properties.
func _schema_initialize() -> void:
	pass

## Virtual. Called for every entry before it is processed (validated, checked for mandatory entries etc.).
func _preprocess_entry(entry: Dictionary) -> void:
	pass

## Virtual. If is_validated is true, this will be called in addition to regular validation. Useful for providing special rules that aren't possible by default.
func _additional_validate(entry: Dictionary, property: String) -> String:
	return ""

## Virtual. If is_validated is true, this will be called if regular validation fails. Can be used for custom entries that follow non-standard format.
func _reserve_validate(entry: Dictionary, property: String) -> bool:
	return false

## Virtual. Called for every entry after it is processed.
func _postprocess_entry(entry: Dictionary) -> void:
	pass

## Returns the database as an array of Dictionary entries.
func get_array() -> Array[Dictionary]:
	return __data

## Returns the database as a Dictionary, where [member entry_name] is used for key and the loaded entries are values. Fails if [member entry_name] is empty. Use [member skip_unnamed] to automatically skip unnamed entries.
func get_dictionary(skip_unnamed := false) -> Dictionary:
	if entry_name.is_empty():
		push_error("Can't create Dictionary if data is unnamed.")
		return {}

	if __data_dirty:
		__dict.clear()
		for entry in __data:
			if not entry_name in entry:
				assert(not skip_unnamed, "Entry has no name, can't create Dictionary key.")
				continue
			
			assert(not entry[entry_name] in __dict, "Duplicate entry name: %s" % entry[entry_name])
			
			__dict[entry[entry_name]] = entry
		__data_dirty = false
	
	return __dict

## Same as [method get_array], but the entries are returned as the designated structs, instead of Dictionaries. [method define_from_struct] has to be called before using this method.
func get_struct_array() -> Array[RefCounted]:
	var ret: Array[RefCounted]
	if __struct_constructor.is_null():
		push_error("define_from_struct() needs to be called first to get struct Array.")
		return ret
	
	ret.assign(__data.map(__make_struct))
	return ret

## Same as [method get_dictionary], but the entries (values) are returned as the designated structs, instead of Dictionaries. [method define_from_struct] has to be called before using this method.
func get_struct_dictionary(skip_unnamed := false) -> Dictionary:
	if __struct_constructor.is_null():
		push_error("define_from_struct() needs to be called first to get struct Dictionary.")
		return {}
	
	var ret := get_dictionary(skip_unnamed)
	for key in ret:
		ret[key] = __make_struct(ret[key])
	return ret

## Returns number of entries in the database.
func size() -> int:
	return __data.size()

## Returns whether the property is valid.
func is_property_valid(entry: Dictionary, property: String, value = null) -> bool:
	if value == null:
		value = entry[property]
	
	var valid: bool = property == entry_name or property == id_name
	if not valid:
		for prop in __valid_properties:
			if prop[0] == property:
				assert(not is_typed or __match_type(typeof(value), prop[1]), "Invalid type of property '%s' in entry '%s'." % [property, entry.get(entry_name)])
				valid = true
				break
	
	if valid:
		var error: String
		if additional_validate.is_valid():
			error = additional_validate.call(entry, property)
		else:
			error = _additional_validate(entry, property)
		assert(error.is_empty(), "'%s' in entry '%s': %s" % [property, entry[entry_name], error])
	
	if not valid:
		if reserve_validate.is_valid():
			valid = reserve_validate.call(entry, property)
		else:
			valid = _reserve_validate(entry, property)

	return valid

## Creates a TextDatabase from the given script and loads file(s) under provided path.
static func load_database(database_script: String, path: String) -> TextDatabase:
	var storage := load(database_script).new() as TextDatabase
	assert(storage, "Invalid custom script: %s" % database_script)
	storage.load_from_path(path)
	return storage

## Loads data from the given path. Can be called multiple times on different files and the new data will be appended to the database with incrementing IDs.
## If the path is a directory, all files from that directory will be loaded, in alphabetical order.
func load_from_path(path: String):
	var dir := DirAccess.open(path)
	if dir:
		var file_list: Array[String]
		
		dir.list_dir_begin()
		var file := dir.get_next()
		while not file.is_empty():
			if not dir.current_is_dir():
				file_list.append(dir.get_current_dir().path_join(file))
			file = dir.get_next()
		
		file_list.sort()
		for file_path in file_list:
			load_from_path(file_path)
		
		return
	
	if not __did_setup:
		__setup()
		__did_setup = true
	
	var data: Array
	
	match path.get_extension():
		"json":
			var file := FileAccess.open(path, FileAccess.READ)
			var json = JSON.parse_string(file.get_as_text())
			
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
			assert(error == OK, "Parse failed, invalid ConfigFile \"%s\". Error code: %s" % [path, error])
			
			data = __config_file_to_array(file)
		_:
			push_error("Unrecognized extension '.%s', can't extract data." % path.get_extension())
			return
	
	for entry in data:
		for property in __default_values:
			if not property in entry:
				var default = __default_values[property]
				if default is Array or default is Dictionary:
					entry[property] = default.duplicate()
				else:
					entry[property] = default
		
		if preprocess_entry.is_valid():
			preprocess_entry.call(entry)
		else:
			_preprocess_entry(entry)
		
		if not entry_name.is_empty() and not entry_name in entry:
			push_warning("Entry has no name key (%s): %s" % [entry_name, entry])
		
		for property in __mandatory_properties:
			var property_name: String = property[0]
			
			if property_name in entry:
				if is_typed:
					assert(__match_type(typeof(entry[property_name]), property[1]), "Invalid type of property '%s' in entry '%s'." % [property_name, entry.get(entry_name)])
			else:
				assert(false, "Missing mandatory property '%s' in entry '%s'." % [property_name, entry.get(entry_name)])
		
		if is_validated and OS.is_debug_build():
			for property in entry:
				assert(is_property_valid(entry, property), "Invalid property '%s' in entry '%s'." % [property, entry[entry_name]])
		
		if postprocess_entry.is_valid():
			postprocess_entry.call(entry)
		else:
			_postprocess_entry(entry)
	
	__data.append_array(data)
	__data_dirty = true

var __data: Array[Dictionary]
var __data_dirty: bool
var __dict: Dictionary
var __last_id: int
var __did_setup: bool

var __struct_constructor: Callable
var __mandatory_properties: Array[Array]
var __valid_properties: Array[Array]
var __default_values: Dictionary

func _init():
	_initialize()
	if OS.is_debug_build():
		_schema_initialize()

func __setup():
	if not OS.is_debug_build():
		return
	
	assert(not id_name.is_empty(), "'id_name' can't be empty String.")
	
	for property in __valid_properties:
		if property[1] != TYPE_MAX:
			is_typed = true
	
	if not __valid_properties.is_empty():
		is_validated = true

func __make_struct(entry: Dictionary) -> RefCounted:
	var struct: RefCounted = __struct_constructor.call()
	for property in entry:
		struct.set(property, entry[property])
	return struct

func __match_type(type1: int, type2: int) -> bool:
	if type1 == TYPE_MAX or type2 == TYPE_MAX:
		return true
	
	if is_strict:
		return type1 == type2
	else:
		return type1 == type2 or (type1 == TYPE_INT and type2 == TYPE_FLOAT)

func __property_exists(property: String) -> bool:
	for p in __valid_properties:
		if p[0] == property:
			return true
	
	return false

func __config_file_to_array(data: ConfigFile) -> Array[Dictionary]:
	var array: Array[Dictionary]
	for section in data.get_sections():
		var entry := {id_name: __last_id}
		if not entry_name.is_empty():
			entry[entry_name] = section
		__last_id += 1
		
		for value in data.get_section_keys(section):
			entry[value] = data.get_value(section, value)
		
		array.append(entry)
	
	return array
