extends RefCounted
const WEIGHT_KG := 60.0
const DAILY_KCAL := 1600
const WATER_CAPACITY_ML := 2000.0
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

func consume(inventory, index: int) -> Dictionary:
	if index < 0 or index >= inventory.CAPACITY or inventory.slots[index].is_empty():
		return {"ok": false,"message": "Selecciona un alimento o agua."}
	var item: Dictionary = inventory.slots[index]
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
		inventory.slots[index] = {}
	calories_today += kcal
	hydration_ml = minf(WATER_CAPACITY_ML,hydration_ml+water)
	water_today_ml += water
	return {"ok": true,"kcal": kcal,"water_ml": water,"message": "%s: +%d kcal%s" % [definition["name"],kcal," · +%d ml" % water if water > 0 else ""]}
