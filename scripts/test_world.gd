extends RefCounted
## Compact woodland clearing. Obstacles occupy separated slots, preserving corridors.
const TILE := 64
const SIZE := Vector2i(48, 32)
const FIRST := Vector2i(-24, -16)
const PLAYER_RADIUS := 15.0
const DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
const RETIRED_STRUCTURE_CELLS := [Vector2i(-8,-5),Vector2i(7,4),Vector2i(-5,-5)]
var camp_buildings: Array[Dictionary] = []
var reserved_areas: Array[Rect2] = []
var tree_groups: Array = []
var tree_designs: Dictionary = {}
var previous_grass_count := 0
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
var burdock: Dictionary = {}
var grass_tufts: Array[Dictionary] = []
var puddles: Array[Dictionary] = []
var dirt_patches: Array[Rect2] = []
const JUMP_LIMIT := 19.2
const NO_SUPPORT := Vector2i(99999,99999)
var physical_heights: Dictionary = {}
var terrain_influences: Array[Dictionary] = []
var ground_sampler = preload("res://scripts/terrain_sampler.gd").new()
var ground_profile = preload("res://scripts/terrain_profile.gd").new()
var platforms: Array[Dictionary] = []
var building_collisions: Array[Rect2] = []
var navigation_revision := 0
var reachable: Array[Vector2i] = []
var bounds := Rect2(Vector2(FIRST * TILE), Vector2(SIZE * TILE))

func generate(new_seed: int, on_progress: Callable = Callable()) -> void:
	if on_progress.is_valid(): on_progress.call(0.02)
	navigation_revision += 1
	seed_value = new_seed
	ground_sampler.configure(new_seed,ground_profile); ground_sampler.existing_paths = true
	terrain.seed = new_seed
	terrain.frequency = 0.11
	var rng := RandomNumberGenerator.new()
	rng.seed = new_seed
	cells.clear()
	physical_heights.clear()
	props.clear()
	building_collisions.clear()
	camp_buildings = preload("res://scripts/camp_art.gd").layout()
	reserved_areas.clear()
	for building in camp_buildings:
		reserved_areas.append(building.rect.grow(20))
		building_collisions.append_array(building.walls)
	platforms.clear()
	large_rocks.clear()
	prop_variants.clear()
	prop_collisions.clear()
	collision_cells.clear()
	saplings.clear()
	burdock.clear()
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
	# Reserve the historical cells during seeded layout so existing plants and
	# natural variants do not move, then release the retired structures below.
	for cell in RETIRED_STRUCTURE_CELLS:
		props[cell] = 0
		cells[cell]["blocked"] = true
	ensure_nature_variety()
	if on_progress.is_valid(): on_progress.call(0.30)
	generate_tree_groups()
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
	for cell in props.keys():
		if in_reserved_area(center(cell),64):
			if large_rocks.has(cell):
				for y in 2:
					for x in 2: cells[cell+Vector2i(x,y)].blocked = false
			props.erase(cell); large_rocks.erase(cell); saplings.erase(cell)
			cells[cell].blocked = false
	assign_variants(rng)
	clear_camp_overlap()
	complete_rock_variety()
	if on_progress.is_valid(): on_progress.call(0.50)
	index_collisions()
	generate_ground_details()
	if on_progress.is_valid(): on_progress.call(0.65)
	add_burdock()
	for cell in RETIRED_STRUCTURE_CELLS:
		props.erase(cell); prop_collisions.erase(cell); cells[cell].blocked = false
		if not reachable.has(cell): reachable.append(cell)
	index_collisions()
	terrain_influences.clear()
	for cell in props:
		if props[cell] in [1,2,4]: terrain_influences.append({"id":StringName(str(cell)),"rect":prop_collisions[cell].grow(12 if props[cell] in [2,4] else 8)})
	generate_platforms()
	if on_progress.is_valid(): on_progress.call(0.85)
	generate_grass_cover(bounds.grow(-96),roundi(previous_grass_count*1.35))
	if on_progress.is_valid(): on_progress.call(1.0)

func add_burdock() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 40917
	for attempt in 10000:
		if burdock.size() == 24: break
		var cell: Vector2i = reachable[rng.randi_range(0,reachable.size()-1)]
		var base := center(cell)+Vector2(0,26)
		if props.has(cell) or cells[cell].road or not grass_allowed(base,12,false,false) or not walkable(base,42): continue
		var covered := false
		for anchor in props:
			if props[anchor] != 2: continue
			var height: float = tree_dimensions(anchor).y
			if Rect2(center(anchor)+Vector2(-height/2,26-height),Vector2(height,height)).grow(26).has_point(base): covered = true; break
		if covered: continue
		props[cell] = 5
		burdock[cell] = 1+burdock.size()%2
		prop_collisions[cell] = Rect2(center(cell)+Vector2(-10,22),Vector2(20,4))

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
		# Preserve the seed stream while replacing variable sizes with five equal-height drawings.
		rng.randf_range(34, 50); rng.randf_range(0.96, 1.0)
		saplings[cell] = {"height": 42.0, "tint": Color.WHITE}

