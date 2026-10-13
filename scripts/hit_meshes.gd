extends RefCounted
## Visible alpha silhouettes are independent of the small movement colliders.
var targets: Dictionary = {}
var silhouettes: Dictionary = {}
var host: Node2D
const BUCKET_SIZE := 128.0
var buckets: Dictionary = {}
var next_order := 0
var indexed_host := Transform2D.IDENTITY

func configure(parent: Node2D) -> void:
	host = parent
	indexed_host = host.global_transform

func clear() -> void:
	for record in targets.values():
		host.remove_child(record["area"])
		record["area"].free()
	targets.clear()
	buckets.clear(); next_order = 0
	if is_instance_valid(host): indexed_host = host.global_transform

func add(cell: Vector2i, texture: Texture2D, rect: Rect2, depth: float) -> void:
	var key := str(texture.get_instance_id())
	if not silhouettes.has(key):
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(texture.get_image(), 0.6)
		var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), 3.0)
		var surface := PackedVector2Array()
		for y in range(0,bitmap.get_size().y,6):
			for x in range(0,bitmap.get_size().x,6):
				if bitmap.get_bitv(Vector2i(x,y)):
					surface.append(Vector2(x+0.5,y+0.5))
		silhouettes[key] = {"bitmap": bitmap, "polygons": polygons, "surface": surface}
	var source: Dictionary = silhouettes[key]
	var area := Area2D.new()
	area.collision_layer = 16
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = false
	area.z_as_relative = false
	area.z_index = -20
	for polygon in source["polygons"]:
		var shape := CollisionPolygon2D.new()
		shape.polygon = polygon
		area.add_child(shape)
	host.add_child(area)
	targets[cell] = {"area": area, "bitmap": source["bitmap"], "depth": depth, "texture_size": texture.get_size(), "rest": rect, "surface": source["surface"],"order":next_order,"buckets":[]}
	next_order += 1
	set_transform(cell, rect.position, 0.0, rect.size / texture.get_size())
	index_cell(cell)

func set_transform(cell: Vector2i, origin: Vector2, rotation: float, scale: Vector2) -> void:
	if targets.has(cell):
		var area: Area2D = targets[cell]["area"]
		var placement := Transform2D(rotation, scale, 0, origin)
		if area.transform != placement:
			area.transform = placement
			index_cell(cell)

static func bucket_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x/BUCKET_SIZE),floori(point.y/BUCKET_SIZE))

func unindex_cell(cell: Vector2i) -> void:
	for key in targets[cell].get("buckets",[]):
		var entries: Array = buckets.get(key,[])
		entries.erase(cell)
		if entries.is_empty(): buckets.erase(key)

func index_cell(cell: Vector2i) -> void:
	var record: Dictionary = targets[cell]
	var transform: Transform2D = record.area.global_transform
	var size: Vector2 = record.texture_size
	var low := transform*Vector2.ZERO; var high := low
	for corner in [Vector2(size.x,0),size,Vector2(0,size.y)]:
		var point: Vector2 = transform*corner
		low = low.min(point); high = high.max(point)
	# Padding belongs only to the broad phase. The original bitmap test below
	# still decides the hit, including rotated edge pixels and negative scales.
	var bounds := Rect2(low,high-low).grow(0.001)
	record["world_bounds"] = bounds
	var first := bucket_at(bounds.position); var last := bucket_at(bounds.end)
	var keys := []
	for y in range(first.y,last.y+1):
		for x in range(first.x,last.x+1): keys.append(Vector2i(x,y))
	if keys == record.buckets: return
	unindex_cell(cell); record.buckets = keys
	for key in keys:
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(cell)

func contains(cell: Vector2i, point: Vector2) -> bool:
	if not targets.has(cell):
		return false
	var record: Dictionary = targets[cell]
	var area: Area2D = record["area"]
	var local := area.global_transform.affine_inverse() * point
	var bitmap: BitMap = record["bitmap"]
	var pixel := Vector2i(floori(local.x), floori(local.y))
	return Rect2i(Vector2i.ZERO, bitmap.get_size()).has_point(pixel) and bitmap.get_bitv(pixel)

func target_at(point: Vector2) -> Vector2i:
	if host.global_transform != indexed_host:
		indexed_host = host.global_transform
		for cell in targets: index_cell(cell)
	var result := Vector2i(99999, 99999)
	var depth := -INF
	var order := 9223372036854775807
	for cell in buckets.get(bucket_at(point),[]):
		var record: Dictionary = targets[cell]
		if not record.world_bounds.has_point(point): continue
		if (record.depth > depth or (record.depth == depth and record.order < order)) and contains(cell, point):
			result = cell
			depth = record.depth; order = record.order
	return result

func remove(cell: Vector2i) -> void:
	if targets.has(cell):
		unindex_cell(cell)
		host.remove_child(targets[cell]["area"])
		targets[cell]["area"].free()
		targets.erase(cell)

func nearest_surface(cell: Vector2i, point: Vector2) -> Vector2:
	if not targets.has(cell):
		return point
	if contains(cell,point):
		return point
	var record: Dictionary = targets[cell]
	var transform: Transform2D = record["area"].global_transform
	var nearest := point
	var distance := INF
	for sample in record["surface"]:
		var world_point: Vector2 = transform*sample
		var candidate := point.distance_squared_to(world_point)
		if candidate < distance:
			distance = candidate
			nearest = world_point
	return nearest
