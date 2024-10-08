# <img src="https://github.com/KoBeWi/Godot-Text-Database/blob/master/Media/Icon.png" width="64" height="64"> Godot Text Database

TextDatabse is a class that can load custom data files (supported formats are `.json` and `.cfg`) created manually and validate them for you. If comparing to SQL database, imagine you create a schema and then load data and the data tries to fit into the schema. Why?

## Why TextDatabase

When creating a game, you often want to have some data. It can be list of levels, item database, enemy codex, just anything that has some properties and comes in a more or less big number. There are multiple approaches for that. The easiest one is creating a constant Dictionary or Array somewhere in a singleton or any script file, which will hold all your data and then load and access it directly. Another way is to create a custom Resource type and then create all your data as resource instances.

The first approach, while it is simple, is actually evil. Scripts aren't meant to hold data. You can store some stuff, but it doesn't scale good. Although GDScript is actually friendly for such usage. The second approach, while I've seen recommended by some people, is actually inconvenient, as you need to edit the resources in the inspector or using text editors. Also with this approach you usually put the resources as separate files (I bet it's recommended), which just creates incredible clutter.

Then comes the mother of all data storage, that is, storing data in a format intended for storage (usually JSON, there are better, see below). Depending on your structure, you can conveniently store data in one or multiple files and format it in readable and easy to edit way. You can of course create a custom editor for your data, but it's usually not worth it. If you want to do changes to your data structure, you also need to update the editor; also making editor as convenient as a regular text editor takes a bit of work. The only problem with using text is that you can easily mistype something, which makes your data loading fail or result in some weird unexpected bugs. This is where TextDatabase comes in, to make text storage safe to use. But before that...

## Why ConfigFile is better than JSON

Most people, when thinking about data storage, they use JSON. Of course there are other formats, but this is the only one that Godot supports. But there's another - ConfigFile. It's a Godot's custom text format inspired by INI files. Your `export.cfg` is stored in this format, also `.tscn` and `.tres` files have very similar structure. Why is better than JSON?
- It has proper integer support, so e.g. you don't get unexpected results when using loaded data in a `match` statement.
- Actually, it supports any Godot's native Variant type. You can store e.g. Vector2s in your ConfigFiles.
- It supports comments. You can conveniently comment-out parts of data or annotate it.
- It also supports trailing commas.
- The syntax is way better. Just compare this JSON:
```JSON
[
	{
		"name": "Bag of Spikes",
		"description": "A bag full of rusty spikes.",
		"price": 80,
		"type": "misc"
	},

	{
		"name": "Hammer",
		"description": "A hammer. For hitting screws and things.",
		"price": 75,
		"type": "misc"
	}
]
```
With this super-slick CFG:
```INI
[Bag of Spikes]
description = "A bag full of rusty spikes."
price = 80
type = "misc"

[Hammer]
description = "A hammer. For hitting screws and things."
price = 75
type = "misc"
```
It's much shorter, comes without useless indendations and curly braces. It's way better format to edit by hand.

With this long introduction, let's explain the actual class.

## Basic usage

`TextDatabase` class inherits RefCounted. The simplest usage goes like this:
```GDScript
var database = TextDatabase.new()
database.load_from_path("res://MyData.cfg")
```
You create a database instance and then load files. You can then access your data using `database.get_array()` or `database.get_dictionary()`. Note that TextDatabase imposes some structure. Your data should be an array of dictionaries. Each entry is one dictionary and it can store different properties. Also if you have a "name key" in each of your entries, you can convert the database into a dictionary and access the entries by name.

Example usage with the data above:
```GDscript
var database = TextDatabase.new()
database.load_from_path("res://Items.cfg")
var data = database.get_dictionary()

for item in data:
	print(item.description) # Prints "A bag full of rusty spikes." and "A hammer. For hitting screws and things.".
```

You can also load multiple files into a database:
```GDscript
var database = TextDatabase.new()
database.load_from_path("res://Items1.cfg")
database.load_from_path("res://Items2.cfg")
```
They will all be stored in one array/dictionary, so you can divide your data into multiple files if you don't like 5000-liners. If the path you provide is a directory instead of a file, all files in that directory will be loaded (non-recursively).

## ID and name

Each entry in database has a unique ID. IDs are consecutive numbers in the order the entries are loaded. If you load mutliple files, additional files will follow the ID numbering from the previous files. By default the "ID" is stored in a property called `id`, but you can change it by modifying `id_name` property of the database. Then there is name. Each entry can be optionally named with a unique name. Names are required if you want to use the database as dictionary. ConfigFiles enforces naming your entries; the section names are used as item names. Name property can also be custiomized by `entry_name` in database.

