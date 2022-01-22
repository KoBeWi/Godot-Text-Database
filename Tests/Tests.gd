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
	var loaded_dict: Dictionary = database.get_array()[0]
	var target_dict := {id = 0, test = "Entry", single = true}
	
	assert(loaded_dict.hash() == target_dict.hash())
	
	database = TextDatabase.new()
	database.id_name = "test"
	database.load_from_path("res://SingleEntry.cfg")
	loaded_dict = database.get_array()[0]
	target_dict = {test = 0, name = "Entry", single = true}
	
	assert(loaded_dict.hash() == target_dict.hash())
	
	database = TextDatabase.new()
	database.mandatory_properties = ["mandatory"]
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.mandatory_properties = [["mandatory", TYPE_INT]]
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.valid_properties = ["mandatory"]
	database.load_from_path("res://SingleEntry2.cfg")
	
	database = TextDatabase.new()
	database.valid_properties = [["mandatory", TYPE_INT]]
	database.load_from_path("res://SingleEntry2.cfg")
