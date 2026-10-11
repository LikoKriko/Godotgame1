extends RefCounted
## Compact quarantine yard. Obstacles occupy separated slots, preserving corridors.
const TILE := 64
const SIZE := Vector2i(32, 24)
const FIRST := Vector2i(-16, -12)
const PLAYER_RADIUS := 15.0
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var seed_value := 73129
var terrain := FastNoiseLite.new()
var cells: Dictionary = {}
var props: Dictionary = {}
var reachable: Array[Vector2i] = []
var bounds := Rect2(Vector2(FIRST * TILE), Vector2(SIZE * TILE))

func generate(new_seed: int) -> void:
	seed_value = new_seed
	terrain.seed = new_seed
	terrain.frequency = 0.11
	var rng := RandomNumberGenerator.new()
	rng.seed = new_seed
	cells.clear()
	props.clear()
	reachable.clear()
	for y in range(FIRST.y, FIRST.y + SIZE.y):
		for x in range(FIRST.x, FIRST.x + SIZE.x):
			var cell := Vector2i(x, y)
			var border := x == FIRST.x or x == FIRST.x + SIZE.x - 1 or y == FIRST.y or y == FIRST.y + SIZE.y - 1
			var road := absi(x) <= 1 or absi(y) <= 1
			var zone := biome_at(cell)
			var blocked := border
			if not road and not border and posmod(x, 3) == 1 and posmod(y, 3) == 1 and rng.randf() < 0.8:
				blocked = true
				props[cell] = zone
			cells[cell] = {"zone": zone, "blocked": blocked, "road": road, "variant": rng.randi_range(0, 7)}
	# Warning beacons are collision props away from the safe central pad.
	for cell in [Vector2i(-5, -5), Vector2i(5, -5), Vector2i(-5, 5), Vector2i(5, 5)]:
		props[cell] = 3
		cells[cell]["blocked"] = true
	var visited := {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for step in DIRECTIONS:
			var neighbor: Vector2i = current + step
			if cells.has(neighbor) and not cells[neighbor]["blocked"] and not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	reachable.assign(queue)
	# Inaccessible pockets become rubble, so enemies always use connected terrain.
	for cell in cells:
		if not cells[cell]["blocked"] and not visited.has(cell):
			cells[cell]["blocked"] = true
			props[cell] = 1

func biome_at(cell: Vector2i) -> int:
	var value := terrain.get_noise_2d(cell.x, cell.y)
	return 0 if value < -0.15 else (2 if value > 0.15 else 1)

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))

func center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(32, 32)

func walkable(point: Vector2, radius: float = PLAYER_RADIUS) -> bool:
	if not bounds.grow(-radius).has_point(point):
		return false
	var first := cell_at(point - Vector2.ONE * radius)
	var last := cell_at(point + Vector2.ONE * radius)
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var cell := Vector2i(x, y)
			if not cells.has(cell) or cells[cell]["blocked"]:
				var rect := Rect2(Vector2(cell * TILE), Vector2(TILE, TILE))
				var nearest := point.clamp(rect.position, rect.end)
				if nearest.distance_squared_to(point) < radius * radius:
					return false
	return true

func move_actor(point: Vector2, displacement: Vector2, radius: float = PLAYER_RADIUS) -> Vector2:
	# Substeps prevent crossing a wall on a slow frame or with upgraded speed.
	var steps := maxi(1, ceili(displacement.length() / 8.0))
	var step := displacement / steps
	for i in steps:
		if walkable(point + Vector2(step.x, 0), radius):
			point.x += step.x
		if walkable(point + Vector2(0, step.y), radius):
			point.y += step.y
	return point

func spawn_position(player: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var candidates: Array[Vector2i] = []
	for cell in reachable:
		var distance := center(cell).distance_to(player)
		if distance >= 440.0 and distance <= 850.0:
			candidates.append(cell)
	if candidates.is_empty():
		for cell in reachable:
			if center(cell).distance_to(player) >= 280.0:
				candidates.append(cell)
	if candidates.is_empty():
		return player
	return center(candidates[rng.randi_range(0, candidates.size() - 1)])

func flow_to(point: Vector2) -> Dictionary:
	# One shared breadth-first field for all enemies, avoiding scenery and walls.
	var origin := cell_at(point)
	var flow := {origin: Vector2i.ZERO}
	var queue: Array[Vector2i] = [origin]
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for step in DIRECTIONS:
			var neighbor: Vector2i = current + step
			if cells.has(neighbor) and not cells[neighbor]["blocked"] and not flow.has(neighbor):
				flow[neighbor] = -step
				queue.append(neighbor)
	return flow
