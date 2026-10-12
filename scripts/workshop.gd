extends RefCounted
const RECIPES := {
	&"pickaxe": {&"piedra": 2, &"palo": 2, &"cuerda": 1},
	&"axe": {&"piedra": 1, &"palo": 2, &"cuerda": 1},
	&"cuerda": {&"fibra": 3},
	&"burdock_armor": {&"hoja_bardana":15,&"cuerda":3,&"fibra":20},
}
const REPAIRS := {
	&"pickaxe": {&"piedra": 1, &"palo": 1},
	&"axe": {&"piedra": 1, &"palo": 1},
	&"sword": {&"piedra": 2, &"palo": 1},
	&"bow": {&"palo": 1, &"cuerda": 1},
	&"helmet": {&"piedra": 2, &"cuerda": 1},
	&"suit": {&"fibra": 2, &"cuerda": 1},
	&"trousers": {&"fibra": 2, &"cuerda": 1},
	&"boots": {&"fibra": 2, &"cuerda": 1},
}

static func affordable(bag, cost: Dictionary) -> bool:
	for id in cost:
		if bag.count(id) < cost[id]:
			return false
	return true

static func craft(bag, id: StringName) -> String:
	if not RECIPES.has(id):
		return "No hay receta para ese objeto."
	if not affordable(bag,RECIPES[id]):
		return "Faltan materiales."
	# Consume and add in a trial backpack: a failed craft never loses inputs,
	# and materials can free the slot occupied by the crafted object.
	var trial = bag.fork()
	for material in RECIPES[id]:
		trial.remove_amount(material,RECIPES[id][material])
	if not trial.add(id,1):
		return "La mochila está llena."
	bag.slots = trial.slots
	bag.quick_slots = trial.quick_slots
	bag.next_uid = trial.next_uid
	return ""

static func repair(bag, uid: int) -> String:
	var item: Dictionary = bag.item_by_uid(uid)
	if item.is_empty() or not REPAIRS.has(item["id"]):
		return "El objeto ya no está disponible."
	var maximum: int = bag.DEFINITIONS[item["id"]]["uses"]
	if item["uses"] >= maximum:
		return "El objeto ya está en perfecto estado."
	var cost: Dictionary = REPAIRS[item["id"]]
	if not affordable(bag,cost):
		return "Faltan materiales."
	for material in cost:
		bag.remove_amount(material,cost[material])
	item["uses"] = maximum
	return ""