Example:
Data file:
```INI
[Rusty Sword]
attack = 5

[Rubber Sword]
attack = 1
```
Loader:
```GDScript
var database = TextDatabase.new()
database.load_from_file("res://Equipment.cfg")
```
Results in this Array:
```GDScript
[{"id": 0, "name": "Rusty Sword", "attack": 5}, {"id": 1, "name": "Rubber Sword", "attack": 1}]
```
With customization:
```GDScript
var database = TextDatabase.new()
database.id_name = "item"
database.entry_name = "type"
database.load_from_file("res://Equipment.cfg")
```
```GDScript
[{"item": 0, "type": "Rusty Sword", "attack": 5}, {"item": 1, "type": "Rubber Sword", "attack": 1}]
```

## Data validation

You can define 2 types of properties in TextDatabase: "mandatory" properties and "valid" properties. Mandatory property is a property that MUST be in an entry. E.g. if you have you have a collection of items, you might want all of them to have description. Valid properties are properties that CAN be in entry. E.g. your items might have a set of stats, like "attack" and "defense". If you make a typo "attac", the property won't be recognized as valid. Valid properties may also have default values. Mandatory properties are automatically assigned as valid properties.

The data is validated during loading. If any entry is missing mandatory property or a property is invalid, it will hit an assertion and pause your game (works only in editor). So if you make a typo or forget to add something or put a wrong type etc., you will be spammed with errors, so you won't miss them unknowingly. This makes it very safe and convenient to use. Do note that property validation isn't done only against "valid" properties, but TextDatabase will also consider "mandatory" properties as well, so you don't need to duplicate them. If you want to validate properties, but don't have any "valid" properties, you can set `is_validated` to true, to enable validation using only the mandatory set. Also properties can be typed, so that the type loaded from file is checked against the declared one. There is also an option called `is_strict` (default `false`), which makes validation fail if property declared as `float` has `int` value.

With all this combined, your database definition is really close to a schema of traditional database. Note that all validation happens only in debug builds. Make sure that you have no errors when loading database and avoid any data modifications in validation methods. Also, since defined properties are effectively unused in release builds, it's better to define them only in debug builds.

### Validation examples

Loading data with a set of mandatory properties.
```GDscript
var database = TextDatabase.new()
database.add_mandatory_property("description")
database.add_mandatory_property("price")
database.load_from_path("res://Items1.cfg")
```
With types:
```GDscript
var database = TextDatabase.new()
database.add_mandatory_property("description", TYPE_STRING)
database.add_mandatory_property("price", TYPE_INT)
database.load_from_path("res://Items1.cfg")
```
Defining valid properties:
```GDscript
var database = TextDatabase.new()
database.add_valid_property("attack") # define a valid property
database.add_valid_property("defense", TYPE_INT) # same, but with type
database.add_default_property("power", 0) # add valid property with default value
database.add_default_property("resistance", 0, false) # same, but the property will be untyped
database.load_from_path("res://Items1.cfg")
```

## Custom database classes

Sometimes you need more data processing in your database. Common example is when you have a property that stores enum. But you can't load enums from text files (even with ConfigFile :< ), so instead you can store enum name as string and then convert it to proper value upon loading. This, or maybe your "schema" is sooooo long that you want to store it somewhere else. Or maybe you just think that declaring stuff ad-hoc is ugly. That's where custom database classes come in.

You can create a custom script that extends TextDatabase. The main advantage is that you get access to multiple callbacks that allow you for some advanced behavior or just more encapsulated initialization.

Database has 2 initialization callbacks:
- `_initialize()`, which can be used to customize database (with `id_name` etc.).
- `_schema_initialize()`, which is called only in debug builds and can be used to define properties etc.
```GDScript
func _initialize():
	entry_name = "item"

func _schema_initialize():
	add_mandatory_property("price", TYPE_INT)
	add_mandatory_property("color", TYPE_COLOR)
	add_valid_property("shape", TYPE_STRING)
	add_valid_property("power", TYPE_INT)
```

The `_preprocess_entry()` callback is called for every entry in your database after it is loaded, but before validation.
```GDScript
func _preprocess_entry(entry):
	# If an entry doesn't have this mandatory property, add a dynamic default value.
	if not entry.has("color"):
		entry.color = [Color.red, Color.green, Color.blue][entry.id % 3]
```

