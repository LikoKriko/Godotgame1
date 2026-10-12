extends SceneTree
var loops := 0
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		failures += 1

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func walk_start(game, direction: Vector2) -> Vector2:
	for y in range(-640,641,64):
		for x in range(-1024,1025,64):
			var start := Vector2(x,y)
			var clear := true
			for distance in range(0,401,8):
				if not game.world.walkable(start+direction*distance):
					clear = false
					break
			if clear:
				return start
	push_error("No clear walk corridor for %s" % direction)
	return Vector2.ZERO

func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.character.animation_looped.connect(func(): loops += 1)
	var directions := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2(1, 1).normalized(), Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(), Vector2(-1, 1).normalized()]
	var keys := [[KEY_S], [KEY_A], [KEY_D], [KEY_W], [KEY_S, KEY_D], [KEY_W, KEY_D], [KEY_W, KEY_A], [KEY_S, KEY_A]]
	var names := [&"down", &"left", &"right", &"up", &"down_right", &"up_right", &"up_left", &"down_left"]
	for i in 8:
		game.restart()
		var start := walk_start(game, directions[i])
		game.player = start
		game.camera.position = start
		game.movement.step(directions[i], 1.0, 220.0)
		loops = 0
		for code in keys[i]:
			key(code, true)
		var seen := {}
		for frame in 90:
			await process_frame
			seen[game.character.frame] = true
		require(seen.size() == 4, "Holding %s must advance all four walk frames; saw %s" % [names[i], seen.keys()])
		require(loops >= 2, "Holding direction must loop the walk cycle")
		require(game.player.distance_to(start) > 200.0, "Player actually moved")
		for code in keys[i]:
			key(code, false)
		for frame in 3:
			await process_frame
		require(game.character.animation in [StringName("idle_"+names[i]),StringName("work_"+names[i])] and not game.working, "Release stops walking and retains direction")
	# The animation stops if the player keeps pushing against a wall.
	game.restart()
	game.player = Vector2(0, game.world.bounds.end.y - 64 - 15.01)
	game.movement.step(Vector2.DOWN, 1.0, 220.0)
	key(KEY_S, true)
	for frame in 12:
		await process_frame
	require(game.character.animation in [&"idle_down",&"work_down"] and not game.working, "No walking in place against a wall")
	key(KEY_S, false)
	game.restart()
	var tree := Vector2i(-4, -3)
	game.player = game.resources.bounds(tree).position + Vector2(-24, 32)
	require(game.start_work(game.resources.bounds(tree).get_center()), "Harvest can begin")
	key(KEY_D, true)
	for frame in 3:
		await process_frame
	require(not game.working, "Moving still cancels harvesting")
	key(KEY_D, false)
	print("%s: %d sustained-walk checks: eight directions, repeated cycles, release, collision and harvest cancellation" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
