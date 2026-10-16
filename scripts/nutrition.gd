extends RefCounted
const WEIGHT_KG := 60.0
const DAILY_KCAL := 1600
const WATER_CAPACITY_ML := 2000.0
const BOTTLE_CAPACITY_ML := 500
const SIP_ML := 250
var calories_today := 0
var hydration_ml := WATER_CAPACITY_ML
var water_today_ml := 0

func reset() -> void:
	calories_today = 0
	hydration_ml = WATER_CAPACITY_ML
	water_today_ml = 0

func new_day() -> void:
	calories_today = 0
	water_today_ml = 0

func advance(delta: float, day_seconds: float) -> void:
	hydration_ml = maxf(0,hydration_ml-maxf(delta,0)*WATER_CAPACITY_ML/day_seconds)

func speed_penalty() -> float:
	var excess := calories_today-DAILY_KCAL
	if excess >= 800:
		return 0.24
	if excess > 600:
		return 0.10
	if excess >= 400:
		return 0.06
	if excess >= 200:
		return 0.03
	if excess >= 0:
		return 0.01
	return 0.0

func speed_multiplier() -> float:
	return 1.0-speed_penalty()

func consume(inventory, index: int, quick: bool = false) -> Dictionary:
	var storage: Array = inventory.quick_slots if quick else inventory.slots
	if index < 0 or index >= storage.size() or storage[index].is_empty():
		return {"ok": false,"message": "Selecciona un alimento o agua."}
	var item: Dictionary = storage[index]
	if item.id == &"water": return consume_legacy_bottle(inventory,index,quick)
	if item.id == &"botella":
		var contents: int = item.get("water_ml",0)
		if contents < SIP_ML: return {"ok":false,"message":"La botella está vacía; rellénala con E junto al agua."}
		if hydration_ml >= WATER_CAPACITY_ML: return {"ok":false,"message":"Ya estás hidratado; el agua se conserva."}
		item.water_ml = contents-SIP_ML
		hydration_ml = minf(WATER_CAPACITY_ML,hydration_ml+SIP_ML)
		water_today_ml += SIP_ML
		return {"ok":true,"kcal":0,"water_ml":SIP_ML,"message":"Botella: +250 ml · quedan %d ml" % item.water_ml}
	var definition: Dictionary = inventory.DEFINITIONS[item["id"]]
	var kcal: int = definition.get("kcal",0)
	var water: int = definition.get("water_ml",0)
	if kcal <= 0 and water <= 0:
		return {"ok": false,"message": "Este objeto no se puede consumir."}
	if water > 0 and kcal == 0 and hydration_ml >= WATER_CAPACITY_ML:
		return {"ok": false,"message": "Ya estás hidratado; el agua se conserva."}
	# Consume the selected stack, never a different stack with the same ID.
	item["quantity"] -= 1
	if item["quantity"] == 0:
		storage[index] = {}
	calories_today += kcal
	hydration_ml = minf(WATER_CAPACITY_ML,hydration_ml+water)
	water_today_ml += water
	return {"ok": true,"kcal": kcal,"water_ml": water,"message": "%s: +%d kcal%s" % [definition["name"],kcal," · +%d ml" % water if water > 0 else ""]}

func consume_legacy_bottle(inventory, index: int, quick: bool) -> Dictionary:
	# Unpack an old stack atomically. Never lose its volume or consume the flask.
	var trial = inventory.fork()
	var storage: Array = trial.quick_slots if quick else trial.slots
	var old: Dictionary = storage[index]
	var target := index
	var target_quick := quick
	if old.quantity == 1:
		old.id = &"botella"; old.water_ml = BOTTLE_CAPACITY_ML
	else:
		if not trial.can_add(&"botella",1): return {"ok":false,"message":"Libera un hueco para separar una botella de la pila antigua."}
		old.quantity -= 1
		trial.add(&"botella",1)
		var location: Dictionary = trial.location(trial.next_uid-1)
		target = location.index; target_quick = false
		trial.slots[target].water_ml = BOTTLE_CAPACITY_ML
	var result := consume(trial,target,target_quick)
	if result.ok:
		inventory.slots = trial.slots; inventory.quick_slots = trial.quick_slots
		inventory.next_uid = trial.next_uid
	return result

static func refill(item: Dictionary) -> Dictionary:
	if item.get("id") != &"botella": return {"ok":false,"message":"Selecciona una botella en la barra rápida."}
	if item.get("water_ml",0) == BOTTLE_CAPACITY_ML: return {"ok":false,"message":"La botella ya está llena."}
	item.water_ml = BOTTLE_CAPACITY_ML
	return {"ok":true,"message":"Botella rellenada · 500 ml."}
