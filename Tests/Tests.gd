extends Node

func _ready() -> void:
	var database := TextDatabase.new()
	database.load_from_path("res://DataFolder")
	var expected := ["Entry 1", "Entry 2", "Entry 3", "Entry 4", "Entry 5", "Entry 6", "Entry 7", "Entry 8"]
	var data_array := database.get_array()
	
	for i in expected.size():
		assert(data_array[i].name == expected[i])
	
	database = TextDatabase.new()
	database.entry_name = "test"
	database.load_from_path("res://SingleEntry.cfg")
	var loaded_dict: Dictionary = database.get_array().front()
	var target_dict := {id = 0, test = "Entry", single = true}
	
	assert(loaded_dict.hash() == target_dict.hash())
	
	database = TextDatabase.new()
	database.id_name = "test"
	database.load_from_path("res://SingleEntry.cfg")
	loaded_dict = database.get_array().front()
	target_dict = {test = 0, name = "Entry", single = true}
	
	assert(loaded_dict.hash() == target_dict.hash())
	
	database = TextDatabase.new()
	database.add_mandatory_property("mandatory")
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.add_mandatory_property("mandatory", TYPE_INT)
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.add_valid_property("mandatory")
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.add_valid_property("mandatory", TYPE_INT)
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.add_default_property("default", 1)
	database.add_default_property("mandatory", 0)
	database.load_from_path("res://SingleEntry2.cfg")
	
	assert(database.get_array().front().default == 1)
	assert(database.get_array().front().mandatory == 1)
	
	database = TextDatabase.new()
	database.add_default_property("mandatory", 15)
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.add_default_property("mandatory", "test", false)
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
#	database.is_strict = true
	database.add_mandatory_property("mandatory", TYPE_FLOAT)
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.load_from_path("res://Jason.json")
	loaded_dict = database.get_array().front()
	target_dict = {name = "Entry", type = "Test", value = 1.0, id = 0}
	
	assert(loaded_dict.hash() == target_dict.hash())
	
	database = TextDatabase.load_database("res://CustomDatabase.gd", "res://SingleEntry.cfg")
	assert(database.get_array().front().single__ == true)
	
	database = TextDatabase.new()
	database.define_from_struct(Somethinger.new)
	database.load_from_path("res://DataFolder/Data1.cfg")
	
	var loaded_array: Array[Somethinger]
	loaded_array.assign(database.get_struct_array())
	
	assert(loaded_array[0].something)
	
	loaded_dict = database.get_struct_dictionary()
	var sth: Somethinger = loaded_dict["Entry 1"]
	
	assert(sth.something)

class Somethinger:
	var something: bool
