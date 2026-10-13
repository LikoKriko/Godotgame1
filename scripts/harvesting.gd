extends RefCounted
const Rig = preload("res://scripts/tool_contact.gd")
const REACH := 40.0
const NONE := Vector2i(99999, 99999)
const TYPES := {
	0: {"name": "Maquinaria", "material": "chatarra", "hits": 3, "yield": 3, "branch": 3},
	1: {"name": "Roca", "material": "piedra", "hits": 3, "yield": 4, "branch": 1},
	2: {"name": "Árbol", "material": "madera", "hits": 3, "yield": 4, "branch": 0},
	4: {"name": "Arbolito joven", "material": "fibra", "hits": 2, "yield": 3, "branch": 0}
	,5: {"name":"Bardana","material":"hoja_bardana","hits":1,"yield":5,"branch":0}
}
var world
var bag
var meshes
var nodes: Dictionary = {}
var inventory := {"madera": 0, "piedra": 0, "chatarra": 0, "fibra": 0, "palo": 0}

func configure(map, inventory_model = null, hit_meshes = null) -> void:
	world = map
	bag = inventory_model
	meshes = hit_meshes
	nodes.clear()
	inventory = {"madera": 0, "piedra": 0, "chatarra": 0, "fibra": 0, "palo": 0}
	inventory["hoja_bardana"] = 0
	for cell in world.props:
		var kind: int = world.props[cell]
		if not TYPES.has(kind):
			continue
		var data: Dictionary = TYPES[kind].duplicate()
		if kind == 5: data["yield"] = 5 if world.burdock[cell] == 1 else 3
		data["hand_collectable"] = kind == 1 and not world.large_rocks.has(cell) and world.prop_collisions[cell].size.x <= 20
		if data["hand_collectable"]:
			data["name"] = "Piedra pequeña"
			data["hits"] = 2
			data["yield"] = 1
		data["footprint"] = Rect2i(cell, Vector2i(2, 2) if world.large_rocks.has(cell) else Vector2i.ONE)
		if world.large_rocks.has(cell):
			data["name"] = "Roca grande"
			data["hits"] = 6
			data["yield"] = 12
		data["remaining"] = data["hits"]
		nodes[cell] = data

func bounds(cell: Vector2i) -> Rect2:
	return world.prop_collisions[cell]

func target_at(point: Vector2) -> Vector2i:
	if meshes == null:
		return NONE
	var cell: Vector2i = meshes.target_at(point)
	return cell if nodes.has(cell) else NONE

func hit_at(aim: Vector2, _tip: Vector2, _shoulder: Vector2, player: Vector2, bonus: int = 0) -> Dictionary:
	# Selection uses the whole visible silhouette. Reach uses distance to the
	# physical base/footprint, independently of where on the sprite we point.
	var cell := target_at(aim)
	if cell == NONE or not can_reach(cell,player):
		return {"miss": true}
	var impact := visual_aim(aim,player)
	var result := hit(cell,player,bonus,true)
	if result.is_empty():
		return {"miss": true}
	result["cell"] = cell
	result["impact"] = impact
	return result

func distance_to(cell: Vector2i, player: Vector2) -> float:
	if not nodes.has(cell):
		return INF
	var rect := bounds(cell)
	return player.distance_to(player.clamp(rect.position,rect.end))

func visual_aim(cursor: Vector2, player: Vector2) -> Vector2:
	var cell := target_at(cursor)
	if cell == NONE or not can_reach(cell,player):
		return cursor
	# Aim at a nearby part of the selected object, rather than reaching up to
	# its canopy. The cursor still chooses which object receives the blow.
	return meshes.nearest_surface(cell,player+Vector2(0,-15))

func can_reach(cell: Vector2i, player: Vector2) -> bool:
	if not nodes.has(cell):
		return false
	var rect := bounds(cell)
	var nearest := player.clamp(rect.position, rect.end)
	if nearest.distance_to(player) > REACH:
		return false
	# A resource cannot be worked through a different obstacle.
	var distance := player.distance_to(nearest)
	for i in range(1, maxi(1, ceili(distance / 6.0))):
		var point := player.move_toward(nearest, i * 6.0)
		var crossed: Vector2i = world.cell_at(point)
		if not nodes[cell]["footprint"].has_point(crossed) and not world.walkable(point, 1.0):
			return false
	return true

func nearest(player: Vector2) -> Vector2i:
	var result := NONE
	var best := INF
	for cell in nodes:
		if can_reach(cell, player):
			var rect := bounds(cell)
			var distance := player.distance_to(player.clamp(rect.position, rect.end))
			if distance < best:
				best = distance
				result = cell
	return result

func hit(cell: Vector2i, player: Vector2, bonus: int = 0, validated_impact: bool = false) -> Dictionary:
	if not nodes.has(cell) or (not validated_impact and not can_reach(cell, player)):
		return {}
	var node: Dictionary = nodes[cell]
	var bare_stone: bool = node["hand_collectable"] and bag != null and bag.held_id() == &""
	if bag != null and not bare_stone and not bag.can_harvest(node["material"]):
		return {"reason": "herramienta"}
	var amount: int = node["yield"] + bonus
	var material: String = node["material"]
	var rewards := {StringName(material): amount}
	if material == "fibra":
		rewards[&"palo"] = 2
	if node["remaining"] == 1 and bag != null and not bag.can_add_many(rewards):
		return {"reason": "mochila_llena"}
	node["remaining"] -= 1
	if node["remaining"] > 0:
		return {"depleted": false}
	if bag != null:
		bag.add_many(rewards)
	for id in rewards:
		inventory[String(id)] += rewards[id]
	var footprint: Rect2i = node["footprint"]
	for y in range(footprint.position.y, footprint.end.y):
		for x in range(footprint.position.x, footprint.end.x):
			var released := Vector2i(x, y)
			world.cells[released]["blocked"] = false
			world.reachable.append(released)
	world.release_prop(cell)
	if meshes != null:
		meshes.remove(cell)
	nodes.erase(cell)
	return {"depleted": true, "material": material, "amount": amount, "rewards": rewards}
