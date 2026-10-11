extends SceneTree
const Motion = preload("res://scripts/turn_motion.gd")
var checks := 0
var failures := 0

func require(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var frames: SpriteFrames = game.character.sprite_frames
	for start in 8:
		for offset in [-4, -2, -1, 1, 2, 4]:
			game.restart()
			var source := Vector2.from_angle(start * PI / 4)
			var target := Vector2.from_angle((start + offset) * PI / 4)
			game.movement.step(source, 1, 220)
			var name := StringName("turn_%s_%s" % [Motion.FACINGS[start], Motion.FACINGS[posmod(start + offset, 8)]])
			require(frames.has_animation(name), "Turn clip exists for angle and direction")
			require(frames.get_frame_count(name) == absi(offset) + 1 and not frames.get_animation_loop(name), "Turn passes through intermediate directions once")
			var seen := {}
			var slowest := 1.0
			for i in 22:
				game.move_player(target, 1.0 / 60)
				slowest = minf(slowest, game.movement.speed_factor)
				if game.character.animation == name:
					seen[game.character.frame] = true
				require(is_zero_approx(game.character.rotation), "Turn changes perspective without rotating sprite flat on ground")
				var texture: AtlasTexture = frames.get_frame_texture(game.character.animation, game.character.frame)
				require(is_equal_approx(texture.region.size.y * game.character.scale.y, 64.0), "Walking and turning preserve character height")
				var feet: float = game.character.position.y + 300.0 * game.character.scale.y
				require(is_equal_approx(feet, game.player.y + 17), "Feet stay anchored while turning")
			require(seen.size() >= 2, "Turn actually advances visible frames")
			require(game.character.animation == StringName("walk_" + Motion.FACINGS[posmod(start + offset, 8)]), "Completed turn resumes walking toward target")
			require(is_equal_approx(game.movement.speed_factor, 1.0), "Turn completion restores maximum speed")
			if absi(offset) == 1:
				require(slowest > 0.97 and slowest < 1, "45-degree turn barely slows")
			elif absi(offset) == 2:
				require(slowest > 0.90 and slowest < 0.96, "90-degree turn has moderate slowdown")
			else:
				require(slowest < 0.7, "180-degree turn has larger slowdown")
	game.restart()
	game.movement.step(Vector2.RIGHT, 1, 220)
	game.move_player(Vector2.LEFT, 0.05)
	game.move_player(Vector2.DOWN, 0.02)
	game.move_player(Vector2.DOWN, 0.4)
	require(game.character.animation == &"walk_down" and game.movement.speed_factor == 1, "Interrupted turn reaches new target")
	game.move_player(Vector2.ZERO, 0.01)
	require(game.character.animation == &"idle_down", "Release during movement enters idle")
	for name in frames.get_animation_names():
		require(not str(name).begins_with("harvest_") and not str(name).begins_with("mine_"), "No character weapon or tool animations")
	print("%s: %d turn checks, %d failures: 45/90/180 degrees in eight directions, slowdown, completion and interruption" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
