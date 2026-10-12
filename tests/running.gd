extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value:
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
	game.bag.unequip(&"hands")
	game._process(0.01)
	key(KEY_D,true)
	for i in 10: game._process(0.05)
	require(not game.running and not game.start_slide(),"Walking cannot initiate a slide")
	var begin: Vector2 = game.player
	game._process(0.1)
	require(absf(game.player.distance_to(begin)-7) < 0.01,"Walk retains its 70 units/s speed")
	key(KEY_SHIFT,true)
	begin = game.player
	game._process(0.1)
	require(game.running and absf(game.player.distance_to(begin)-11.2) < 0.01,"Holding Shift runs at exactly 1.6 times walk speed")
	require(game.full_avatar.state == &"run","Running uses its own full-frame animation")
	key(KEY_SHIFT,false)
	game._process(0.1)
	require(not game.running and game.full_avatar.state == &"walk","Releasing Shift restores the unchanged walking cycle")
	key(KEY_CTRL,true)
	game._process(0.16)
	require(not game.locomotion.sliding() and game.locomotion.crouch > 0.99,"Control while walking crouches")
	key(KEY_CTRL,false)
	game._process(0.16)
	key(KEY_SHIFT,true)
	game._process(0.05)
	key(KEY_CTRL,true)
	game._process(0.05)
	require(game.locomotion.sliding() and game.locomotion.crouch < 0.01,"Control while running slides without also crouching")
	key(KEY_CTRL,false)
	key(KEY_SHIFT,false)
	key(KEY_D,false)
	game._process(0.6)
	key(KEY_CTRL,true)
	game._process(0.16)
	require(game.locomotion.crouch > 0.99 and not game.locomotion.sliding(),"Control while stationary crouches")
	key(KEY_CTRL,false)
	game._process(0.16)
	game.gameplay_settings.values["auto_run"] = true
	key(KEY_D,true)
	game._process(0.2)
	require(game.running,"Automatic running does not require Shift")
	game.gameplay_settings.values["auto_run"] = false
	game._process(0.2)
	require(not game.running,"Applying automatic-run off takes effect in the current game")
	key(KEY_D,false)
	game._process(0.01)
	game.menu_open = true
	begin = game.player
	key(KEY_SHIFT,true)
	key(KEY_D,true)
	game._process(0.5)
	require(game.player == begin,"Menus prevent running and movement")
	key(KEY_D,false)
	key(KEY_SHIFT,false)
	print("%s: %d running/control checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
