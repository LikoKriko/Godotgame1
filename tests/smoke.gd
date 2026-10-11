extends SceneTree
var checks := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)
func work(game, cell: Vector2i) -> void:
	var footprint: Rect2 = game.resources.bounds(cell)
	game.player = footprint.position + Vector2(-24, footprint.size.y / 2)
	check(game.world.walkable(game.player), "Test approach is reachable")
	var hits: int = game.resources.nodes[cell]["remaining"]
	for i in hits:
		check(game.start_work(cell), "Can begin work")
		game.advance_work(game.work_duration * 0.49)
		check(game.resources.nodes[cell]["remaining"] == hits - i, "No drop before strike")
		game.advance_work(game.work_duration * 0.02)
		game.advance_work(game.work_duration)
func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(not game.has_method("spawn_enemy") and not game.has_method("attack"), "Exploration contains no enemy spawning or combat")
	for i in 600:
		game._process(0.1)
	check(game.resources.inventory == {"madera": 0, "mineral": 0, "chatarra": 0}, "Idle exploration grants no resources")
	var tree := Vector2i(-4, -3)
	check(not game.start_work(tree), "Cannot harvest at distance")
	game.player = game.resources.bounds(tree).position + Vector2(-24, 32)
	check(game.start_work(tree), "Tree in reach")
	game.advance_work(0.1)
	game.cancel_work()
	check(game.resources.nodes[tree]["remaining"] == 3, "Cancel before impact causes no damage")
	game.skills_open = true
	check(not game.start_work(tree), "Panel blocks collection")
	game.skills_open = false
	work(game, tree)
	check(game.resources.inventory["madera"] == 4, "Wood enters inventory")
	check(not game.world.props.has(tree) and game.world.walkable(game.world.center(tree)), "Depleted tree frees passage")
	check(game.resources.hit(tree, game.player).is_empty(), "Cannot collect depleted tree twice")
	var rock := Vector2i(3, -4)
	work(game, rock)
	check(game.resources.inventory["mineral"] == 12, "Large rock gives minerals")
	for y in 2:
		for x in 2:
			check(game.world.walkable(game.world.center(rock + Vector2i(x, y))), "Entire rock footprint released")
	check(game.level == 2 and game.skill_points == 1, "Gathering earns experience and a skill point")
	game.upgrade(0)
	check(game.ranks[0] == 1 and game.skill_points == 0, "Gathering upgrade")
	var machine: Vector2i = game.resources.NONE
	for cell in game.resources.nodes:
		if game.resources.nodes[cell]["material"] == "chatarra":
			machine = cell
			break
	check(machine != game.resources.NONE, "Scrap source exists")
	work(game, machine)
	check(game.resources.inventory["chatarra"] == 3, "Scrap enters inventory")
	game.restart()
	check(game.resources.inventory["madera"] == 0 and game.resources.nodes.has(tree), "Reset restores resources and clears inventory")
	game.player = game.resources.bounds(tree).position + Vector2(-24, 32)
	var input := InputEventKey.new()
	input.keycode = KEY_E
	input.physical_keycode = KEY_E
	input.pressed = true
	Input.parse_input_event(input)
	Input.flush_buffered_events()
	game._process(0.01)
	check(game.working and game.character.animation == &"harvest_right", "E starts directional harvesting")
	var release: InputEventKey = input.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	game.cancel_work()
	var frames: SpriteFrames = game.character.sprite_frames
	for direction in [&"down", &"left", &"right", &"up"]:
		check(frames.get_frame_count("harvest_" + direction) == 4, "Four harvesting frames per direction")
	print("PASS: %d exploration checks: wood, minerals, scrap, animation, cancellation, range, inventory, progression, reset" % checks)
	quit(0)
