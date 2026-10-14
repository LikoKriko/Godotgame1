extends RefCounted
const RECIPES := {
	&"sword": {&"palo":2,&"piedra":1,&"cuerda":1},
	&"bow": {&"palo":1,&"cuerda":2},
	&"leaf_boots": {&"cuerda":2,&"hoja_bardana":4},
	&"leaf_helmet": {&"hoja_bardana":2,&"cuerda":1},
	&"basic_workbench": {&"palo":12,&"cuerda":5},
	&"pickaxe": {&"piedra": 2, &"palo": 2, &"cuerda": 1},
	&"axe": {&"piedra": 1, &"palo": 2, &"cuerda": 1},
	&"cuerda": {&"fibra": 3},
	&"burdock_armor": {&"hoja_bardana":15,&"cuerda":3,&"fibra":20},
	&"botella": {&"cuero":3,&"hilo":1},
	&"flecha": {&"palo":1,&"piedra":1,&"cuerda":1},
}
const CREATION_TIMES := {&"pickaxe":2.0,&"axe":2.0,&"cuerda":2.0,&"burdock_armor":2.0,&"botella":2.0,&"flecha":2.0,&"sword":2.0,&"bow":2.0,&"leaf_boots":2.0,&"leaf_helmet":2.0,&"basic_workbench":2.0}
const OUTPUT_COUNTS := {&"flecha":5}
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

static func craft(bag, id: StringName, station_level: int = 0) -> String:
	if not RECIPES.has(id):
		return "La receta todavía no está definida."
	if id not in bag.unlocked_recipes: return "Esta receta no está desbloqueada."
	if station_level < required_station(bag,id): return "Necesitas una mesa de fabricación básica."
	if not affordable(bag,RECIPES[id]):
		return "Faltan materiales."
	# Consume and add in a trial backpack: a failed craft never loses inputs,
	# and materials can free the slot occupied by the crafted object.
	var trial = bag.fork()
	for material in RECIPES[id]:
		trial.remove_amount(material,RECIPES[id][material])
	if not trial.add(id,OUTPUT_COUNTS.get(id,1)):
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

static func required_station(bag, id: StringName) -> int:
	return required_station_for(bag.DEFINITIONS.get(id,{}))

static func required_station_for(definition: Dictionary) -> int:
	var nonbasic_tool: bool = definition.get("slot",&"") == &"tool" and definition.get("category",&"") not in [&"bottle",&"workbench"] and not definition.get("basic_tool",false)
	return maxi(1 if nonbasic_tool else 0,int(definition.get("required_station",0)))

static func recipe_ids(bag, station_level: int = 0) -> Array:
	var result := []
	for id in bag.unlocked_recipes:
		if not bag.DEFINITIONS.has(id) or (not RECIPES.has(id) and id != &"cuero"): continue
		if required_station(bag,id) > station_level: continue
		if station_level > 0 and id == &"basic_workbench": continue
		result.append(id)
	return result