func generate_ground_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 90210
	grass_tufts.clear()
	puddles.clear()
	var inset := bounds.grow(-96)
	var count := rng.randi_range(3, 5)
	for i in 100:
		if puddles.size() >= count:
			break
		var point := Vector2(rng.randf_range(inset.position.x, inset.end.x), rng.randf_range(inset.position.y, inset.end.y)).snapped(Vector2(2, 2))
		if in_reserved_area(point,48) or not walkable(point, 32):
			continue
		var separated := true
		for puddle in puddles:
			if point.distance_to(puddle["position"]) < 600:
				separated = false
		if separated:
			puddles.append({"position": point, "width": rng.randf_range(28, 48)})

	# Preserve the random stream used by older saved layouts, without
	# creating the retired gray gravel zones.
	for unused in 16: rng.randf()
	# Stratified, jittered cover prevents both empty stretches and a tile grid.
	var soil_rng := RandomNumberGenerator.new(); soil_rng.seed = seed_value ^ 65173
	dirt_patches.clear()
	for quadrant in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var patch_center: Vector2 = quadrant*Vector2(soil_rng.randf_range(350,1250),soil_rng.randf_range(240,780))
		var radius := Vector2(soil_rng.randf_range(65,125),soil_rng.randf_range(55,95))
		dirt_patches.append(Rect2(patch_center-radius,radius*2))
	previous_grass_count = grass_baseline_count(inset,rng)

func grass_baseline_count(inset: Rect2, rng: RandomNumberGenerator) -> int:
	# Keep the requested increase exact relative to the previous seeded cover.
	var baseline_count := 0
	for y in range(int(inset.position.y),int(inset.end.y),22):
		for x in range(int(inset.position.x),int(inset.end.x),24):
			var point := Vector2(x+rng.randf_range(-9,9),y+rng.randf_range(-8,8))
			var width := rng.randf_range(18,28)
			var variant := rng.randi_range(0,preload("res://scripts/imported_nature.gd").GRASS.size()-1)
			if rng.randf() < 0.60 and grass_allowed(point,grass_padding(width,variant)):
				baseline_count += 1

	return baseline_count

func generate_grass_cover(inset: Rect2, count: int) -> void:
	grass_tufts.clear()
	var cover_rng := RandomNumberGenerator.new(); cover_rng.seed = seed_value ^ 83717
	var grouping := FastNoiseLite.new(); grouping.seed = seed_value ^ 38117; grouping.frequency = 0.018
	var candidates: Array[Dictionary] = []
	for y in range(int(inset.position.y),int(inset.end.y),18):
		for x in range(int(inset.position.x),int(inset.end.x),20):
			var point := Vector2(x+cover_rng.randf_range(-6,6),y+cover_rng.randf_range(-6,6))
			var width := cover_rng.randf_range(18,28)
			var variant := cover_rng.randi_range(0,preload("res://scripts/imported_nature.gd").GRASS.size()-1)
			if not grass_allowed(point,grass_padding(width,variant)): continue
			var density := exp(grouping.get_noise_2d(point.x,point.y)*3.0)*maxf(0.05,ground_sampler.vegetation_density(point))
			var rank := -log(maxf(0.000001,cover_rng.randf()))/density
			candidates.append({"position":point,"width":width,"variant":variant,"rank":rank})
	candidates.sort_custom(func(a,b): return a.rank < b.rank)
	for i in mini(count,candidates.size()):
		var tuft: Dictionary = candidates[i]; tuft.erase("rank"); grass_tufts.append(tuft)

static func grass_padding(width: float, variant: int) -> float:
	var region: Rect2 = preload("res://scripts/imported_nature.gd").GRASS[variant].rect
	return maxf(width*0.55,width*region.size.y/region.size.x)

