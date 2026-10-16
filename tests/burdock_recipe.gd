extends SceneTree
const Bag = preload("res://scripts/inventory.gd")
const Workshop = preload("res://scripts/workshop.gd")
const Icons = preload("res://scripts/item_icons.gd")
func _initialize():
	var bag = Bag.new(); bag.reset()
	var expected := {&"hoja_bardana":15,&"cuerda":3,&"fibra":20}
	assert(Workshop.RECIPES[&"burdock_armor"] == expected)
	bag.add(&"hoja_bardana",14); bag.add(&"cuerda",3); bag.add(&"fibra",20)
	assert(Workshop.craft(bag,&"burdock_armor") != "" and bag.count(&"hoja_bardana") == 14)
	bag.add(&"hoja_bardana",1)
	var source: int = bag.location(bag.slots.filter(func(item): return item.get("id") == &"fibra")[0].uid).index
	assert(bag.move_item(&"bag",source,&"quick",0))
	assert(Workshop.craft(bag,&"burdock_armor") == "")
	assert(bag.count(&"burdock_armor") == 1 and bag.count(&"hoja_bardana") == 0 and bag.count(&"cuerda") == 0 and bag.count(&"fibra") == 0)
	assert(bag.quick_slots[0].is_empty())
	var icon := Icons.get_icon(&"burdock_armor")
	assert(icon != null and icon.get_image().get_pixel(0,0).a == 0)
	assert(Icons.get_icon(&"hoja_bardana") != null and Icons.get_icon(&"water") != null)
	assert(load("res://assets/ui/pause_font.fnt").has_char(201))
	print("PASS: burdock recipe, exact costs, atomic shortage, quick-store ingredients, finished icon, transparent corners and pause font accents")
	quit()
