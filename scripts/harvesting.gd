extends RefCounted
const REACH := 76.0
const NONE := Vector2i(99999, 99999)
const TYPES := {
	0: {"name": "Maquinaria", "material": "chatarra", "hits": 3, "yield": 3, "branch": 3},
	1: {"name": "Roca", "material": "mineral", "hits": 3, "yield": 4, "branch": 1},
	2: {"name": "Árbol", "material": "madera", "hits": 3, "yield": 4, "branch": 0}
}
var world
var bag
var nodes: Dictionary = {}
var inventory := {"madera": 0, "mineral": 0, "chatarra": 0}

func configure(map, inventory_model = null) -> void:
	world = map
	bag = inventory_model
	nodes.clear()
	inventory = {"madera": 0, "mineral": 0, "chatarra": 0}
	for cell in world.props:
		var kind: int = world.props[cell]
		if not TYPES.has(kind):
			continue
		var data: Dictionary = TYPES[kind].duplicate()
		data["footprint"] = Rect2i(cell, Vector2i(2, 2) if world.large_rocks.has(cell) else Vector2i.ONE)
		if world.large_rocks.has(cell):
			data["name"] = "Roca grande"
			data["hits"] = 6
			data["yield"] = 12
		data["remaining"] = data["hits"]
		nodes[cell] = data

func bounds(cell: Vector2i) -> Rect2:
	var footprint: Rect2i = nodes[cell]["footprint"]
	return Rect2(Vector2(footprint.position * world.TILE), Vector2(footprint.size * world.TILE))

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

func hit(cell: Vector2i, player: Vector2, bonus: int = 0) -> Dictionary:
	if not can_reach(cell, player):
		return {}
	var node: Dictionary = nodes[cell]
	if bag != null and not bag.can_harvest(node["material"]):
		return {"reason": "herramienta"}
	var amount: int = node["yield"] + bonus
	var material: String = node["material"]
	if node["remaining"] == 1 and bag != null and not bag.can_add(StringName(material), amount):
		return {"reason": "mochila_llena"}
	node["remaining"] -= 1
	if node["remaining"] > 0:
		return {"depleted": false}
	if bag != null:
		bag.add(StringName(material), amount)
	inventory[material] += amount
	var footprint: Rect2i = node["footprint"]
	for y in range(footprint.position.y, footprint.end.y):
		for x in range(footprint.position.x, footprint.end.x):
			var released := Vector2i(x, y)
			world.cells[released]["blocked"] = false
			world.reachable.append(released)
	world.props.erase(cell)
	world.large_rocks.erase(cell)
	nodes.erase(cell)
	return {"depleted": true, "material": material, "amount": amount}