The `_additional_validate()` callback is called after the regular validation. You can apply some rules that aren't possible automatically. Return a String with error that will be displayed or an empty String if entry is valid. Doesn't get called in release builds.
```GDScript
enum Shapes {RECTANGLE, CIRCLE, OCTACHORON}

func _additional_validate(entry, property):
	# This makes sure that a property value exists in enum.
	if property == "shape":
		if not entry[property] in Shapes.keys():
			return "Invalid shape."
	return ""
```

The `_reserve_validate()` callback is called for invalid entries if all other validation fails. You can apply custom validation and return `true` or `false`. Doesn't get called in release builds.
```GDScript
func _reserve_validate(entry, property) -> bool:
	# This allows for properties like "power_lv1" to pass validation.
	if property.find("_lv") > -1:
		return is_property_valid(entry, property.get_slice("_", 0), entry[property])
	return false
```
(note the `is_property_valid()` method in above example. It's useful for manual validation)

The `_postprocess_entry()` callback is called for every entry in your database after the validation is finished.
```GDScript
enum Shapes {RECTANGLE, CIRCLE, OCTACHORON}

func _postprocess_entry(entry):
	# Assign actual enum value to a property.
	if "shape" in entry:
		for i in Shapes.keys().size():
			if Shapes.keys()[i] == entry.shape:
				entry.shape = i
				break
```

To load a data file with custom class, you can do either:
```GDScript
var database = load("res://ItemsDatabase.gd").new()
database.load_from_file("res://ShapeItems.json")
var data = database.get_array()
```
Or a shorter version:
```GDScript
var data = TextDatabase.load_database("res://ItemsDatabase.gd", "res://ShapeItems.json").get_array()
```

You can check the example project if you are still unsure. The class also includes built-in documentation.

## RefCounted structs

New in 1.3: Normally database entries are Dictionaries with the defined values. As an alternative you can use pseudo-structs extending RefCounted. The loading will be marginally slower, but it allows for overall safer code and better performance when accessing entry properties.

To use structs, call `define_from_struct(constructor)` method, where `constructor` is a Callable that creates your struct, e.g. `Struct.new`. Afterwards you can use `get_struct_array()` or `get_struct_dictionary()` which will return your database with the provided struct as values.

`define_from_struct()` will automatically add valid properties to your database, based on properties from the provided class, and using the struct's defaults as entry defaults. It also makes the database typed and validated. If you want to make some struct properties mandatory or change their validated type, use `override_property_mandatory()` and `override_property_type()`. The latter is useful when the property can't be stored in text form, but can be processed afterwards (e.g. texture is loaded from stored path). "id" and "name" properties are optional in struct and won't be assigned when not declared.

When using custom database script, `define_from_struct()` should be called in `_initialize()`. It will automatically skip property definition in debug builds and only assign the constructor.

### Struct example

A simple Item struct that has `value` property and an `icon`. It's defined like this:

```GDScript
class_name Item extends RefCounted
var value: int
var icon: Texture2D
```

Note the icon, which is Texture2D, so it can't be stored as text. We can use `_postprocess_entry()` method to assign the texture. The database code will be this:

```GDScript
extends TextDatabase

func _initialize():
	define_from_struct(Item.new)

func _schema_initialize():
	override_property_type("icon", TYPE_STRING) # Stored type is different than in Item.

func _postprocess_entry(entry: Dictionary):
	entry.icon = load("res://Icons/" + entry.icon + ".png") # Assign actual Texture2D.
```
Note that if you omit postprocess here, you will get a type error when struct is being created.

Afterwards you can safely access your items as Items:
```GDScript
var database := TextDatabase.load_database("res://ItemDatabase.gd", "res://Items.cfg")
items = database.get_struct_dictionary()
```
```GDScript
var item: Item = items["Rusty Sword"]
sprite.texture = item.icon # Safe line!
```

## Inline methods

If you don't want to use custom class for post-processing and validating entries, you can use Callables (especially lamdas):
```GDScript
database.preprocess_entry = func(entry):
	if not entry.has("color"):
		entry.color = [Color.red, Color.green, Color.blue][entry.id % 3]
```

___
You can find all my addons on my [profile page](https://github.com/KoBeWi).

<a href='https://ko-fi.com/W7W7AD4W4' target='_blank'><img height='36' style='border:0px;height:36px;' src='https://cdn.ko-fi.com/cdn/kofi1.png?v=3' border='0' alt='Buy Me a Coffee at ko-fi.com' /></a>
