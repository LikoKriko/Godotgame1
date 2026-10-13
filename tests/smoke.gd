extends SceneTree
const Aim = preload("res://tests/aim_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	call_deferred("run_checks")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		failures += 1
func work(game, cell: Vector2i) -> void:
	var material: String = game.resources.nodes[cell]["material"]
	var item: StringName = &"" if material in ["chatarra", "fibra"] else (&"axe" if material == "madera" else &"pickaxe")
	var aim: Vector2 = Aim.approach(game, cell, item)
	check(aim.is_finite(), "Reachable test surface")
	var hits: int = game.resources.nodes[cell]["remaining"]
	for i in hits:
		check(game.start_work(aim), "Can begin work")
		game.advance_work(game.work_duration * 0.49)
		check(game.resources.nodes[cell]["remaining"] == hits - i, "No drop before strike")
		game.advance_work(game.work_duration * 0.02)
		game.advance_work(game.work_duration)
func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	check(not game.has_method("spawn_enemy") and not game.has_method("attack"), "Exploration contains no enemy spawning or combat")
	var initial_resources: Dictionary = game.resources.inventory.duplicate()
	for i in 600:
		game._process(0.1)
	check(game.resources.inventory == initial_resources, "Idle exploration grants no resources, including newly introduced materials")
	var tree := Vector2i(-4, -3)
	var aim: Vector2 = game.resources.bounds(tree).get_center()
	check(game.start_work(aim), "Distant swing starts")
	game.advance_work(game.work_duration)
	check(game.resources.nodes[tree]["remaining"] == 3, "Distant swing cannot gather")
	aim = Aim.approach(game, tree, &"axe")
	check(game.start_work(aim), "Tree in reach")
	game.advance_work(0.1)
	game.cancel_work()
	check(game.resources.nodes[tree]["remaining"] == 3, "Cancel before impact causes no damage")
	game.inventory_panel.open_section(2)
	check(not game.start_work(aim), "Panel blocks collection")
	game.inventory_panel.hide()
	work(game, tree)
	check(game.resources.inventory["madera"] == 4, "Wood enters inventory")
	check(not game.world.props.has(tree) and game.world.walkable(game.world.center(tree)), "Depleted tree frees passage")
	check(game.resources.hit(tree, game.player).is_empty(), "Cannot collect depleted tree twice")
	var rock := Vector2i(3, -4)
	work(game, rock)
	check(game.resources.inventory["piedra"] == 12, "Large rock gives minerals")
	for y in 2:
		for x in 2:
			check(game.world.walkable(game.world.center(rock + Vector2i(x, y))), "Entire rock footprint released")
	check(game.level == 2 and game.skill_points == 1, "Gathering earns experience and a skill point")
	game.buy_improvement(&"speed",true)
	check(game.progression.skills[&"speed"] == 1 and game.skill_points == 0, "Shared level point unlocks an ability")
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
	check(game.working and game.full_avatar.state == &"action", "E starts a cursor-directed whole-frame strike")
	var release: InputEventKey = input.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	game.cancel_work()
	print("%s: %d exploration checks: wood, minerals, scrap, animation, cancellation, range, inventory, progression, reset" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
