extends SceneTree
const World = preload("res://scripts/test_world.gd")
var checks := 0
var failures := 0

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var map = World.new()
	for seed_value in range(73129, 73149):
		map.generate(seed_value)
		require(map.cells.size() == 2 * 32 * 24, "Map has exactly twice the original surface area")
		require(map.bounds.size == Vector2(3072, 2048), "Expanded world bounds")
		require(map.walkable(Vector2.ZERO), "Safe spawn")
		require(map.large_rocks.size() == 10, "Ten large rocks per expanded map")
		for anchor in map.large_rocks:
			require(not map.walkable(map.prop_collisions[anchor].get_center()), "Large-rock body has collision")
		require(map.props[Vector2i(-4, -3)] == 2, "Tree near starting area")
		var snapshot: Dictionary = map.cells.duplicate(true)
		var variant_snapshot: Dictionary = map.prop_variants.duplicate()
		map.generate(seed_value)
		require(snapshot == map.cells, "Repeatable seed")
		require(variant_snapshot == map.prop_variants, "Nature variants repeat with the same seed")
		var reachable_set := {}
		for cell in map.reachable:
			reachable_set[cell] = true
		for cell in map.cells:
			if not map.cells[cell]["blocked"]:
				require(reachable_set.has(cell), "All open cells connected")
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var destination: Vector2 = map.move_actor(Vector2.ZERO, direction * 3000)
			require(map.walkable(destination), "Large movement cannot tunnel through boundary")
			require(map.bounds.has_point(destination), "Player remains inside map")
			require(destination.length() > (1024.0 if direction.x != 0 else 768.0), "Expanded corridors extend beyond previous boundary")
	map.generate(73129)
	var original: Dictionary = map.cells.duplicate(true)
	map.generate(73130)
	require(original != map.cells, "New seed changes distribution")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var input := InputEventKey.new()
	input.keycode = KEY_F2
	input.pressed = true
	game._unhandled_key_input(input)
	require(game.world.seed_value == 73130 and game.player == Vector2.ZERO, "F2 generates and resets run")
	require(game.minimap.world == game.world, "Minimap uses active map")
	require(Vector2(game.world.SIZE) * game.minimap.cell_scale() == Vector2(192, 144), "Expanded map fits minimap panel")
	require(game.camera.limit_left == -1536 and game.camera.limit_right == 1536 and game.camera.limit_top == -1024 and game.camera.limit_bottom == 1024, "Camera follows expanded world limits")
	require(game.world_view.ground_material.get_shader_parameter("map_seed") == 73130.0, "Ground follows regenerated seed")
	print("%s: %d world checks across 20 seeds, %d failures: connectivity, expanded boundaries, minimap and regeneration" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
