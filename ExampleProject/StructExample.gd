extends Node2D

class Weapon:
	enum Element {FIRE, ICE, THUNDER}
	
	var name: String
	var attack: int
	
	var element: Element
	var icon: Texture2D
	
	func get_element_color() -> Color:
		return [Color.RED, Color.AQUA, Color.VIOLET][element]

func _ready() -> void:
	# This is more or less the same as in Example.gd, except the custom database is created ad hoc instead.
	var weapons := TextDatabase.new()
	# Bind the struct.
	weapons.define_from_struct(Weapon.new)
	# Override some properties (enums and textures can't be loaded as is).
	weapons.override_property_type("icon", TYPE_STRING)
	weapons.override_property_type("element", TYPE_STRING)
	
	# Assign a post-processing lambda.
	weapons.postprocess_entry = func(entry: Dictionary):
		entry.element = Weapon.Element[entry.element]
		entry.icon = load("res://" + entry.icon + ".png")
	
	weapons.load_from_path("res://Weapons.cfg")
	
	# Create weapons, using proper icons and element colors.
	for entry: Weapon in weapons.get_struct_array():
		var icon := Sprite2D.new()
		icon.texture = entry.icon # <- Notice safe lines :D
		icon.position = Vector2(192, 64 + get_child_count() * 72)
		add_child(icon)
		
		var label := Label.new()
		label.text = entry.name
		label.position = Vector2(40, 0)
		label.modulate = entry.get_element_color()
		icon.add_child(label)
