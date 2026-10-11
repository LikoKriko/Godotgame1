extends RefCounted
## Compact woodland clearing. Obstacles occupy separated slots, preserving corridors.
const TILE := 64
const SIZE := Vector2i(32, 24)
const FIRST := Vector2i(-16, -12)
const PLAYER_RADIUS := 15.0
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
var seed_value := 73129
var terrain := FastNoiseLite.new()
var cells: Dictionary = {}
var props: Dictionary = {}
var large_rocks: Dictionary = {}
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
	large_rocks.clear()
	reachable.clear()
	for y in range(FIRST.y, FIRST.y + SIZE.y):
		for x in range(FIRST.x, FIRST.x + SIZE.x):
			var cell := Vector2i(x, y)
			var border := x == FIRST.x or x == FIRST.x + SIZE.x - 1 or y == FIRST.y or y == FIRST.y + SIZE.y - 1
			var road := absi(x) <= 1 or absi(y) <= 1
			var zone := biome_at(cell)
			var blocked := border
			if not road and not border and posmod(x, 3) == 1 and posmod(y, 3) == 1 and rng.randf() < 0.5:
				blocked = true
				props[cell] = 2 if rng.randf() < 0.65 else 1
			cells[cell] = {"zone": zone, "blocked": blocked, "road": road, "variant": rng.randi_range(0, 7)}
	# Several large rocks, each with a matching 2x2 collision footprint.
	var rock_anchors: Array[Vector2i] = [Vector2i(3, -4)]
	for quadrant in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var x := rng.randi_range(-13, -8) if quadrant.x < 0 else rng.randi_range(7, 11)
		var y := rng.randi_range(-9, -7) if quadrant.y < 0 else rng.randi_range(6, 8)
		rock_anchors.append(Vector2i(x, y))
	for anchor in rock_anchors:
		large_rocks[anchor] = true
		for y in 2:
			for x in 2:
				var occupied := anchor + Vector2i(x, y)
				props.erase(occupied)
				cells[occupied]["blocked"] = true
		props[anchor] = 1
	# Common trees close enough to inspect from the starting area.
	for cell in [Vector2i(-4, -3), Vector2i(-6, 3), Vector2i(4, 4)]:
		props[cell] = 2
		cells[cell]["blocked"] = true
	# A small trace of abandoned equipment preserves scrap gathering in the woods.
	for cell in [Vector2i(-8, -5), Vector2i(7, 4)]:
		props[cell] = 0
		cells[cell]["blocked"] = true
	for cell in [Vector2i(-5, -5)]:
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
	# Inaccessible pockets become rubble, keeping exploration terrain connected.
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
