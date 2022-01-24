extends TextDatabase

enum Elements {FIRE, ICE, THUNDER}

func _initialize():
	add_mandatory_property("icon", TYPE_STRING)
	add_valid_property("element", TYPE_STRING)
	add_valid_property("attack", TYPE_INT)

func _postprocess_entry(entry: Dictionary):
	entry.element = Elements.keys().find(entry.element)
	entry.icon = load("res://" + entry.icon + ".png")
