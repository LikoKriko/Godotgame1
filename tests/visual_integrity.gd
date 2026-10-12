extends SceneTree
const Rig = preload("res://scripts/arm_rig.gd")
const Frames = preload("res://scripts/survivor_frames.gd")
const Regions = preload("res://assets/characters/survivor_regions.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.camera.zoom = Vector2.ONE*3
	game.day_cycle.hour = 12
	game.solar_lighting.update_light()
	for cell in game.world.props:
		var texture: AtlasTexture = game.world_view.presentation(cell)["texture"]
		var isolated: Texture2D = game.solar_lighting.shadows.standalone(texture)
		require(isolated.get_size() == texture.region.size,"Prop shadow must isolate only the selected atlas region")
		var expected: Image = texture.atlas.get_image().get_region(Rect2i(texture.region))
		require(isolated.get_image().get_data() == expected.get_data(),"Prop shadow pixels must match exactly one tree/rock silhouette")
	require(game.arm_rig.get_index() > game.gait.get_index(),"Near arms are rendered after the torso")
	for facing in [&"right",&"left"]:
		var index := Frames.DIRECTIONS.find(facing)
		var region: Array = Regions.IDLE[index]
		var uv_bounds := Rect2(region[0],region[1],region[2],region[3])
		game.movement.step(Vector2.RIGHT if facing == &"right" else Vector2.LEFT,1,220)
		for item in [&"axe",&"pickaxe"]:
			game.bag.select_tool(item)
			for walking in [false,true]:
				if walking:
					game.character.play(StringName("walk_"+facing))
					game.character.set_frame_and_progress(1,0)
					game.gait.update_pose(0)
				else:
					game.arm_rig.ready_pose(game.player,facing,item)
					game.gait.update_work_pose()
				for limb in game.arm_rig.layers:
					for pixel in limb.upper.uv+limb.lower.uv:
						require(uv_bounds.has_point(pixel),"Lateral arms sample lateral skin, never front-facing texture")
				var with_arms: Image = await capture()
				game.arm_rig.hide()
				var without_arms: Image = await capture()
				var changed := 0
				for y in range(with_arms.get_height()/2-160,with_arms.get_height()/2+80):
					for x in range(with_arms.get_width()/2-110,with_arms.get_width()/2+110):
						var diff := with_arms.get_pixel(x,y)-without_arms.get_pixel(x,y)
						if absf(diff.r)+absf(diff.g)+absf(diff.b) > 0.06:
							changed += 1
				require(changed > 50,"Both idle and walking lateral grips must visibly render arms: %s %s %s" % [facing,item,walking])
				game.arm_rig.show()
				for limb in 2:
					var source := preload("res://scripts/character_parts.gd").leg(index,limb)
					var factor: float = 64.0/region[3]
					var expected_hip := Vector2((source["hip"].x-region[4])*factor,-47+(source["hip"].y-region[1])*factor+game.gait.bob)
					require(game.gait.legs.joints[limb]["hip"].is_equal_approx(expected_hip),"Thighs remain anchored at their native pelvis positions")
					require(game.gait.legs.thighs[limb].texture == Frames.BODY_SHEET,"Moving thigh includes the original shorts without baked arm pixels")
	print("%s: %d visual-integrity checks, %d failures: isolated prop shadows, native skin, visible side grips, hips and shorts" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free()
	quit(0 if failures == 0 else 1)