func grass_allowed(point: Vector2, padding: float = 0.0, exclude_dirt: bool = true, exclude_bases: bool = true) -> bool:
	if in_reserved_area(point,padding): return false
	for platform in platforms:
		if platform.rect.grow(padding).has_point(point): return false
	var horizontal := 24*sin(point.x/210)+10*sin(point.x/93)
	var vertical := 24*sin(point.y/245)-10*sin(point.y/110)
	if minf(absf(point.y-horizontal),absf(point.x-vertical)) < 82+padding:
		return false
	if exclude_dirt:
		for patch in dirt_patches:
			var radius := patch.size/2+Vector2.ONE*(padding+20)
			if ((point-patch.get_center())/radius).length() < 1.0: return false
	if exclude_bases:
		var first := cell_at(point-Vector2.ONE*padding)
		var last := cell_at(point+Vector2.ONE*padding)
		for y in range(first.y,last.y+1):
			for x in range(first.x,last.x+1):
				for anchor in collision_cells.get(Vector2i(x,y),[]):
					if prop_collisions[anchor].grow(padding).has_point(point): return false
	for puddle in puddles:
		if point.distance_to(puddle["position"]) < puddle["width"]*0.55+padding:
			return false
	return true

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
		if kind == 2:
			var height := tree_dimensions(cell).y
			prop_collisions[cell] = Rect2(position+Vector2(-height*0.055,26-height*0.10),Vector2(height*0.11,height*0.10))
		elif Nature.profile(1,id).size >= 64*0.65:
			var width: float = Nature.profile(1,id).size*0.72
			prop_collisions[cell] = Rect2(position+Vector2(-width/2,(60 if large_rocks.has(cell) else 26)-12),Vector2(width,12))

func shuffle_ids(ids: Array[int], rng: RandomNumberGenerator) -> void:
	for i in range(ids.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var value := ids[i]
		ids[i] = ids[other]
		ids[other] = value

func index_collisions() -> void:
	collision_cells.clear()
	for anchor in prop_collisions:
		if props.get(anchor) == 5: continue # Visible hit surface, freely walkable.
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
	if props.get(cell) != 5: navigation_revision += 1
	props.erase(cell)
	physical_heights.erase(cell)
	large_rocks.erase(cell)
	prop_variants.erase(cell)
	prop_collisions.erase(cell)
	saplings.erase(cell)
	burdock.erase(cell)
	index_collisions()

func biome_at(cell: Vector2i) -> int:
	var value := terrain.get_noise_2d(cell.x, cell.y)
	return 0 if value < -0.15 else (2 if value > 0.15 else 1)

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE), floori(point.y / TILE))

func center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE) + Vector2(32, 32)

func walkable(point: Vector2, radius: float = PLAYER_RADIUS, clearance: float = 0, support: Vector2i = NO_SUPPORT) -> bool:
	for rect in building_collisions:
		if point.distance_squared_to(point.clamp(rect.position,rect.end)) < radius*radius: return false
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
				var height := physical_height(anchor)
				if anchor == support or (height <= JUMP_LIMIT and clearance >= height): continue
				var rect: Rect2 = prop_collisions[anchor]
				if point.distance_squared_to(point.clamp(rect.position, rect.end)) < radius * radius:
					return false
	return true

func move_actor(point: Vector2, displacement: Vector2, radius: float = PLAYER_RADIUS, clearance: float = 0, support: Vector2i = NO_SUPPORT) -> Vector2:
	# Substeps prevent crossing a wall on a slow frame or with upgraded speed.
	var steps := maxi(1, ceili(displacement.length() / 8.0))
	var step := displacement / steps
	for i in steps:
		if walkable(point + Vector2(step.x, 0), radius,clearance,support):
			point.x += step.x
		if walkable(point + Vector2(0, step.y), radius,clearance,support):
			point.y += step.y
	return point

func physical_height(cell: Vector2i) -> float:
	if physical_heights.has(cell): return physical_heights[cell]
	if props.get(cell) == 1:
		var profile := Nature.profile(1,prop_variants[cell])
		var source: Rect2 = preload("res://scripts/imported_nature.gd").ROCKS[profile.size_index*2+profile.shape].rect
		physical_heights[cell] = Nature.dimensions(1,prop_variants[cell],source.size).y
		return physical_heights[cell]
	if props.get(cell) == 2: return tree_dimensions(cell).y
	return 42.0 if props.get(cell) == 4 else 100.0

func generate_platforms() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value ^ 29183
	var art = preload("res://scripts/raised_ground.gd"); art.prepare()
	for attempt in 10000:
		if platforms.size() == 4: break
		var platform_center := Vector2(rng.randf_range(-1100,1100),rng.randf_range(-700,700))
		var width := rng.randf_range(Nature.CHARACTER_WIDTH*2,Nature.CHARACTER_WIDTH*3); var variant := platforms.size()%3
		var texture: Texture2D = art.textures[variant]
		var size := Vector2(width,width*texture.get_height()/texture.get_width())
		var rect := Rect2(platform_center-size/2,size)
		if not grass_allowed(platform_center,size.length()/2) or not walkable(platform_center,size.length()/2+24): continue
		var clear := true
		for cell in props:
			if props[cell] in [2,4,5] and platform_center.distance_to(self.center(cell)) < 150: clear = false; break
		for platform in platforms:
			if platform.rect.grow(48).intersects(rect): clear = false
		if clear: platforms.append({"variant":variant,"rect":rect,"height":art.HEIGHT})

