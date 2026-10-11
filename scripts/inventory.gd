extends RefCounted
const CAPACITY := 32
const EQUIPMENT_SLOTS := [&"head", &"torso", &"legs", &"hands", &"feet"]
const DEFINITIONS := {
	&"sword": {"name": "Espada", "slot": &"hands", "uses": 40, "stack": 1, "purpose": "Combate cuerpo a cuerpo"},
	&"bow": {"name": "Arco", "slot": &"hands", "uses": 60, "stack": 1, "purpose": "Disparar flechas"},
	&"pickaxe": {"name": "Pico", "slot": &"hands", "uses": 30, "stack": 1, "purpose": "Extraer mineral de rocas"},
	&"axe": {"name": "Hacha", "slot": &"hands", "uses": 30, "stack": 1, "purpose": "Cortar árboles"},
	&"madera": {"name": "Madera", "slot": &"", "uses": -1, "stack": 99, "purpose": "Material de fabricación"},
	&"mineral": {"name": "Mineral", "slot": &"", "uses": -1, "stack": 99, "purpose": "Material de fabricación"},
	&"chatarra": {"name": "Chatarra", "slot": &"", "uses": -1, "stack": 99, "purpose": "Material de fabricación"},
	&"helmet": {"name": "Casco", "slot": &"head", "uses": -1, "stack": 1, "purpose": "Equipo de cabeza"},
	&"suit": {"name": "Traje", "slot": &"torso", "uses": -1, "stack": 1, "purpose": "Equipo de torso"},
	&"trousers": {"name": "Pantalón", "slot": &"legs", "uses": -1, "stack": 1, "purpose": "Equipo de piernas"},
	&"boots": {"name": "Botas", "slot": &"feet", "uses": -1, "stack": 1, "purpose": "Equipo de pies"}
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
	# Starter clothing fills the matching slots; hands are reserved for tools.
	for id in [&"helmet", &"suit", &"trousers", &"boots"]:
		equipment[DEFINITIONS[id]["slot"]] = make_item(id, 1)
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

func usable() -> bool:
	var item: Dictionary = equipment[&"hands"]
	return not item.is_empty() and item["uses"] > 0

func consume_use() -> bool:
	if not usable():
		return false
	equipment[&"hands"]["uses"] -= 1
	return true

func can_harvest(material: String) -> bool:
	if material == "chatarra":
		return held_id() == &""
	return usable() and held_id() == (&"axe" if material == "madera" else &"pickaxe")
