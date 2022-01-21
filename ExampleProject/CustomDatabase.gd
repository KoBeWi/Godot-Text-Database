extends TextDatabase

enum Elements {FIRE, ICE, THUNDER}

func _initialize():
	mandatory_properties = [["icon", TYPE_STRING]]
	valid_properties = [["element", TYPE_STRING], ["attack", TYPE_INT]]

func _postprocess_entry(entry: Dictionary):
	entry.element = Elements.keys().find(entry.element)
	entry.icon = load("res://" + entry.icon + ".png")