func surface_height(point: Vector2) -> float:
	for platform in platforms:
		if preload("res://scripts/raised_ground.gd").contains(platform,point): return platform.height
	return 0.0

func in_reserved_area(point: Vector2, padding: float = 0.0) -> bool:
	for area in reserved_areas:
		if area.grow(padding).has_point(point): return true
	return false

func tree_dimensions(cell: Vector2i) -> Vector2:
	return preload("res://scripts/large_tree_art.gd").dimensions(tree_designs.get(cell,posmod(cell.x*31+cell.y*17,9)))

func generate_tree_groups() -> void:
	for cell in props.keys():
		if props[cell] == 2: props.erase(cell); cells[cell].blocked = false
	tree_groups.clear(); tree_designs.clear()
	var rng := RandomNumberGenerator.new(); rng.seed = seed_value ^ 33281
	var centers: Array[Vector2] = []
	for attempt in 1000:
		if tree_groups.size() >= 10: break
		var anchor := Vector2i(rng.randi_range(FIRST.x+3,FIRST.x+SIZE.x-4),rng.randi_range(FIRST.y+3,FIRST.y+SIZE.y-4))
		var point := center(anchor)
		var separated := true
		for previous in centers:
			if point.distance_to(previous) < 430: separated = false
		if not separated or in_reserved_area(point,180): continue
		var candidates: Array[Vector2i] = []
		for y in range(-2,3):
			for x in range(-2,3):
				var cell := anchor+Vector2i(x,y)
				if not cells.has(cell) or cells[cell].road or props.has(cell) or cells[cell].blocked or in_reserved_area(center(cell),85): continue
				if center(cell).distance_to(point) > 155: continue
				candidates.append(cell)
		for i in range(candidates.size()-1,0,-1):
			var other := rng.randi_range(0,i); var saved := candidates[i]; candidates[i] = candidates[other]; candidates[other] = saved
		var count := mini(rng.randi_range(3,15),candidates.size())
		if count < 3: continue
		var group: Array[Vector2i] = []
		for i in count:
			var cell := candidates[i]; props[cell] = 2; cells[cell].blocked = true
			tree_designs[cell] = posmod(i+tree_groups.size()*3,9); group.append(cell)
		tree_groups.append(group); centers.append(point)

func clear_camp_overlap() -> void:
	for cell in props.keys():
		if props[cell] not in [1,2]: continue
		var kind: int = props[cell]
		var dimensions: Vector2
		if kind == 2: dimensions = tree_dimensions(cell)
		else:
			var profile := Nature.profile(1,prop_variants[cell])
			var source: Rect2 = preload("res://scripts/imported_nature.gd").ROCKS[profile.size_index*2+profile.shape].rect
			dimensions = Nature.dimensions(1,prop_variants[cell],source.size)
		var point := center(cell)+(Vector2(32,32) if large_rocks.has(cell) else Vector2.ZERO)
		var visual := Rect2(point+Vector2(-dimensions.x/2,(60 if large_rocks.has(cell) else 26)-dimensions.y),dimensions)
		var overlaps := false
		for area in reserved_areas:
			if visual.intersects(area): overlaps = true; break
		if not overlaps: continue
		if large_rocks.has(cell):
			for y in 2:
				for x in 2: cells[cell+Vector2i(x,y)].blocked = false
		props.erase(cell); large_rocks.erase(cell); prop_variants.erase(cell); prop_collisions.erase(cell); cells[cell].blocked = false

func complete_rock_variety() -> void:
	var shown := {}
	for cell in props:
		if props[cell] == 1: shown[prop_variants[cell]] = true
	for id in Nature.COUNT:
		if shown.has(id): continue
		for cell in cells:
			if cells[cell].road or cells[cell].blocked or props.has(cell) or in_reserved_area(center(cell),130): continue
			var separated := true
			for other in props:
				var point := center(other)+(Vector2(32,32) if large_rocks.has(other) else Vector2.ZERO)
				if center(cell).distance_to(point) < 150: separated = false; break
			if not separated: continue
			props[cell] = 1; prop_variants[cell] = id; cells[cell].blocked = true
			prop_collisions[cell] = Nature.collision(center(cell),1,id,false)
			var width: float = Nature.profile(1,id).size*0.72
			if Nature.profile(1,id).size >= 64*0.65:
				prop_collisions[cell] = Rect2(center(cell)+Vector2(-width/2,14),Vector2(width,12))
			break
