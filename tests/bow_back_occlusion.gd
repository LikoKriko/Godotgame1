extends SceneTree
const Actor = preload("res://tools/continuous_actor.gd")
const Baker = preload("res://tools/bake_complete_sprites.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func capture(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func difference(a: Color,b: Color) -> float: return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(192,192); view.transparent_bg = true
	view.world_3d = World3D.new(); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 128
	camera.position = Vector3(0,78,200); view.add_child(camera)
	camera.look_at(Vector3(0,34,0))
	var actor := Actor.new(); view.add_child(actor); actor.camera_up = camera.global_basis.y
	var hidden := [0,0]
	var kept := [0,0]
	for state in [&"idle",&"walk",&"run",&"equip",&"action",&"crouch_walk"]:
		for direction in [10,12,14]:
			for phase in [0.0,0.28,0.5,0.85]:
				actor.build(&"bow",&"bow",state,phase,direction)
				actor.body_material.set_shader_parameter("protect_bow_arm",false)
				actor.tool.hide(); actor.show_core_only()
				var core := await capture(view)
				actor.restore_full(&"")
				actor.body_material.set_shader_parameter("body_mask",ImageTexture.create_from_image(core))
				for side in 2:
					var parameter := "debug_left_arm" if side == 0 else "debug_right_arm"
					actor.body_material.set_shader_parameter(parameter,true)
					actor.body_material.set_shader_parameter("protect_bow_arm",false)
					var raw := await capture(view)
					actor.body_material.set_shader_parameter("protect_bow_arm",true)
					var masked := await capture(view)
					var leaks := 0
					var lost := 0
					for y in 192:
						for x in 192:
							var pixel := raw.get_pixel(x,y)
							if pixel.r < 0.99 or pixel.b < 0.99 or pixel.g > 0.01: continue
							var output := masked.get_pixel(x,y)
							if core.get_pixel(x,y).a > 0.99:
								hidden[side] += 1
								if output.r > 0.99 and output.b > 0.99 and output.g < 0.01: leaks += 1
							else:
								kept[side] += 1
								if difference(pixel,output) > 0.04: lost += 1
					require(leaks == 0 and lost == 0,"Both bow arms are hidden only where the back covers them: %s/%d/%s/arm%d" % [state,direction,phase,side])
					actor.body_material.set_shader_parameter(parameter,false)
					actor.body_material.set_shader_parameter("protect_bow_arm",false)
	for side in 2: require(hidden[side] > 0 and kept[side] > 0,"Each arm has tested occlusion and visible grips")
	# Check the shipped whole frames against the torso/head mask, rather than
	# accepting authoring-only fixes that never reach the PNG used by the game.
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/complete/manifest.json"))
	for state in [&"idle",&"walk",&"run",&"equip",&"action",&"crouch_walk"]:
		var data: Dictionary = manifest.items.bow.clips[String(state)]
		var sheet := Image.load_from_file(ProjectSettings.globalize_path(data.path))
		var count := int(data.frames)
		var directions := int(data.directions)
		for direction in [10,12,14]:
			for frame in count:
				var phase := frame/float(count) if state in [&"walk",&"run",&"crouch_walk"] else (frame/float(count-1) if count > 1 else 0.0)
				if state == &"action": phase = frame/16.0 if frame <= 8 else 0.5+(frame-8)/14.0
				actor.build(&"bow",&"bow",state,phase,direction)
				actor.show_core_only()
				var core := await capture(view)
				actor.restore_full(&"")
				var baked := sheet.get_region(Rect2i(frame*192,(direction/(16/directions))*192,192,192))
				var overwritten := 0
				for y in 192:
					for x in 192:
						var pixel := core.get_pixel(x,y)
						if pixel.a > 0.99 and pixel.r > 0.58 and pixel.g > 0.30 and pixel.r > pixel.g*1.15 and difference(pixel,baked.get_pixel(x,y)) > 0.06: overwritten += 1
				require(overwritten <= 2,"Exported back retains exposed skin colors without arm or cord bleeding: %s/%d/%d (%d pixels)" % [state,direction,frame,overwritten])
	print("%s: %d bow-back checks, %d failures; hidden pixels %s, visible arm pixels %s" % ["PASS" if failures == 0 else "FAIL",checks,failures,hidden,kept])
	quit(1 if failures else 0)
