extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func capture(game) -> Image:
	for i in 2:
		await process_frame
		await RenderingServer.frame_post_draw
	return game.solar_lighting.shadows.mask_viewport.get_texture().get_image()
func difference(a: Color,b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var total_covered := 0
	for facing in [&"up",&"up_right",&"up_left"]:
		var index := preload("res://scripts/turn_motion.gd").FACINGS.find(facing)
		game.movement.heading = index*PI/4
		for item in [&"axe",&"pickaxe"]:
			game.bag.select_tool(item)
			for phase in [0.28,0.55]:
				game.working = true
				game.work_elapsed = phase*game.work_duration
				game.work_aim = game.player+Vector2.from_angle(game.movement.heading)*50
				game.hit_applied = false
				game.arm_rig.impact_material = &""
				game.animate_work_rig(phase)
				game.character.play(StringName("work_"+facing))
				game.gait.update_work_pose()
				var active: int = game.arm_rig.state["index"]
				var limb = game.arm_rig.layers[active]
				require(limb.tool_layer.z_index == -1,"Back-facing tool is placed behind the body")
				var behind: Image = await capture(game)
				limb.tool_layer.z_index = 0
				var in_front: Image = await capture(game)
				limb.tool = &""
				var absent: Image = await capture(game)
				var covered := 0
				var correct := 0
				for y in behind.get_height():
					for x in behind.get_width():
						var reference := absent.get_pixel(x,y)
						if reference.a > 0.99 and difference(reference,in_front.get_pixel(x,y)) > 0.08:
							covered += 1
							if difference(reference,behind.get_pixel(x,y)) < 0.04: correct += 1
				require(covered == 0 or correct >= covered*0.97,"Opaque head/torso cover weapon pixels during real rendered swings: %s %s" % [facing,item])
				total_covered += covered
				limb.tool = item
	require(total_covered > 100,"Test exercises actual weapon overlap with the body")
	game.working = false
	game.locomotion.reset()
	game.gait.update_work_pose()
	game.day_cycle.hour = 23
	game.solar_lighting.update_light()
	var night: Image = await capture(game)
	require(not night.is_empty() and game.solar_lighting.shadows.colored_avatar.visible,"Colored avatar remains rendered when solar shadows are disabled at night")
	print("%s: %d tool-depth checks, %d failures; %d opaque overlapping pixels: head/body occlusion, three back views, axe/pick and night" % ["PASS" if failures == 0 else "FAIL",checks,failures,total_covered])
	game.free()
	quit(0 if failures == 0 else 1)
