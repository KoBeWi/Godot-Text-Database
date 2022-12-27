extends Node2D

func _ready() -> void:
	var icons := TextDatabase.new()
	# Quick-setup the database.
	icons.add_mandatory_property("color")
	icons.add_default_property("scale", Vector2.ONE)
	icons.add_default_property("scalef", 1.0)
	# Load icon data from 2 files.
	icons.load_from_path("Icons.cfg")
	icons.load_from_path("Icons.json")
	
	# Create icons, reading their color and scale from the database.
	for entry in icons.get_array():
		var icon := Sprite2D.new()
		icon.name = entry.name
		icon.texture = preload("res://icon.png")
		icon.position = Vector2(64, 64 + get_child_count() * 72)
		icon.modulate = Color(entry.color)
		icon.scale = entry.scale * entry.scalef
		add_child(icon)
	
	# Load weapons from custom database.
	var weapons := TextDatabase.load_database("res://CustomDatabase.gd", "res://Weapons.cfg")
	
	# Create weapons, using proper icons and element colors.
	for entry in weapons.get_array():
		var icon := Sprite2D.new()
		icon.texture = entry.icon
		icon.position = Vector2(192, 64 + (get_child_count() - icons.size()) * 72)
		add_child(icon)
		
		var label := Label.new()
		label.text = entry.name
		label.position = Vector2(40, 0)
		label.modulate = [Color.RED, Color.AQUA, Color.VIOLET][entry.element]
		icon.add_child(label)
