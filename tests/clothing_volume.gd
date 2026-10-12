extends SceneTree
const Poses = preload("res://scripts/clothing_poses.gd")
const Frames = preload("res://scripts/survivor_frames.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	require(Poses.catalogue.size()*Poses.FRAMES == 576,"Clothing has 576 explicit reference poses")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	require(game.camera.zoom.is_equal_approx(Vector2.ONE*1.95),"Default view is exactly 30 percent closer")
	for facing in 8:
		var unique := {}
		game.movement.step(Vector2.from_angle(preload("res://scripts/turn_motion.gd").FACINGS.find(Frames.DIRECTIONS[facing])*PI/4),1,220)
		for state in Poses.STATES:
			for frame in 8:
				var progress := (frame+0.5)/8.0
				game.locomotion.reset()
				game.working = state in [&"axe",&"pickaxe",&"punch"]
				game.equipping = state == &"equip"
				game.work_elapsed = progress*game.work_duration if game.working else 0
				game.equip_elapsed = progress*0.42
				game.gait.idle_clock = progress*4
				if state == &"punch": game.bag.unequip(&"hands")
				else: game.bag.select_tool(&"pickaxe" if state == &"pickaxe" else &"axe")
				if state == &"walk":
					game.character.play(StringName("walk_"+Frames.DIRECTIONS[facing]))
					game.character.set_frame_and_progress(frame/2,0.25 if frame%2 == 0 else 0.75)
					game.gait.update_pose(0)
				else:
					game.gait.update_work_pose()
				if state == &"jump":
					game.locomotion.jump()
					game.locomotion.advance(progress*game.locomotion.JUMP_SECONDS,false)
				if state == &"slide":
					game.locomotion.slide(Vector2.from_angle(game.movement.heading))
					game.locomotion.advance(progress*game.locomotion.SLIDE_SECONDS,false)
				if state == &"crouch": game.locomotion.crouch = progress
				game.gait.apply_locomotion()
				game.gait.clothing.update_pose(game,game.gait)
				require(game.gait.clothing.state == state,"Clothing chooses the actual movement/action state")
				var signature := str(game.gait.clothing.waist.polygon)
				for trouser in game.gait.clothing.trousers:
					signature += str(trouser.polygon)
					for point in trouser.polygon: require(point.is_finite(),"Clothing geometry remains finite")
				unique[signature] = true
		require(unique.size() >= 30,"Every facing has at least thirty genuinely different rendered clothing positions: %d" % unique.size())
	game.working = false
	game.equipping = false
	game.locomotion.reset()
	var shadows = game.solar_lighting.shadows
	game.solar_lighting.update_light()
	var redraws: int = shadows.prop_redraws
	for i in 120: game.solar_lighting.update_light()
	require(shadows.prop_redraws == redraws,"Unchanged sun and props do not rebuild static shadows every frame")
	var cache_size: int = game.world_view.presentation_cache.size()
	for i in 100:
		for cell in game.world.props: game.world_view.presentation(cell)
	require(game.world_view.presentation_cache.size() == cache_size,"Presentation cache stays bounded when reused")
	require(shadows.mask_viewport.size == Vector2i(384,384),"Avatar and shadow reuse one high-resolution target")
	print("%s: %d clothing/volume checks, %d failures: 576 poses, visible diversity, states, close camera and bounded caches" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free()
	quit(0 if failures == 0 else 1)
