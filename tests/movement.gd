extends SceneTree
const Motion = preload("res://scripts/turn_motion.gd")
var checks := 0

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		quit(1)
		assert(condition, message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var directions := [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	for fps in [30, 60, 144]:
		for start in directions:
			for target in directions:
				var motion = Motion.new()
				motion.step(start, 1.0, 220.0)
				var minimum := 1.0
				for i in ceili(0.4 * fps):
					var velocity: Vector2 = motion.step(target, 1.0 / fps, 220.0)
					minimum = minf(minimum, motion.speed_factor)
					require(velocity.length() <= 220.001, "Never exceeds maximum speed")
				require(Vector2.from_angle(motion.heading).is_equal_approx(target), "Turn reaches target at %d fps" % fps)
				require(is_equal_approx(motion.speed_factor, 1.0), "Restores full speed")
				if start.dot(target) < -0.9:
					require(minimum < 0.70, "Reversals visibly slow")
				elif start.dot(target) < 0.1:
					require(minimum > 0.90 and minimum < 0.95, "90 degree turn moderate slowdown")
	var motion = Motion.new()
	motion.step(Vector2.RIGHT, 1.0, 220.0)
	var diagonal := Vector2(1, -1).normalized()
	var velocity: Vector2 = motion.step(diagonal, 0.035, 220.0)
	require(velocity.length() > 214.0, "45 degree turn barely slows")
	velocity = motion.step(diagonal, 1.0, 220.0)
	require(is_equal_approx(velocity.length(), 220.0), "Diagonal does not exceed cardinal speed")
	motion.step(Vector2.LEFT, 0.04, 220.0)
	motion.step(Vector2.DOWN, 1.0, 220.0)
	require(motion.facing() == &"down", "Interrupted turn reaches new target")
	require(motion.step(Vector2.ZERO, 0.1, 220.0) == Vector2.ZERO, "Release stops immediately")
	var frames = preload("res://scripts/survivor_frames.gd").build()
	for direction in Motion.FACINGS:
		require(frames.get_frame_count("walk_" + direction) == 4, "Four walking frames")
		require(frames.get_frame_count("idle_" + direction) == 1, "Directional idle frame")
		for frame in 4:
			var texture: AtlasTexture = frames.get_frame_texture("walk_" + direction, frame)
			require(texture.get_size() == Vector2(640, 640), "Frames share canvas and baseline")
			require(texture.region.size.x > 50 and texture.region.size.y > 150, "Nonempty full-body frame")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.move_player(Vector2.RIGHT, 0.3)
	require(game.character.animation == &"walk_right", "Movement drives right animation")
	game.move_player(Vector2.LEFT, 0.3)
	require(game.character.animation == &"walk_left", "Reversal drives left animation")
	game.move_player(Vector2.ZERO, 0.1)
	require(game.character.animation == &"idle_left", "Idle retains facing")
	game.restart()
	require(game.movement.facing() == &"down" and game.movement.speed_factor == 1.0 and game.gait.clothing.state == &"idle", "Restart resets motion, facing and resting pose")
	print("PASS: %d movement/animation checks (30, 60, 144 fps)" % checks)
	quit(0)
