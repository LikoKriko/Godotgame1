extends RefCounted
## Visible alpha silhouettes are independent of the small movement colliders.
var targets: Dictionary = {}
var silhouettes: Dictionary = {}
var host: Node2D

func configure(parent: Node2D) -> void:
	host = parent

func clear() -> void:
	for record in targets.values():
		host.remove_child(record["area"])
		record["area"].free()
	targets.clear()

func add(cell: Vector2i, texture: Texture2D, rect: Rect2, depth: float) -> void:
	var key := str(texture.get_instance_id())
	if not silhouettes.has(key):
		var bitmap := BitMap.new()
		bitmap.create_from_image_alpha(texture.get_image(), 0.6)
		var polygons := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), 3.0)
		silhouettes[key] = {"bitmap": bitmap, "polygons": polygons}
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
	targets[cell] = {"area": area, "bitmap": source["bitmap"], "depth": depth, "texture_size": texture.get_size(), "rest": rect}
	set_transform(cell, rect.position, 0.0, rect.size / texture.get_size())

func set_transform(cell: Vector2i, origin: Vector2, rotation: float, scale: Vector2) -> void:
	if targets.has(cell):
		var area: Area2D = targets[cell]["area"]
		area.transform = Transform2D(rotation, scale, 0, origin)

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
	var result := Vector2i(99999, 99999)
	var depth := -INF
	for cell in targets:
		if targets[cell]["depth"] > depth and contains(cell, point):
			result = cell
			depth = targets[cell]["depth"]
	return result

func remove(cell: Vector2i) -> void:
	if targets.has(cell):
		host.remove_child(targets[cell]["area"])
		targets[cell]["area"].free()
		targets.erase(cell)
