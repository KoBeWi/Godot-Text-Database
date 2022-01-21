extends Node

func _ready() -> void:
	var database := TextDatabase.new()
	database.load_from_path("res://DataFolder")
	var expected := ["Entry 1", "Entry 2", "Entry 3", "Entry 4", "Entry 5", "Entry 6", "Entry 7", "Entry 8"]
	var data_array := database.get_array()
	
	for i in expected.size():
		assert(data_array[i].name == expected[i])
