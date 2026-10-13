extends SceneTree
const Nature = preload("res://scripts/nature_variants.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var map = game.world
	for kind in [1, 2]:
		var unique := {}
		var sizes := {}
		for id in Nature.COUNT:
			var data := Nature.profile(kind, id)
			unique[str(data["shape"]) + ":" + str(data["size"]) + ":" + str(data["tint"])] = true
			sizes[data["size"]] = true
			var texture: Texture2D = game.world_view.forest_textures[data["shape"]] if kind == 2 else preload("res://scripts/imported_nature.gd").texture(preload("res://scripts/imported_nature.gd").ROCKS[data.size_index*2+data.shape])
			var dimensions := Nature.dimensions(kind, id, texture.get_size())
			var rect := Rect2(Vector2(-dimensions.x / 2, 26 - dimensions.y), dimensions)
			var body := Nature.collision(Vector2.ZERO, kind, id, false)
			require(rect.encloses(body), "Collider stays inside natural sprite")
			require(dimensions.x > 0 and dimensions.y > 0, "Positive sprite dimensions")
			var tint: Color = data["tint"]
			require(minf(tint.r, minf(tint.g, tint.b)) >= 0.9, "Restrained same-species tones")
			require(is_equal_approx(dimensions.x if kind == 1 else dimensions.y, data["size"]), "Rendered size matches catalogue")
			if kind == 1:
				require(dimensions.x >= Nature.CHARACTER_HEIGHT * 0.2 and dimensions.x <= Nature.CHARACTER_HEIGHT * 2.0, "Rock size range 20 to 200 percent")
			else:
				require(body.size.x < dimensions.x * 0.25, "Tree collider follows trunk rather than canopy")
		require(unique.size() >= 30 and sizes.size() == 5, "Thirty distinct variants and five sizes per natural prop")
	var minimum := Nature.dimensions(1, 0, Vector2(640, 400)).x
	var maximum := Nature.dimensions(1, 24, Vector2(640, 400)).x
	require(is_equal_approx(minimum / Nature.CHARACTER_HEIGHT, 0.2), "Smallest pebble is 20 percent")
	require(is_equal_approx(maximum / Nature.CHARACTER_HEIGHT, 2.0), "Largest boulder is 200 percent")
	var shown := {1: {}, 2: {}}
	var small := Vector2i(99999, 99999)
	for cell in map.prop_variants:
		var kind: int = map.props[cell]
		var id: int = map.prop_variants[cell]
		shown[kind][id] = true
		require(id >= 0 and id < 30, "Seed assigns valid catalogue ID")
		require(not map.walkable(map.prop_collisions[cell].get_center()), "Each natural prop blocks its own body")
		if kind == 1 and id < 6 and small == game.resources.NONE:
			small = cell
	require(shown[2].size() == 30, "Initial map exposes all thirty tree variants")
	require(shown[1].size() == 30, "Initial map exposes all thirty rock variants")
	require(small != game.resources.NONE, "Initial map includes tiny pebbles")
	var tree_body: Rect2 = map.prop_collisions[Vector2i(-4, -3)]
	require(map.walkable(tree_body.get_center() + Vector2(tree_body.size.x / 2 + map.PLAYER_RADIUS + 2, 0)), "Player can walk beside trunk beneath canopy")
	if small != game.resources.NONE:
		var body: Rect2 = map.prop_collisions[small]
		require(map.walkable(map.center(small)), "Tiny pebble does not block its entire cell")
		require(body.size.x < 16, "Tiny pebble has a small collider")
		game.bag.unequip(&"tool")
		var approach := Vector2.ZERO
		var found := false
		for candidate in [body.position + Vector2(-24, body.size.y / 2), body.position + Vector2(body.size.x + 24, body.size.y / 2), body.position + Vector2(body.size.x / 2, -24), body.position + Vector2(body.size.x / 2, body.size.y + 24)]:
			if map.walkable(candidate) and game.resources.can_reach(small, candidate):
				approach = candidate
				found = true
				break
		require(found, "Small stone is approachable from a free side")
		var hits: int = game.resources.nodes[small]["remaining"]
		for i in hits:
			game.resources.hit(small, approach)
		require(game.bag.count(&"piedra") >= 1 and game.bag.count(&"piedra") <= 3, "Variable-sized stone gives the matching stone yield")
		require(not map.props.has(small) and not map.prop_variants.has(small) and not map.prop_collisions.has(small), "Harvest removes sprite, variant and collider")
		require(map.walkable(body.get_center()), "Harvest frees the actual collision body")
		for entries in map.collision_cells.values():
			require(not entries.has(small), "Spatial index contains no stale harvested collider")
	game.restart()
	require(game.world.prop_collisions.has(small), "Reset restores collected stone and collider")
	var tree := Vector2i(-4, -3)
	var sprite: Sprite2D = game.world_view.tree_sprites[tree]
	var under_canopy: Vector2 = game.world.prop_collisions[tree].position + Vector2(-24, -20)
	require(map.walkable(under_canopy), "Can pass under canopy outside tree base")
	game.player = under_canopy
	game._process(0.02)
	require(sprite.modulate.a < 1 and sprite.modulate.a > 0.35, "Tree fades smoothly instead of snapping")
	game.world_view.update_trees(under_canopy, 1.0)
	require(absf(sprite.modulate.a - 0.35) < 0.01 and sprite.z_index == 1, "Occluding tree is translucent above character")
	game.world_view.update_trees(game.world.prop_collisions[tree].end + Vector2(0, 40), 1.0)
	require(sprite.modulate.a > 0.99 and sprite.z_index == -1, "Tree restores opacity and goes behind character in front")
	game.bag.select_tool(&"axe")
	var approach: Vector2 = game.world.prop_collisions[tree].position + Vector2(-24, 4)
	for i in 3:
		game.resources.hit(tree, approach)
	game.world_view.update_trees(game.player, 0.1)
	require(not game.world_view.tree_sprites.has(tree), "Harvest removes translucent tree sprite")
	game.restart()
	require(game.world_view.tree_sprites.has(tree), "Reset restores tree sprites")
	print("%s: %d nature checks, %d failures; initial map: %d tree variants and %d rock variants" % ["PASS" if failures == 0 else "FAIL", checks, failures, shown[2].size(), shown[1].size()])
	quit(0 if failures == 0 else 1)
