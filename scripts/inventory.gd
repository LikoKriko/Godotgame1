extends RefCounted
const CAPACITY := 32
const EQUIPMENT_SLOTS := [&"head", &"torso", &"legs", &"hands", &"feet"]
const DEFINITIONS := {
	&"sword": {"name": "Espada", "slot": &"tool", "category": &"sword", "basic_tool":true, "damage": 3.0, "uses": 40, "stack": 1, "purpose": "Combate cuerpo a cuerpo"},
	&"bow": {"name": "Arco", "slot": &"tool", "category": &"bow", "basic_tool":true, "damage": 3.0, "uses": 60, "stack": 1, "purpose": "Requiere flechas · un uso por tensado"},
	&"pickaxe": {"name": "Pico", "slot": &"tool", "category": &"pickaxe", "basic_tool":true, "damage": 1.0, "uses": 30, "stack": 1, "purpose": "Extraer piedra de rocas"},
	&"axe": {"name": "Hacha", "slot": &"tool", "category": &"axe", "basic_tool":true, "damage": 1.0, "uses": 30, "stack": 1, "purpose": "Cortar árboles"},
	&"flecha": {"name":"Flecha básica","slot":&"","uses":-1,"stack":99,"purpose":"Munición para arcos · se consume una por disparo"},
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
	# Retained only to read old stacked water without discarding excess bottles.
	&"water": {"name": "Botella", "slot": &"", "uses": -1, "stack": 99, "purpose": "Botellas de una partida anterior · 500 ml cada una", "water_ml": 500, "catalogue":false},
	&"botella": {"name":"Botella","slot":&"tool","category":&"bottle","uses":-1,"stack":1,"purpose":"500 ml · beber 250 ml · E sobre agua para rellenar","container":true},
	&"cuero": {"name":"Cuero","slot":&"","uses":-1,"stack":99,"purpose":"Material de fabricación; todavía no disponible en el mundo"},
	&"hilo": {"name":"Hilo","slot":&"","uses":-1,"stack":99,"purpose":"Cada unidad equivale a 1 metro; todavía no disponible en el mundo"},
	&"helmet": {"name": "Casco", "slot": &"head", "uses": 80, "stack": 1, "purpose": "Protección de cabeza"},
	&"suit": {"name": "Traje", "slot": &"torso", "uses": 100, "stack": 1, "purpose": "Protección de torso"},
	&"trousers": {"name": "Pantalón corto", "slot": &"legs", "uses": 60, "stack": 1, "purpose": "Equipo de piernas"},
	&"boots": {"name": "Botas", "slot": &"feet", "uses": 60, "stack": 1, "purpose": "Protección de pies"}
	,&"hoja_bardana": {"name":"Hoja de bardana","slot":&"","uses":-1,"stack":99,"purpose":"Material para fabricar la primera armadura"}
	,&"burdock_armor": {"name":"Armadura de hojas","slot":&"torso","uses":-1,"stack":1,"purpose":"Armadura tejida con hojas de bardana, fibra vegetal y cuerda."}
	,&"leaf_boots": {"name":"Botas de hojas","slot":&"feet","uses":-1,"stack":1,"purpose":"Equipo de hojas; apariencia pendiente de su sprite."}
	,&"leaf_helmet": {"name":"Casco de hojas","slot":&"head","uses":-1,"stack":1,"purpose":"Equipo de hojas; apariencia pendiente de su sprite."}
	,&"basic_workbench": {"name":"Mesa de fabricación básica","slot":&"tool","category":&"workbench","uses":-1,"stack":1,"purpose":"Seleccionar en la barra rápida y colocar con clic · 3 segundos"}
}
const DEFAULT_RECIPES := [&"botella",&"pickaxe",&"axe",&"sword",&"bow",&"cuero",&"cuerda",&"flecha",&"burdock_armor",&"leaf_boots",&"leaf_helmet",&"basic_workbench"]
var unlocked_recipes: Array = DEFAULT_RECIPES.duplicate()
var slots: Array[Dictionary] = []
var equipment: Dictionary = {}
var next_uid := 1
var quick_slots: Array[Dictionary] = [{},{},{},{},{},{}]
var active_quick_uid := -1
# Compatibility only: retain an old save's carried tool when every storage slot is full.
# New equipment always lives in the physical quick bar, independently of gloves.
var held_tool: Dictionary = {}

