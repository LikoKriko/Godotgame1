extends RefCounted
## Compact woodland clearing. Obstacles occupy separated slots, preserving corridors.
const TILE := 64
const SIZE := Vector2i(48, 32)
const FIRST := Vector2i(-24, -16)
const PLAYER_RADIUS := 15.0
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const Nature = preload("res://scripts/nature_variants.gd")
var seed_value := 73129
var terrain := FastNoiseLite.new()
var cells: Dictionary = {}
var props: Dictionary = {}
var large_rocks: Dictionary = {}
var prop_variants: Dictionary = {}
var prop_collisions: Dictionary = {}
var collision_cells: Dictionary = {}
var saplings: Dictionary = {}
var grass_tufts: Array[Dictionary] = []
var puddles: Array[Dictionary] = []
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
	prop_variants.clear()
	prop_collisions.clear()
	collision_cells.clear()
	saplings.clear()
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
	# Five additional rocks occupy the expanded outer woodland.
	rock_anchors.append(Vector2i(3, 10))
	for quadrant in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var x := rng.randi_range(FIRST.x + 3, FIRST.x + 8) if quadrant.x < 0 else rng.randi_range(FIRST.x + SIZE.x - 11, FIRST.x + SIZE.x - 4)
		var y := rng.randi_range(FIRST.y + 3, FIRST.y + 5) if quadrant.y < 0 else rng.randi_range(FIRST.y + SIZE.y - 6, FIRST.y + SIZE.y - 4)
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
	ensure_nature_variety()
	add_saplings(rng)
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
	assign_variants(rng)
	index_collisions()
	generate_ground_details()

func add_saplings(rng: RandomNumberGenerator) -> void:
	var candidates: Array[Vector2i] = [Vector2i(2, 2), Vector2i(-3, 2)]
	for i in 160:
		candidates.append(Vector2i(rng.randi_range(FIRST.x + 2, FIRST.x + SIZE.x - 3), rng.randi_range(FIRST.y + 2, FIRST.y + SIZE.y - 3)))
	for cell in candidates:
		if saplings.size() >= 20:
			break
		if cells[cell]["blocked"] or cells[cell]["road"]:
			continue
		props[cell] = 4
		cells[cell]["blocked"] = true
		saplings[cell] = {"height": rng.randf_range(34, 50), "tint": Color(0.94, rng.randf_range(0.96, 1.0), 0.92)}

func generate_ground_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 90210
	grass_tufts.clear()
	puddles.clear()
	var inset := bounds.grow(-96)
	for i in 650:
		var point := Vector2(rng.randf_range(inset.position.x, inset.end.x), rng.randf_range(inset.position.y, inset.end.y)).snapped(Vector2(2, 2))
		if (absf(point.x) < 85 or absf(point.y) < 85) and rng.randf() < 0.9:
			continue
		if walkable(point, 2):
			grass_tufts.append({"position": point, "width": rng.randf_range(10, 24), "variant": rng.randi_range(0, 1)})
	var count := rng.randi_range(3, 5)
	for i in 100:
		if puddles.size() >= count:
			break
		var point := Vector2(rng.randf_range(inset.position.x, inset.end.x), rng.randf_range(inset.position.y, inset.end.y)).snapped(Vector2(2, 2))
		if not walkable(point, 32):
			continue
		var separated := true
		for puddle in puddles:
			if point.distance_to(puddle["position"]) < 600:
				separated = false
		if separated:
			puddles.append({"position": point, "width": rng.randf_range(28, 48)})

func ensure_nature_variety() -> void:
	var normal_rocks := 0
	for cell in props:
		if props[cell] == 1 and not large_rocks.has(cell):
			normal_rocks += 1
	for cell in cells:
		if normal_rocks >= 24:
			break
		if not cells[cell]["blocked"] and not cells[cell]["road"] and posmod(cell.x, 3) == 1 and posmod(cell.y, 3) == 1:
			props[cell] = 1
			cells[cell]["blocked"] = true
			normal_rocks += 1

func assign_variants(rng: RandomNumberGenerator) -> void:
	var tree_ids: Array[int] = []
	var rock_ids: Array[int] = []
	# Balanced seeded pools expose the catalogue without unrelated random flicker.
	for i in Nature.COUNT:
		tree_ids.append(i)
		if i < 24:
			rock_ids.append(i)
	shuffle_ids(tree_ids, rng)
	shuffle_ids(rock_ids, rng)
	var counts := {1: 0, 2: 0}
	var big_count := 0
	for cell in props:
		var kind: int = props[cell]
		if kind == 4:
			var height: float = saplings[cell]["height"]
			prop_collisions[cell] = Rect2(center(cell) + Vector2(-3, 26 - height * 0.14), Vector2(6, height * 0.14))
			continue
		if kind not in [1, 2]:
			prop_collisions[cell] = Rect2(Vector2(cell * TILE), Vector2(TILE, TILE))
			continue
		var id: int
		if large_rocks.has(cell):
			id = 24 + big_count % 6
			big_count += 1
		else:
			var ids := tree_ids if kind == 2 else rock_ids
			id = ids[counts[kind] % ids.size()]
			counts[kind] += 1
		prop_variants[cell] = id
		var position := center(cell) + (Vector2(32, 32) if large_rocks.has(cell) else Vector2.ZERO)
		prop_collisions[cell] = Nature.collision(position, kind, id, large_rocks.has(cell))

func shuffle_ids(ids: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(ids.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var value := ids[i]
		ids[i] = ids[other]
		ids[other] = value

func index_collisions() -> void:
	collision_cells.clear()
	for anchor in prop_collisions:
		var rect: Rect2 = prop_collisions[anchor]
		var first := cell_at(rect.position)
		var last := cell_at(rect.end)
		for y in range(first.y, last.y + 1):
			for x in range(first.x, last.x + 1):
				var cell := Vector2i(x, y)
				if not collision_cells.has(cell):
					collision_cells[cell] = []
				collision_cells[cell].append(anchor)

func release_prop(cell: Vector2i) -> void:
	props.erase(cell)
	large_rocks.erase(cell)
	prop_variants.erase(cell)
	prop_collisions.erase(cell)
	saplings.erase(cell)
	index_collisions()

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
			var border := cell.x == FIRST.x or cell.x == FIRST.x + SIZE.x - 1 or cell.y == FIRST.y or cell.y == FIRST.y + SIZE.y - 1
			if not cells.has(cell) or border:
				var rect := Rect2(Vector2(cell * TILE), Vector2(TILE, TILE))
				var nearest := point.clamp(rect.position, rect.end)
				if nearest.distance_squared_to(point) < radius * radius:
					return false
			for anchor in collision_cells.get(cell, []):
				var rect: Rect2 = prop_collisions[anchor]
				if point.distance_squared_to(point.clamp(rect.position, rect.end)) < radius * radius:
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
