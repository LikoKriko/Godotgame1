extends RefCounted
## Versioned data only: never deserialize executable objects. Replace the save
## atomically so interruption during writing leaves the last good game intact.
const PATH := "user://day_zero_save.cfg"
const VERSION := 5

static func capture(game) -> Dictionary:
	var remaining := {}
	var quick: Array[int] = []
	for uid in game.quick_items: quick.append(uid if not game.bag.item_by_uid(uid).is_empty() else -1)
	for cell in game.resources.nodes:
		remaining[cell] = game.resources.nodes[cell]["remaining"]
	return {
		"version": VERSION, "seed": game.world.seed_value, "combat": game.enemies.capture_state(),
		"hut": game.hut.snapshot(), "rock_support":game.rock_support, "player": game.player, "heading": game.movement.heading,
		"resources": remaining, "collected": game.resources.inventory.duplicate(),
		"slots": game.bag.slots.duplicate(true), "equipment": game.bag.equipment.duplicate(true), "next_uid": game.bag.next_uid,
		"experience": game.experience, "level": game.level, "points": game.skill_points,
		"skills": game.progression.skills.duplicate(), "perks": game.progression.perks.duplicate(),
		"active": game.progression.active.duplicate(), "cooldowns": game.progression.cooldowns.duplicate(),
		"health": game.progression.health, "day": game.day_cycle.day, "hour": game.day_cycle.hour,
		"calories": game.nutrition.calories_today, "hydration": game.nutrition.hydration_ml,
		"water_today": game.nutrition.water_today_ml, "quick_items": quick,
		"held_tool": game.bag.held_tool.duplicate(true), "quick_slots": game.bag.quick_slots.duplicate(true), "active_quick_uid": game.bag.active_quick_uid, "plant_layout_version":1,"resource_layout_version":2
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
	if data is Dictionary: data = migrate(data)
	return data if data is Dictionary and valid(data) else {}

static func migrate(original: Dictionary) -> Dictionary:
	var data := migrate_tools(original)
	if original.get("version") not in [1,2,3,4]: return data
	if not data.get("slots") is Array or not data.get("quick_slots") is Array or not data.get("next_uid") is int: return {}
	# Split only when the entire old stack fits; otherwise keep it recoverable
	# until a bottle can be unpacked while drinking. Preserve each original UID.
	for item in data.slots+data.quick_slots:
		if not item is Dictionary or item.get("id") != &"water": continue
		if not item.get("quantity") is int or item.quantity < 1: return {}
		var free: Array[int] = []
		for i in data.slots.size():
			if data.slots[i] is Dictionary and data.slots[i].is_empty(): free.append(i)
		if free.size() < item.quantity-1: continue
		var extra: int = item.quantity-1
		item.id = &"botella"; item.quantity = 1; item.water_ml = 500
		for i in extra:
			var bottle: Dictionary = item.duplicate(true)
			bottle.uid = data.next_uid; data.next_uid += 1
			data.slots[free[i]] = bottle
	if data.get("resource_layout_version",0) != 2 and data.get("seed") is int and data.get("resources") is Dictionary:
		var world = preload("res://scripts/test_world.gd").new(); world.generate(data.seed)
		var resources = preload("res://scripts/harvesting.gd").new(); resources.configure(world)
		for cell in data.resources:
			if not cell is Vector2i or not data.resources[cell] is int: return {}
			if world.props.get(cell) != 1: continue
			var old_hits := 6 if world.large_rocks.has(cell) else (2 if world.prop_collisions[cell].size.x <= 20 else 3)
			var remaining: int = data.resources[cell]
			if remaining < 1 or remaining > old_hits: return {}
			data.resources[cell] = ceili(remaining/float(old_hits)*resources.nodes[cell].hits)
	if data.get("resources") is Dictionary:
		for cell in preload("res://scripts/test_world.gd").RETIRED_STRUCTURE_CELLS: data.resources.erase(cell)
	data.version = VERSION; data.resource_layout_version = 2
	return data

static func migrate_tools(original: Dictionary) -> Dictionary:
	var data := original.duplicate(true)
	if data.get("collected") is Dictionary: data.collected["hoja_bardana"] = data.collected.get("hoja_bardana",0)
	if data.get("version") == 2: return migrate_held_tool(data)
	if data.get("version") != 1: return data
	if not data.get("quick_items") is Array or data.quick_items.size() != 6 or not data.get("slots") is Array or not data.get("equipment") is Dictionary: return {}
	data.quick_slots = [{},{},{},{},{},{}]
	data.active_quick_uid = -1
	for item in data.slots:
		if not item is Dictionary: return {}
	for item in data.equipment.values():
		if not item is Dictionary: return {}
	var old_held: int = data.equipment.get(&"hands",{}).get("uid",-1)
	for i in 6:
		var uid = data.quick_items[i]
		for index in data.slots.size():
			if uid != -1 and data.slots[index].get("uid",-1) == uid:
				data.quick_slots[i] = data.slots[index]; data.slots[index] = {}
		for gear in data.equipment:
			if uid != -1 and data.equipment[gear].get("uid",-1) == uid:
				data.quick_slots[i] = data.equipment[gear]; data.equipment[gear] = {}
		if uid == old_held and uid != -1: data.active_quick_uid = uid
	data.version = 2
	return migrate_held_tool(data)

static func migrate_held_tool(data: Dictionary) -> Dictionary:
	if not data.get("equipment") is Dictionary: return {}
	var hands = data.equipment.get(&"hands",{})
	if not hands is Dictionary: return {}
	var definitions: Dictionary = preload("res://scripts/inventory.gd").DEFINITIONS
	data.held_tool = {}
	if not hands.is_empty() and definitions.get(hands.get("id"),{}).get("slot") == &"tool":
		data.held_tool = hands
		data.equipment[&"hands"] = {}
	if not data.held_tool.is_empty() and data.get("quick_slots") is Array and data.quick_slots.size() == 6 and data.get("quick_items") is Array and data.quick_items.size() == 6:
		for i in 6:
			if data.quick_slots[i] is Dictionary and data.quick_slots[i].is_empty():
				data.quick_slots[i] = data.held_tool
				data.quick_items[i] = data.held_tool.uid
				data.active_quick_uid = data.held_tool.uid
				data.held_tool = {}
				break
	data.version = VERSION
	return data

static func valid(data: Dictionary) -> bool:
	if data.has("hut") and not preload("res://scripts/hut.gd").valid_snapshot(data.hut): return false
	if not preload("res://scripts/enemy_manager.gd").valid_state(data.get("combat",{})): return false
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
	if not valid_item(data.get("held_tool"),uids): return false
	if not data.held_tool.is_empty() and Bag.DEFINITIONS[data.held_tool.id].slot != &"tool": return false
	for item in data.slots:
		if not valid_item(item, uids): return false
	for slot in Bag.EQUIPMENT_SLOTS:
		if not data.equipment.has(slot) or not valid_item(data.equipment[slot], uids): return false
		var item: Dictionary = data.equipment[slot]
		if not item.is_empty() and Bag.DEFINITIONS[item.id].slot != slot: return false
	if not data.get("quick_slots") is Array or data.quick_slots.size() != 6: return false
	for item in data.quick_slots:
		if not valid_item(item,uids): return false
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
	if not data.resources is Dictionary or not data.collected is Dictionary or data.collected.size() != 6: return false
	for cell in data.resources:
		if not cell is Vector2i or not data.resources[cell] is int or data.resources[cell] < 1 or data.resources[cell] > 12: return false
	for id in data.collected:
		if not id in ["madera", "piedra", "chatarra", "fibra", "palo","hoja_bardana"] or not data.collected[id] is int or data.collected[id] < 0: return false
	if not data.get("quick_items") is Array or data.quick_items.size() != 6: return false
	var assigned := {}
	for i in 6:
		var uid = data.quick_items[i]
		if uid != data.quick_slots[i].get("uid",-1): return false
		if not uid is int or (uid != -1 and not uids.has(uid)): return false
		if uid != -1:
			if assigned.has(uid): return false
			assigned[uid] = true
	if not data.get("active_quick_uid") is int: return false
	if data.active_quick_uid != -1:
		var held := false
		for item in data.quick_slots:
			if item.get("uid",-1) == data.active_quick_uid and Bag.DEFINITIONS[item.id].slot == &"tool": held = true
		if not held or not data.held_tool.is_empty(): return false
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
	if item.id == &"botella":
		if not item.get("water_ml") is int or item.water_ml < 0 or item.water_ml > 500 or item.water_ml%250 != 0: return false
	if not item.uid is int or item.uid < 1 or uids.has(item.uid): return false
	uids[item.uid] = true
	return true

static func restore(game, data: Dictionary) -> bool:
	data = migrate(data)
	if not valid(data): return false
	# Validate seed-dependent resource cells before mutating the current game.
	var trial = preload("res://scripts/test_world.gd").new()
	trial.generate(data.seed)
	var trial_resources = preload("res://scripts/harvesting.gd").new()
	trial_resources.configure(trial)
	var indoors: bool = data.get("hut",{}).get("inside",false)
	if indoors:
		if not preload("res://scripts/hut.gd").ROOM_BOUNDS.grow(-20).has_point(data.player) or not trial.bounds.grow(-trial.PLAYER_RADIUS).has_point(data.hut.outside_player): return false
	elif not trial.bounds.grow(-trial.PLAYER_RADIUS).has_point(data.player): return false
	var combat: Dictionary = data.get("combat",{})
	if not combat.is_empty() and not combat.enemy.is_empty() and not trial.bounds.grow(-9).has_point(combat.enemy.position): return false
	for cell in data.resources:
		if not trial_resources.nodes.has(cell) or data.resources[cell] > trial_resources.nodes[cell].hits: return false
	game.world.seed_value = data.seed
	game.restart()
	for cell in game.resources.nodes.keys():
		if game.world.props[cell] == 5 and not data.resources.has(cell) and data.get("plant_layout_version",0) == 0: continue
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
	game.bag.held_tool = data.held_tool.duplicate(true)
	game.bag.next_uid = data.next_uid
	game.bag.quick_slots.assign(data.quick_slots.duplicate(true))
	game.bag.active_quick_uid = data.active_quick_uid
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
	game.player = data.player if indoors or game.world.walkable(data.player) else Vector2.ZERO
	game.hut.inside = indoors
	if data.has("hut"): game.hut.outside_player = data.hut.outside_player if game.world.walkable(data.hut.outside_player) else game.hut.door
	game.enemies.restore_state(combat)
	if data.get("rock_support") is Vector2i and game.world.props.get(data.rock_support) == 1 and game.world.physical_height(data.rock_support) <= game.world.JUMP_LIMIT and game.world.prop_collisions[data.rock_support].grow(game.world.PLAYER_RADIUS).has_point(data.player+Vector2(0,17)):
		game.rock_support = data.rock_support; game.player = data.player
	game.update_ground_support()
	game.hut.apply_visibility()
	game.movement.heading = data.heading
	game.last_tool_uid = game.bag.held_item().get("uid", -1)
	game.camera.position = game.player
	game.full_avatar.reset()
	game.inventory_panel.refresh()
	game.solar_lighting.update_light()
	game.update_hud()
	return true
