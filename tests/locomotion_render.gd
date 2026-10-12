extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func changed(a: Image,b: Image) -> int:
	var count := 0
	for y in range(a.get_height()/2-160,a.get_height()/2+80):
		for x in range(a.get_width()/2-120,a.get_width()/2+120):
			var diff := a.get_pixel(x,y)-b.get_pixel(x,y)
			if absf(diff.r)+absf(diff.g)+absf(diff.b) > 0.08: count += 1
	return count
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.camera.zoom = Vector2.ONE*3
	game.bag.unequip(&"hands")
	game._process(0.01)
	game.camera.force_update_scroll()
	var idle: Image = await capture()
	var idle_head: float = game.gait.head.position.y
	key(KEY_CTRL,true)
	await process_frame
	game._process(0.16)
	require(game.locomotion.crouch == 1,"Physical Ctrl key enters crouch")
	require(game.gait.head.position.y > idle_head+5,"Crouch visibly lowers the character")
	var crouched: Image = await capture()
	require(changed(idle,crouched) > 100,"Crouch changes the rendered pose")
	key(KEY_CTRL,false)
	await process_frame
	game._process(0.16)
	key(KEY_SPACE,true)
	await process_frame
	key(KEY_SPACE,false)
	require(game.locomotion.airborne() and not game.working,"Space triggers jump instead of an attack")
	game._process(0.33)
	var jumping: Image = await capture()
	require(changed(idle,jumping) > 100 and game.gait.head.position.y < idle_head-20,"Jump raises the visible character")
	game._process(0.4)
	key(KEY_D,true)
	await process_frame
	game._process(0.02)
	key(KEY_SHIFT,true)
	game._process(0.02)
	key(KEY_CTRL,true)
	await process_frame
	key(KEY_CTRL,false)
	key(KEY_SHIFT,false)
	key(KEY_D,false)
	require(game.locomotion.sliding(),"Control while running triggers a slide")
	game._process(0.15)
	var sliding: Image = await capture()
	require(changed(idle,sliding) > 100 and absf(game.gait.torso.rotation) > 0.2,"Slide renders a leaning, flexed pose")
	require(game.arm_rig.visible,"Slide retains the character's arms")
	game._process(0.5)
	require(not game.locomotion.airborne() and not game.locomotion.sliding(),"Movement states return to rest")
	print("%s: %d locomotion-render checks, %d failures: physical Ctrl/Space/Shift, visible poses and recovery" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free()
	quit(0 if failures == 0 else 1)