func reset() -> void:
	unlocked_recipes = DEFAULT_RECIPES.duplicate()
	quick_slots.assign([{},{},{},{},{},{}])
	active_quick_uid = -1
	held_tool = {}
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
	move_item(&"bag",3,&"quick",5)
	activate_quick(5)

func make_item(id: StringName, quantity: int) -> Dictionary:
	var item := {"id": id, "quantity": quantity, "uses": DEFINITIONS[id]["uses"], "rarity": &"basico", "uid": next_uid}
	if id == &"botella": item["water_ml"] = 0
	next_uid += 1
	return item

func count(id: StringName) -> int:
	var amount := 0
	for item in slots+quick_slots:
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
	if index < 0 or index >= CAPACITY or slots[index].is_empty(): return false
	if DEFINITIONS[slots[index].id].slot != target: return false
	if target == &"tool":
		for i in quick_slots.size():
			if quick_slots[i].is_empty():
				return move_item(&"bag",index,&"quick",i) and activate_quick(i)
		return false
	if not equipment.has(target): return false
	var previous: Dictionary = equipment[target]
	equipment[target] = slots[index]
	slots[index] = previous
	return true

func unequip(target: StringName) -> bool:
	if target == &"tool":
		if active_quick_uid != -1:
			active_quick_uid = -1
			return true
		return transfer_first(&"held",0,&"bag") if not held_tool.is_empty() else false
	return transfer_first(&"gear",target,&"bag") if equipment.has(target) and not equipment[target].is_empty() else false

func select_tool(id: StringName) -> bool:
	if held_id() == id:
		return true
	for i in quick_slots.size():
		if quick_slots[i].get("id",&"") == id: return activate_quick(i)
	for i in CAPACITY:
		if slots[i].get("id", &"") == id:
			return equip(i, &"tool")
	return false

func held_id() -> StringName:
	return held_item().get("id", &"")

func held_item() -> Dictionary:
	for item in quick_slots:
		if item.get("uid",-1) == active_quick_uid and active_quick_uid != -1: return item
	return held_tool

func location(uid: int) -> Dictionary:
	if uid < 1: return {}
	if held_tool.get("uid",-1) == uid: return {"kind":&"held","index":0}
	for pair in [[&"bag",slots],[&"quick",quick_slots]]:
		for i in pair[1].size():
			if pair[1][i].get("uid",-1) == uid: return {"kind":pair[0],"index":i}
	for slot in equipment:
		if equipment[slot].get("uid",-1) == uid: return {"kind":&"gear","index":slot}
	return {}

func at(kind: StringName, index) -> Dictionary:
	if kind == &"held": return held_tool if index == 0 else {}
	if kind == &"gear": return equipment.get(index,{})
	var storage: Array = quick_slots if kind == &"quick" else slots
	return storage[index] if index is int and index >= 0 and index < storage.size() else {}

func put(kind: StringName, index, item: Dictionary) -> void:
	if kind == &"held": held_tool = item
	elif kind == &"gear": equipment[index] = item
	elif kind == &"quick": quick_slots[index] = item
	else: slots[index] = item

func accepts(kind: StringName, index, item: Dictionary) -> bool:
	if kind == &"held": return index == 0 and (item.is_empty() or DEFINITIONS[item.id].slot == &"tool")
	if kind == &"gear": return equipment.has(index) and (item.is_empty() or DEFINITIONS[item.id].slot == index)
	return kind in [&"bag",&"quick"] and index is int and index >= 0 and index < (6 if kind == &"quick" else CAPACITY)

func can_move(source: StringName, from, destination: StringName, to) -> bool:
	var item := at(source,from)
	if item.is_empty() or not accepts(destination,to,item) or (source == destination and from == to): return false
	var other := at(destination,to)
	if destination != &"gear" and not other.is_empty() and other.id == item.id and DEFINITIONS[item.id].stack > 1:
		return other.quantity < DEFINITIONS[item.id].stack
	return accepts(source,from,other)

