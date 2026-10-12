extends RefCounted
const CAPACITY := 32
const EQUIPMENT_SLOTS := [&"head", &"torso", &"legs", &"hands", &"feet"]
const DEFINITIONS := {
	&"sword": {"name": "Espada", "slot": &"hands", "category": &"sword", "uses": 40, "stack": 1, "purpose": "Combate cuerpo a cuerpo"},
	&"bow": {"name": "Arco", "slot": &"hands", "category": &"bow", "uses": 60, "stack": 1, "purpose": "Disparar flechas"},
	&"pickaxe": {"name": "Pico", "slot": &"hands", "category": &"pickaxe", "uses": 30, "stack": 1, "purpose": "Extraer piedra de rocas"},
	&"axe": {"name": "Hacha", "slot": &"hands", "category": &"axe", "uses": 30, "stack": 1, "purpose": "Cortar árboles"},
	&"madera": {"name": "Madera", "slot": &"", "uses": -1, "stack": 99, "purpose": "Material de fabricación"},
	&"mineral": {"name": "Mineral", "slot": &"", "uses": -1, "stack": 99, "purpose": "Material de fabricación"},
	&"chatarra": {"name": "Chatarra", "slot": &"", "uses": -1, "stack": 99, "purpose": "Material de fabricación"},
	&"fibra": {"name": "Fibra vegetal", "slot": &"", "uses": -1, "stack": 99, "purpose": "Material de arbolitos jóvenes; recolectar con las manos"},
	&"piedra": {"name": "Piedra", "slot": &"", "uses": -1, "stack": 99, "purpose": "Cabezas de herramientas y reparaciones"},
	&"palo": {"name": "Palo", "slot": &"", "uses": -1, "stack": 99, "purpose": "Mangos; se recoge de arbolitos jóvenes"},
	&"cuerda": {"name": "Cuerda", "slot": &"", "uses": -1, "stack": 99, "purpose": "Cada unidad equivale a 1 metro de cuerda"},
	&"apple": {"name": "Manzana", "slot": &"", "uses": -1, "stack": 99, "purpose": "Comer · 95 kcal", "kcal": 95},
	&"berries": {"name": "Bayas", "slot": &"", "uses": -1, "stack": 99, "purpose": "Comer · 40 kcal", "kcal": 40},
	&"ration": {"name": "Ración", "slot": &"", "uses": -1, "stack": 99, "purpose": "Comer · 400 kcal", "kcal": 400},
	&"water": {"name": "Agua", "slot": &"", "uses": -1, "stack": 99, "purpose": "Beber · 500 ml · 0 kcal", "water_ml": 500},
	&"helmet": {"name": "Casco", "slot": &"head", "uses": 80, "stack": 1, "purpose": "Protección de cabeza"},
	&"suit": {"name": "Traje", "slot": &"torso", "uses": 100, "stack": 1, "purpose": "Protección de torso"},
	&"trousers": {"name": "Pantalón corto", "slot": &"legs", "uses": 60, "stack": 1, "purpose": "Equipo de piernas"},
	&"boots": {"name": "Botas", "slot": &"feet", "uses": 60, "stack": 1, "purpose": "Protección de pies"}
}
var slots: Array[Dictionary] = []
var equipment: Dictionary = {}
var next_uid := 1

func reset() -> void:
	slots.clear()
	for i in CAPACITY:
		slots.append({})
	equipment.clear()
	for slot in EQUIPMENT_SLOTS:
		equipment[slot] = {}
	next_uid = 1
	for id in [&"sword", &"bow", &"pickaxe", &"axe"]:
		add(id, 1)
	# The new survivor starts shirtless and barefoot, wearing only shorts.
	equipment[&"legs"] = make_item(&"trousers", 1)
	equip(3, &"hands")

func make_item(id: StringName, quantity: int) -> Dictionary:
	var item := {"id": id, "quantity": quantity, "uses": DEFINITIONS[id]["uses"], "rarity": &"basico", "uid": next_uid}
	next_uid += 1
	return item

