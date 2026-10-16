extends SceneTree
## Run with a graphical display; compares rendered poses without writing images.
const Aim = preload("res://tests/aim_fixture.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run_checks")

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func snapshot(game) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var center: Vector2 = game.get_viewport().get_canvas_transform()*game.player
	return root.get_texture().get_image().get_region(Rect2i(Vector2i(center)-Vector2i(90,100),Vector2i(180,140)))

func changed(a: Image, b: Image) -> int:
	var count := 0
	for y in a.get_height():
		for x in a.get_width():
			if a.get_pixel(x,y) != b.get_pixel(x,y):
				count += 1
	return count

func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	require(root.get_texture().get_image().get_size() == Vector2i(1920,1080),"Game renders at 1920x1080")
	var sapling: Vector2i = game.world.saplings.keys()[0]
	for fixture in [[sapling,&""],[Vector2i(-4,-3),&"axe"],[Vector2i(3,-4),&"pickaxe"]]:
		var aim: Vector2 = Aim.approach(game,fixture[0],fixture[1])
		game.camera.force_update_scroll()
		game.start_work(aim)
		var rest: Image = await snapshot(game)
		game.advance_work(game.work_duration*0.15)
		var windup: Image = await snapshot(game)
		game.advance_work(game.work_duration*0.35)
		var contact: Image = await snapshot(game)
		require(changed(rest,windup) > 20,"Wind-up visibly changes the articulated pose: %s" % fixture[1])
		require(changed(windup,contact) > 100,"Strike visibly extends hands/tool toward the cursor: %s" % fixture[1])
		require(game.world_view.impulses.has(fixture[0]),"Rendered strike lands on the intended surface")
		var point: Vector2 = game.get_viewport().get_canvas_transform()*aim
		Input.warp_mouse(point)
		await process_frame
		await RenderingServer.frame_post_draw
		require(root.get_mouse_position().distance_to(point) < 2,"Cursor follows mouse in screen coordinates")
		var dot: Color = root.get_texture().get_image().get_pixelv(Vector2i(point))
		require(dot.r > 0.8 and dot.g > 0.8 and dot.b > 0.65,"Small cursor dot renders at the mouse position")
		require(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,"Game uses a dot instead of the system cursor")
		game.advance_work(game.work_duration)
		game.world_view.update_trees(game.player,0.3)
	game.inventory_panel.show()
	await process_frame
	await RenderingServer.frame_post_draw
	require(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"Inventory restores the ordinary pointer")
	game.inventory_panel.hide()
	print("%s: %d graphical checks, %d failures: 1080p, fist/axe/pickaxe animation, impact and cursor" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