func move_item(source: StringName, from, destination: StringName, to) -> bool:
	if not can_move(source,from,destination,to): return false
	var item := at(source,from)
	var other := at(destination,to)
	if destination != &"gear" and not other.is_empty() and other.id == item.id and DEFINITIONS[item.id].stack > 1:
		var amount := mini(item.quantity,DEFINITIONS[item.id].stack-other.quantity)
		other.quantity += amount; item.quantity -= amount
		if item.quantity == 0: put(source,from,{})
	else:
		put(destination,to,item); put(source,from,other)
	if destination == &"held": active_quick_uid = -1
	var held := location(active_quick_uid)
	if held.is_empty() or held.kind != &"quick": active_quick_uid = -1
	return true

func transfer_first(source: StringName, index, destination: StringName) -> bool:
	var item := at(source,index)
	if item.is_empty(): return false
	var storage: Array = quick_slots if destination == &"quick" else slots
	var moved := false
	for pass_index in 2:
		for i in storage.size():
			if (pass_index == 0 and not storage[i].is_empty() and storage[i].id == item.id and DEFINITIONS[item.id].stack > 1) or (pass_index == 1 and storage[i].is_empty()):
				if can_move(source,index,destination,i):
					move_item(source,index,destination,i)
					moved = true
					if at(source,index).is_empty(): return true
	return moved

func shift_transfer(source: StringName, index) -> bool:
	var item := at(source,index)
	if item.is_empty(): return false
	if source != &"bag": return transfer_first(source,index,&"bag")
	var gear: StringName = DEFINITIONS[item.id].slot
	if gear in EQUIPMENT_SLOTS and equipment[gear].is_empty(): return move_item(source,index,&"gear",gear)
	return transfer_first(source,index,&"quick")

func activate_quick(index: int) -> bool:
	var item := at(&"quick",index)
	if item.is_empty() or DEFINITIONS[item.id].slot != &"tool": return false
	if active_quick_uid == item.uid:
		active_quick_uid = -1
		return true
	if not held_tool.is_empty() and not transfer_first(&"held",0,&"bag") and not transfer_first(&"held",0,&"quick"):
		return move_item(&"quick",index,&"held",0)
	active_quick_uid = item.uid
	return true

func held_category() -> StringName:
	return DEFINITIONS.get(held_id(), {}).get("category", &"")

func fork():
	var copy = get_script().new()
	copy.slots = slots.duplicate(true)
	copy.equipment = equipment.duplicate(true)
	copy.quick_slots = quick_slots.duplicate(true)
	copy.active_quick_uid = active_quick_uid
	copy.held_tool = held_tool.duplicate(true)
	copy.next_uid = next_uid
	copy.unlocked_recipes = unlocked_recipes.duplicate()
	return copy

func remove_amount(id: StringName, quantity: int) -> bool:
	if quantity < 0 or count(id) < quantity:
		return false
	var remaining := quantity
	for storage in [slots,quick_slots]:
		for i in storage.size():
			if storage[i].get("id", &"") != id: continue
			var taken := mini(remaining,storage[i].quantity)
			storage[i].quantity -= taken; remaining -= taken
			if storage[i].quantity == 0: storage[i] = {}
			if remaining == 0: return true
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
	quick_slots = trial.quick_slots
	next_uid = trial.next_uid
	return true

func item_by_uid(uid: int) -> Dictionary:
	for item in slots+quick_slots:
		if item.get("uid", -1) == uid:
			return item
	for item in equipment.values()+[held_tool]:
		if item.get("uid", -1) == uid:
			return item
	return {}

func usable() -> bool:
	var item: Dictionary = held_item()
	return not item.is_empty() and item["uses"] > 0

func consume_item_uses(uid: int, amount: int = 1) -> bool:
	var item := item_by_uid(uid)
	if item.is_empty() or item.uses <= 0 or amount <= 0: return false
	item.uses = maxi(0,item.uses-amount)
	return true

func consume_use(amount: int = 1) -> bool:
	return consume_item_uses(held_item().get("uid",-1),amount)

func held_damage() -> float:
	return float(DEFINITIONS.get(held_id(),{}).get("damage",0.0))

func can_harvest(material: String) -> bool:
	if material in ["chatarra", "fibra", "hoja_bardana"]:
		return held_id() == &""
	return usable() and held_category() == (&"axe" if material == "madera" else &"pickaxe")

func unlock_recipe(id: StringName) -> void:
	if DEFINITIONS.has(id) and id not in unlocked_recipes: unlocked_recipes.append(id)
