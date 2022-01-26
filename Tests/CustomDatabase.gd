extends TextDatabase

func _initialize():
	add_valid_property("single")
	is_validated = true

func _preprocess_entry(entry: Dictionary):
	entry.single_ = entry.single
	entry.erase("single")

func _custom_validate(entry: Dictionary, property: String) -> bool:
	return property.ends_with("_") and is_property_valid(entry, property.trim_suffix("_"), entry[property])

func _postprocess_entry(entry: Dictionary):
	entry.single__ = entry.single_
	entry.erase("single_")
