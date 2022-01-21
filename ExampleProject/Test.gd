extends Node2D

func _ready() -> void:
	var icons := TextDatabase.new()
	icons.mandatory_properties = ["color"]
	icons.default_properties = {"scale": Vector2(1, 1), "scalef": 1.0}
	icons.load_from_path("Icons.cfg")
	icons.load_from_path("Icons.json")
	
	# Create icons, reading their color and scale from the database.
	for entry in icons.get_array():
		var icon := Sprite.new()
		icon.name = entry.name
		icon.texture = preload("res://icon.png")
		icon.position = Vector2(64, 64 + get_child_count() * 72)
		icon.modulate = Color(entry.color)
		icon.scale = entry.scale * entry.scalef
		add_child(icon)
	
	# Load weapons from custom database.
	var weapons := TextDatabase.load("res://CustomDatabase.gd", "res://Weapons.cfg")
	
	# Create weapons, using proper icons and element colors.
	for entry in weapons.get_array():
		var icon := Sprite.new()
		icon.texture = entry.icon
		icon.position = Vector2(192, 64 + (get_child_count() - icons.size()) * 72)
		add_child(icon)
		
		var label := Label.new()
		label.text = entry.name
		label.rect_position = Vector2(40, 0)
		label.modulate = [Color.red, Color.aqua, Color.violet][entry.element]
		icon.add_child(label)
