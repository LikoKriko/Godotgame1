extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func ready_frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var shadows = game.solar_lighting.shadows
	for item in [&"axe",&"pickaxe",&"sword",&"bow"]:
		game.bag.select_tool(item)
		game.equipping = false
		for direction in [0,4,8,12]:
			game.movement.heading = direction*TAU/16
			game.working = true
			game.work_duration = 1
			game.work_elapsed = 0.5
			game.full_avatar.update_pose(0)
			await ready_frame()
			await ready_frame()
			var picture: Image = shadows.mask_viewport.get_texture().get_image()
			require(picture.get_used_rect().size.y > 100,"Complete avatar reaches the colored/shadow render target")
			var source: AtlasTexture = game.full_avatar.texture
			var rgba := source.atlas.get_image().get_region(Rect2i(source.region))
			var matches := 0
			var samples := 0
			for y in range(0,192,4):
				for x in range(0,192,4):
					if rgba.get_pixel(x,y).a < 0.9: continue
					var point: Vector2 = (shadows.mask.source_transform*game.full_avatar.global_transform)*Vector2(x+0.5,y+0.5)
					var pixel := Vector2i((shadows.mask.transform*point).floor())
					if pixel.x < 0 or pixel.y < 0 or pixel.x >= 384 or pixel.y >= 384: continue
					samples += 1
					if picture.get_pixelv(pixel).a > 0.8: matches += 1
			require(samples > 15 and matches/float(samples) > 0.97,"Rendered silhouette retains the complete body/tool pixels")
	game.working = false
	game.day_cycle.hour = 0
	game.solar_lighting.update_light()
	require(not shadows.visible and shadows.colored_avatar.visible,"At night the character remains visible while its solar shadow disappears")
	print("%s: %d complete-frame rendering checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
