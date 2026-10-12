extends RefCounted
const Rig = preload("res://scripts/arm_rig.gd")

## Find an opaque, reachable surface and a legal stance independently of the
## strike code, including the exposed flanks of the largest boulders.
static func approach(game, cell: Vector2i, item: StringName) -> Vector2:
	if item == &"":
		game.bag.unequip(&"hands")
	else:
		game.bag.select_tool(item)
	var record: Dictionary = game.world_view.hit_meshes.targets[cell]
	var rect: Rect2 = record["rest"]
	var collider: Rect2 = game.resources.bounds(cell)
	var points: Array[Vector2] = [collider.get_center(), collider.get_center() - Vector2(0,8)]
	for y in range(floori(rect.position.y), ceili(rect.end.y), 3):
		for x in range(floori(rect.position.x), ceili(rect.end.x), 3):
			points.append(Vector2(x+0.5,y+0.5))
	var stances: Array[Vector2] = [Vector2(20,-24), Vector2(-20,-24), Vector2(42,-24), Vector2(-42,-24), Vector2(0,16), Vector2(0,-55)]
	# A two-handed stance has a smaller joint reach intersection than a single
	# arm. Search legal nearby approaches instead of assuming six old offsets.
	for radius in [20.0,30.0,38.0,46.0,54.0]:
		for angle in 24:
			stances.append(Vector2.from_angle(angle*TAU/24)*radius)
	for aim in points:
		if game.resources.target_at(aim) != cell:
			continue
		for offset in stances:
			var player: Vector2 = aim-offset
			if not game.world.walkable(player):
				continue
			var pose := Rig.contact(player,aim,item)
			if not game.resources.can_reach(cell,player):
				continue
			var clear := true
			for i in range(1,ceili(pose["shoulder"].distance_to(aim)/2)):
				var point: Vector2 = pose["shoulder"].move_toward(aim,i*2)
				for obstacle in game.world.collision_cells.get(game.world.cell_at(point),[]):
					if obstacle != cell and game.world.prop_collisions[obstacle].has_point(point):
						clear = false
			if clear:
				game.player = player
				game.camera.position = player
				return aim
	push_error("No reachable surface for %s with %s" % [cell,item])
	return Vector2(INF,INF)
