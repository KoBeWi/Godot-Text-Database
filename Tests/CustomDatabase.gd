extends TextDatabase

func _schema_initialize():
	add_valid_property("single")

func _preprocess_entry(entry: Dictionary):
	entry.single_ = entry.single
	entry.erase("single")

func _additional_validate(entry: Dictionary, property: String) -> String:
	if property.length() >= 5 and not property.ends_with("e"):
		return "This is wrong."
	return ""

func _reserve_validate(entry: Dictionary, property: String) -> bool:
	return property.ends_with("_") and is_property_valid(entry, property.trim_suffix("_"), entry[property])

func _postprocess_entry(entry: Dictionary):
	entry.single__ = entry.single_
	entry.erase("single_")
