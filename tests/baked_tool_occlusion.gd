extends SceneTree
const Baker = preload("res://tools/bake_complete_sprites.gd")
const Actor = preload("res://tools/continuous_actor.gd")
var failures := 0
func _initialize() -> void: call_deferred("run")
func capture(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func distance(a: Color,b: Color) -> float:
	return absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(192,192)
	view.transparent_bg = true
	view.world_3d = World3D.new()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 128
	camera.position = Vector3(0,78,200)
	view.add_child(camera)
	camera.look_at(Vector3(0,34,0))
	var actor := Actor.new()
	actor.camera_up = camera.global_basis.y
	view.add_child(actor)
	var total := 0
	var left_covered := 0
	var left_kept := 0
	for item in [&"axe",&"pickaxe",&"sword",&"bow"]:
		for direction in [0,8,10,12,14]:
			for phase in [0.0,0.28,0.5,0.65]:
				actor.build(item,item,&"action",phase,direction)
				actor.body_material.set_shader_parameter("protect_bow_arm",false)
				actor.tool_material.set_shader_parameter("protect_body",false)
				actor.tool.hide()
				var body := await capture(view)
				actor.show_core_only()
				var core := await capture(view)
				actor.restore_full(item)
				var front := await capture(view)
				actor.tool_material.set_shader_parameter("body_mask",ImageTexture.create_from_image(core))
				actor.tool_material.set_shader_parameter("protect_body",true)
				var protected := await capture(view)
				var covered := 0
				var correct := 0
				for y in 192:
					for x in 192:
						if core.get_pixel(x,y).a > 0.99 and distance(body.get_pixel(x,y),front.get_pixel(x,y)) > 0.08:
							covered += 1
							if distance(body.get_pixel(x,y),protected.get_pixel(x,y)) < 0.04: correct += 1
				if covered > 0 and correct < covered*0.97:
					failures += 1
					push_error("Body failed to cover tool: %s direction %d phase %s (%d/%d)" % [item,direction,phase,correct,covered])
				total += covered
				if item == &"bow" and direction in [10,12,14]:
					actor.tool.hide()
					actor.body_material.set_shader_parameter("debug_left_arm",true)
					var marked := await capture(view)
					actor.body_material.set_shader_parameter("body_mask",ImageTexture.create_from_image(core))
					actor.body_material.set_shader_parameter("protect_bow_arm",true)
					var hidden := await capture(view)
					for y in 192:
						for x in 192:
							var paint := marked.get_pixel(x,y)
							if paint.r < 0.99 or paint.b < 0.99 or paint.g > 0.01: continue
							var remains := hidden.get_pixel(x,y)
							if core.get_pixel(x,y).a > 0.99:
								left_covered += 1
								if remains.r > 0.99 and remains.b > 0.99 and remains.g < 0.01: failures += 1
							else:
								left_kept += 1
								if distance(paint,remains) > 0.04: failures += 1
					actor.body_material.set_shader_parameter("debug_left_arm",false)
					actor.body_material.set_shader_parameter("protect_bow_arm",false)
	if left_covered == 0 or left_kept == 0:
		failures += 1
		push_error("Bow test must cover the left arm inside and outside the torso")
	for direction in [0,8]:
		actor.build(&"bow",&"bow",&"action",0.4,direction)
		var basis := Basis(Vector3.UP,PI/2-direction*TAU/16)
		var cord: Vector3 = basis*((actor.bow_ends[0]+actor.bow_ends[1])/2-actor.last_pose["grip"])
		if (direction == 0 and cord.x >= 0) or (direction == 8 and cord.x <= 0):
			failures += 1
			push_error("Bowstring must face the archer, not the target")
	actor.build(&"",&"",&"idle",0,0)
	var rest_head: Vector3 = actor.head_center
	for phase in 12:
		actor.build(&"",&"",&"walk",phase/12.0,0)
		if absf(actor.head_center.y-rest_head.y) > 1.3: failures += 1
	if actor.get_children().filter(func(node): return node is Sprite3D).size() != 1:
		failures += 1
		push_error("Only the tool may remain a Sprite3D: head and body must share a mesh")
	if total < 50:
		failures += 1
		push_error("Occlusion test must exercise actual overlapping pixels")
	print("%s: 80 authoring poses, %d occluded tool pixels, %d failures; bow arm, bowstring and integrated head verified" % ["PASS" if failures == 0 else "FAIL",total,failures])
	quit(1 if failures else 0)
