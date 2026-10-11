extends SceneTree
const World = preload("res://scripts/test_world.gd")
var checks := 0

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var map = World.new()
	for seed_value in range(73129, 73149):
		map.generate(seed_value)
		require(map.cells.size() == 32 * 24, "Finite 32x24 map")
		require(map.walkable(Vector2.ZERO), "Safe spawn")
		require(map.large_rocks.size() == 5, "Five large rocks per map")
		for anchor in map.large_rocks:
			for y in 2:
				for x in 2:
					require(not map.walkable(map.center(anchor + Vector2i(x, y))), "Large-rock collision covers its entire footprint")
		require(map.props[Vector2i(-4, -3)] == 2, "Tree near starting area")
		var snapshot: Dictionary = map.cells.duplicate(true)
		map.generate(seed_value)
		require(snapshot == map.cells, "Repeatable seed")
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
	require(game.world_view.ground_material.get_shader_parameter("map_seed") == 73130.0, "Ground follows regenerated seed")
	print("PASS: %d world checks across 20 seeds, connectivity, boundaries, regeneration" % checks)
	quit(0)
