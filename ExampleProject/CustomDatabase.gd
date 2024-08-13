extends TextDatabase

enum Element {FIRE, ICE, THUNDER}

func _schema_initialize():
	add_mandatory_property("icon", TYPE_STRING)
	add_valid_property("element", TYPE_STRING)
	add_valid_property("attack", TYPE_INT)

func _postprocess_entry(entry: Dictionary):
	entry.element = Element[entry.element]
	entry.icon = load("res://" + entry.icon + ".png")
