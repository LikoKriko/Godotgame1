extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.bag.unequip(&"hands")
	for facing in preload("res://scripts/turn_motion.gd").FACINGS:
		var heading: int = preload("res://scripts/turn_motion.gd").FACINGS.find(facing)
		game.movement.step(Vector2.from_angle(heading*PI/4),1,220)
		game.character.play("walk_"+facing)
		var scale := Vector2.ZERO
		var texture: Texture2D
		var offsets := []
		for frame in 4:
			game.character.set_frame_and_progress(frame,0)
			game.gait.update_pose(0)
			if frame == 0:
				scale = game.gait.head.scale
				texture = game.gait.head.texture
			require(game.gait.head.scale == scale and game.gait.head.texture == texture,"Original head texture and scale remain fixed throughout each direction")
			offsets.append(game.gait.legs.joints[0]["ankle"]-game.gait.legs.joints[1]["ankle"])
			for joint in game.gait.legs.joints:
				require(is_equal_approx(sqrt(joint["hip"].distance_squared_to(joint["knee"])+pow(joint["depth"],2)),game.gait.legs.UPPER),"Walking thighs preserve physical length")
				require(is_equal_approx(sqrt(joint["knee"].distance_squared_to(joint["ankle"])+pow(joint["depth"],2)),game.gait.legs.LOWER),"Walking shins preserve physical length")
			if frame == 1:
				require(game.gait.legs.joints[0]["lift"] < 0.001 and game.gait.legs.joints[1]["lift"] > 4.0,"First passing pose lifts one foot while the other remains planted")
			elif frame == 3:
				require(game.gait.legs.joints[1]["lift"] < 0.001 and game.gait.legs.joints[0]["lift"] > 4.0,"Second passing pose exchanges the planted and moving leg")
		if facing in [&"right",&"left"]:
			require(offsets[0].x*offsets[2].x < 0 and absf(offsets[0].x) > 10,"Side walk visibly swaps front/back feet")
		game.character.play("idle_"+facing)
		game.gait.update_pose(0.06)
		require(game.gait.stopping and game.gait.visible and game.character.modulate.a > 0 and game.character.modulate.a < 1,"Releasing movement blends smoothly toward idle")
		game.gait.update_pose(0.2)
		require(not game.gait.visible and game.character.visible and game.character.modulate == Color.WHITE,"Stop transition completes at the original idle pose")
	print("%s: %d articulated-walk checks, %d failures: stable head, alternating strides, joints and stop transition" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
