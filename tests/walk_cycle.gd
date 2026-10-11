extends SceneTree
var loops := 0
var checks := 0

func _initialize() -> void:
	call_deferred("run_checks")

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.character.animation_looped.connect(func(): loops += 1)
	var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
	var keys := [KEY_S, KEY_A, KEY_D, KEY_W]
	var names := [&"down", &"left", &"right", &"up"]
	for i in 4:
		game.restart()
		game.movement.step(directions[i], 1.0, 220.0)
		loops = 0
		key(keys[i], true)
		var seen := {}
		for frame in 90:
			await process_frame
			seen[game.character.frame] = true
		require(seen.size() == 4, "Holding %s must advance all four walk frames; saw %s" % [names[i], seen.keys()])
		require(loops >= 2, "Holding direction must loop the walk cycle")
		require(game.player.length() > 200.0, "Player actually moved")
		key(keys[i], false)
		for frame in 3:
			await process_frame
		require(game.character.animation == StringName("idle_" + names[i]), "Release stops walking and retains direction")
	# The animation stops if the player keeps pushing against a wall.
	game.restart()
	game.player = Vector2(0, game.world.bounds.end.y - 64 - 15.01)
	game.movement.step(Vector2.DOWN, 1.0, 220.0)
	key(KEY_S, true)
	for frame in 12:
		await process_frame
	require(game.character.animation == &"idle_down", "No walking in place against a wall")
	key(KEY_S, false)
	game.restart()
	var tree := Vector2i(-4, -3)
	game.player = game.resources.bounds(tree).position + Vector2(-24, 32)
	require(game.start_work(tree), "Harvest can begin")
	key(KEY_D, true)
	for frame in 3:
		await process_frame
	require(not game.working, "Moving still cancels harvesting")
	key(KEY_D, false)
	print("PASS: %d sustained-walk checks: four directions, repeated cycles, release, collision and harvest cancellation" % checks)
	quit(0)
