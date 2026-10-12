extends RefCounted
## Versioned data only: never deserialize executable objects. Replace the save
## atomically so interruption during writing leaves the last good game intact.
const PATH := "user://day_zero_save.cfg"
const VERSION := 1

static func capture(game) -> Dictionary:
	var remaining := {}
	var quick: Array[int] = []
	for uid in game.quick_items: quick.append(uid if not game.bag.item_by_uid(uid).is_empty() else -1)
	for cell in game.resources.nodes:
		remaining[cell] = game.resources.nodes[cell]["remaining"]
	return {
		"version": VERSION, "seed": game.world.seed_value,
		"player": game.player, "heading": game.movement.heading,
		"resources": remaining, "collected": game.resources.inventory.duplicate(),
		"slots": game.bag.slots.duplicate(true), "equipment": game.bag.equipment.duplicate(true), "next_uid": game.bag.next_uid,
		"experience": game.experience, "level": game.level, "points": game.skill_points,
		"skills": game.progression.skills.duplicate(), "perks": game.progression.perks.duplicate(),
		"active": game.progression.active.duplicate(), "cooldowns": game.progression.cooldowns.duplicate(),
		"health": game.progression.health, "day": game.day_cycle.day, "hour": game.day_cycle.hour,
		"calories": game.nutrition.calories_today, "hydration": game.nutrition.hydration_ml,
		"water_today": game.nutrition.water_today_ml, "quick_items": quick
	}

