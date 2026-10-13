extends SceneTree
const Model = preload("res://scripts/inventory.gd")
const Workshop = preload("res://scripts/workshop.gd")
func _initialize():
	var bag = Model.new(); bag.reset()
	bag.slots.fill({})
	for i in 32: bag.slots[i] = bag.make_item(&"madera",99)
	bag.slots[0] = bag.make_item(&"flecha",98)
	bag.slots[1] = bag.make_item(&"palo",2)
	bag.slots[2] = bag.make_item(&"piedra",2)
	bag.slots[3] = bag.make_item(&"cuerda",2)
	var before: Array = bag.slots.duplicate(true)
	assert(Workshop.craft(bag,&"flecha") == "La mochila está llena.")
	assert(bag.slots == before)
	bag.slots[4] = {}
	assert(Workshop.craft(bag,&"flecha").is_empty())
	assert(bag.count(&"flecha") == 103 and bag.count(&"palo") == 1 and bag.count(&"piedra") == 1 and bag.count(&"cuerda") == 1)
	for item in bag.slots: assert(item.is_empty() or item.quantity <= Model.DEFINITIONS[item.id].stack)
	print("PASS five-arrow craft: transactional capacity and stack splitting"); quit()