func count(id: StringName) -> int:
	var amount := 0
	for item in slots:
		if item.get("id", &"") == id:
			amount += item["quantity"]
	return amount

func can_add(id: StringName, quantity: int) -> bool:
	if not DEFINITIONS.has(id) or quantity <= 0:
		return false
	var room := 0
	var stack: int = DEFINITIONS[id]["stack"]
	for item in slots:
		if item.is_empty():
			room += stack
		elif item["id"] == id:
			room += stack - item["quantity"]
	return room >= quantity

func add(id: StringName, quantity: int) -> bool:
	if not can_add(id, quantity):
		return false
	var remaining := quantity
	var stack: int = DEFINITIONS[id]["stack"]
	for item in slots:
		if not item.is_empty() and item["id"] == id:
			var amount := mini(remaining, stack - item["quantity"])
			item["quantity"] += amount
			remaining -= amount
	for i in CAPACITY:
		if remaining <= 0:
			break
		if slots[i].is_empty():
			var amount := mini(remaining, stack)
			slots[i] = make_item(id, amount)
			remaining -= amount
	return true

func equip(index: int, target: StringName) -> bool:
	if index < 0 or index >= CAPACITY or slots[index].is_empty() or not equipment.has(target):
		return false
	if DEFINITIONS[slots[index]["id"]]["slot"] != target:
		return false
	var previous: Dictionary = equipment[target]
	equipment[target] = slots[index]
	slots[index] = previous
	return true

func unequip(target: StringName) -> bool:
	if not equipment.has(target) or equipment[target].is_empty():
		return false
	for i in CAPACITY:
		if slots[i].is_empty():
			slots[i] = equipment[target]
			equipment[target] = {}
			return true
	return false

func select_tool(id: StringName) -> bool:
	if equipment[&"hands"].get("id", &"") == id:
		return true
	for i in CAPACITY:
		if slots[i].get("id", &"") == id:
			return equip(i, &"hands")
	return false

func held_id() -> StringName:
	return equipment[&"hands"].get("id", &"")

func held_category() -> StringName:
	return DEFINITIONS.get(held_id(), {}).get("category", &"")

func fork():
	var copy = get_script().new()
	copy.slots = slots.duplicate(true)
	copy.equipment = equipment.duplicate(true)
	copy.next_uid = next_uid
	return copy

func remove_amount(id: StringName, quantity: int) -> bool:
	if quantity < 0 or count(id) < quantity:
		return false
	var remaining := quantity
	for i in CAPACITY:
		if slots[i].get("id", &"") != id:
			continue
		var taken := mini(remaining, slots[i]["quantity"])
		slots[i]["quantity"] -= taken
		remaining -= taken
		if slots[i]["quantity"] == 0:
			slots[i] = {}
		if remaining == 0:
			break
	return true

func can_add_many(rewards: Dictionary) -> bool:
	var trial = fork()
	for id in rewards:
		if not trial.add(StringName(id), rewards[id]):
			return false
	return true

func add_many(rewards: Dictionary) -> bool:
	var trial = fork()
	for id in rewards:
		if not trial.add(StringName(id), rewards[id]):
			return false
	slots = trial.slots
	next_uid = trial.next_uid
	return true

func item_by_uid(uid: int) -> Dictionary:
	for item in slots:
		if item.get("uid", -1) == uid:
			return item
	for item in equipment.values():
		if item.get("uid", -1) == uid:
			return item
	return {}

func usable() -> bool:
	var item: Dictionary = equipment[&"hands"]
	return not item.is_empty() and item["uses"] > 0

func consume_use() -> bool:
	if not usable():
		return false
	equipment[&"hands"]["uses"] -= 1
	return true

func can_harvest(material: String) -> bool:
	if material in ["chatarra", "fibra"]:
		return held_id() == &""
	return usable() and held_category() == (&"axe" if material == "madera" else &"pickaxe")