static func write(game, path: String = PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("game", "state", capture(game))
	var result := config.save(path+".tmp")
	if result != OK: return result
	return DirAccess.rename_absolute(path+".tmp", path)

static func read_state(path: String = PATH) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(path) != OK: return {}
	var data = config.get_value("game", "state", {})
	return data if data is Dictionary and valid(data) else {}

static func valid(data: Dictionary) -> bool:
	for key in ["version", "seed", "player", "heading", "resources", "collected", "slots", "equipment", "next_uid", "experience", "level", "points", "skills", "perks", "active", "cooldowns", "health", "day", "hour", "calories", "hydration", "water_today"]:
		if not data.has(key): return false
	if data.version != VERSION or not data.seed is int or not data.player is Vector2 or not data.player.is_finite(): return false
	for key in ["heading", "health", "hour", "hydration"]:
		if not (data[key] is float or data[key] is int) or not is_finite(float(data[key])): return false
	for key in ["next_uid", "experience", "level", "points", "day", "calories", "water_today"]:
		if not data[key] is int or data[key] < 0: return false
	if data.level < 1 or data.day < 1 or data.hour < 0 or data.hour >= 24 or data.hydration < 0 or data.hydration > 2000: return false
	if data.experience >= data.level*20: return false
	var Bag = preload("res://scripts/inventory.gd")
	if not data.slots is Array or data.slots.size() != Bag.CAPACITY or not data.equipment is Dictionary: return false
	if data.equipment.size() != Bag.EQUIPMENT_SLOTS.size(): return false
	var uids := {}
	for item in data.slots:
		if not valid_item(item, uids): return false
	for slot in Bag.EQUIPMENT_SLOTS:
		if not data.equipment.has(slot) or not valid_item(data.equipment[slot], uids): return false
		var item: Dictionary = data.equipment[slot]
		if not item.is_empty() and Bag.DEFINITIONS[item.id].slot != slot: return false
	for uid in uids:
		if uid >= data.next_uid: return false
	var Progress = preload("res://scripts/progression.gd")
	for pair in [["skills", Progress.SKILLS, Progress.SKILL_LIMIT], ["perks", Progress.PERKS, Progress.PERK_LIMIT]]:
		if not data[pair[0]] is Dictionary or data[pair[0]].size() != pair[1].size(): return false
		for id in pair[1]:
			var rank = data[pair[0]].get(id, -1)
			if not rank is int or rank < 0 or rank > pair[2]: return false
	for key in ["active", "cooldowns"]:
		if not data[key] is Dictionary or data[key].size() != Progress.SKILLS.size(): return false
		for id in Progress.SKILLS:
			var time = data[key].get(id, -1)
			var limit: float = Progress.SKILLS[id].duration if key == "active" else Progress.SKILLS[id].cooldown
			if not (time is float or time is int) or not is_finite(float(time)) or time < 0 or time > limit: return false
	if data.health < 0 or data.health > 20*(1+0.1*data.perks[&"life"]): return false
	if not data.resources is Dictionary or not data.collected is Dictionary or data.collected.size() != 5: return false
	for cell in data.resources:
		if not cell is Vector2i or not data.resources[cell] is int or data.resources[cell] < 1 or data.resources[cell] > 6: return false
	for id in data.collected:
		if not id in ["madera", "piedra", "chatarra", "fibra", "palo"] or not data.collected[id] is int or data.collected[id] < 0: return false
	if not data.get("quick_items") is Array or data.quick_items.size() != 6: return false
	var assigned := {}
	for uid in data.quick_items:
		if not uid is int or (uid != -1 and not uids.has(uid)): return false
		if uid != -1:
			if assigned.has(uid): return false
			assigned[uid] = true
	return true

static func valid_item(item, uids: Dictionary) -> bool:
	if not item is Dictionary: return false
	if item.is_empty(): return true
	for key in ["id", "quantity", "uses", "rarity", "uid"]:
		if not item.has(key): return false
	var definitions: Dictionary = preload("res://scripts/inventory.gd").DEFINITIONS
	if not definitions.has(item.id) or item.rarity != &"basico": return false
	if not item.quantity is int or item.quantity < 1 or item.quantity > definitions[item.id].stack: return false
	if not item.uses is int or item.uses < -1 or item.uses > definitions[item.id].uses: return false
	if definitions[item.id].uses >= 0 and item.uses < 0: return false
	if not item.uid is int or item.uid < 1 or uids.has(item.uid): return false
	uids[item.uid] = true
	return true

static func restore(game, data: Dictionary) -> bool:
	if not valid(data): return false
	# Validate seed-dependent resource cells before mutating the current game.
	var trial = preload("res://scripts/test_world.gd").new()
	trial.generate(data.seed)
	var trial_resources = preload("res://scripts/harvesting.gd").new()
	trial_resources.configure(trial)
	if not trial.bounds.grow(-trial.PLAYER_RADIUS).has_point(data.player): return false
	for cell in data.resources:
		if not trial_resources.nodes.has(cell) or data.resources[cell] > trial_resources.nodes[cell].hits: return false
	game.world.seed_value = data.seed
	game.restart()
	for cell in game.resources.nodes.keys():
		if data.resources.has(cell):
			game.resources.nodes[cell].remaining = data.resources[cell]
		else:
			var footprint: Rect2i = game.resources.nodes[cell].footprint
			for y in range(footprint.position.y, footprint.end.y):
				for x in range(footprint.position.x, footprint.end.x):
					var released := Vector2i(x, y)
					game.world.cells[released].blocked = false
					game.world.reachable.append(released)
			game.world.release_prop(cell)
			game.resources.nodes.erase(cell)
	game.world_view.refresh_ground()
	game.resources.inventory = data.collected.duplicate()
	game.bag.slots.assign(data.slots.duplicate(true))
	game.bag.equipment = data.equipment.duplicate(true)
	game.bag.next_uid = data.next_uid
	game.quick_items.assign(data.quick_items)
	game.experience = data.experience
	game.level = data.level
	game.skill_points = data.points
	for key in ["skills", "perks", "active", "cooldowns"]: game.progression.set(key, data[key].duplicate())
	game.progression.health = data.health
	game.day_cycle.day = data.day
	game.day_cycle.hour = data.hour
	game.nutrition.calories_today = data.calories
	game.nutrition.hydration_ml = data.hydration
	game.nutrition.water_today_ml = data.water_today
	game.player = data.player if game.world.walkable(data.player) else Vector2.ZERO
	game.movement.heading = data.heading
	game.last_tool_uid = game.bag.equipment[&"hands"].get("uid", -1)
	game.camera.position = game.player
	game.sync_character()
	game.full_avatar.reset()
	game.inventory_panel.refresh()
	game.solar_lighting.update_light()
	game.survival_status.update_status()
	game.update_hud()
	return true
