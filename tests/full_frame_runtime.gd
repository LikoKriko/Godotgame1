extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func key(code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	require(game.full_avatar.visible and game.full_avatar.texture is AtlasTexture,"Game activates one complete-frame avatar")
	game.bag.select_tool(&"pickaxe")
	var origin: Vector2 = game.player
	key(KEY_D,true)
	game._process(0.01)
	require(game.equipping and game.full_avatar.state == &"equip","Selecting a tool enters its dedicated equip clip")
	for i in 4: game._process(0.10)
	require(game.player == origin,"Walking input cannot interrupt or move during equip")
	game._process(0.10)
	game._process(0.10)
	require(not game.equipping and game.player != origin,"Movement resumes after equip finishes")
	for i in 10: game._process(0.05)
	require(game.full_avatar.state == &"walk","Sustained movement plays the walk cycle")
	var first: int = game.full_avatar.frame_index
	game._process(0.10)
	require(game.full_avatar.frame_index != first,"Walk frame changes while continuing in one direction")
	var distance_start: Vector2 = game.player
	for i in 10: game._process(0.1)
	require(absf(game.player.distance_to(distance_start)-70) < 0.1,"Base walking speed is the selected slower 70 units per second")
	key(KEY_D,false)
	game._process(0.01)
	require(game.full_avatar.state == &"stop","Releasing movement enters the six-frame stop clip")
	game._process(0.20)
	game._process(0.01)
	require(game.full_avatar.state == &"idle","Stop resolves back to the equipped ready pose")
	require(game.start_work(game.player+Vector2(200,0)),"Air swing can start")
	game._process(game.work_duration*0.25)
	require(game.full_avatar.state == &"action" and game.full_avatar.frame_index > 0,"Tool use selects complete character-and-tool action frames")
	game._process(game.work_duration)
	require(not game.working,"Action completes its recovery")
	game.bag.select_tool(&"bow")
	game._process(0.01)
	game._process(0.6)
	require(game.start_work(game.player+Vector2(200,0)),"Bow action can start")
	game._process(game.work_duration*0.51)
	var arrows := get_nodes_in_group("player_arrows")
	require(arrows.size() == 1 and arrows[0].position.distance_to(game.full_avatar.shot_origin()) < 0.01,"Arrow originates at the baked release pose")
	game.cancel_work()
	key(KEY_D,true)
	game._process(0.02)
	key(KEY_D,false)
	game._process(0.01)
	require(String(game.full_avatar.stop_clip).begins_with("stop_start_"),"Early release uses a matching partial-stride stop")
	game.restart()
	require(game.full_avatar.state == &"idle" and game.full_avatar.position.is_finite(),"Restart clears transitions and restores a valid complete pose")
	print("%s: %d full-frame runtime checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
