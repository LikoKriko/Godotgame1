extends SceneTree
const Motion = preload("res://scripts/action_motion.gd")
const Rig = preload("res://scripts/arm_rig.gd")
const Aim = preload("res://tests/aim_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	require(Motion.inertia(&"pickaxe") > Motion.inertia(&"axe") and Motion.DURATION[&"pickaxe"] > Motion.DURATION[&"axe"],"Heavier pick has greater inertia and a slower cycle")
	var rock_peak := 0.0
	var wood_peak := 0.0
	for step in 101:
		var phase := 0.5+step*0.005
		rock_peak = maxf(rock_peak,absf(Motion.rebound(phase,&"axe",&"piedra")))
		wood_peak = maxf(wood_peak,absf(Motion.rebound(phase,&"axe",&"madera")))
		require(Motion.rebound(phase,&"axe",&"") == 0,"Air has no collision rebound")
	require(rock_peak > wood_peak*1.6 and wood_peak > 0.01,"Stone has stronger recoil than wood")
	require(Motion.rebound(0.5,&"axe",&"piedra") == 0 and Motion.rebound(1,&"axe",&"piedra") == 0,"Contact and recovery endpoints remain exact")
	for x in range(-18,19,2):
		for y in range(-18,19,2):
			var pose := Rig.solve(Vector2.ZERO,Vector2(x,y),1)
			var distance := sqrt(pose["hand"].length_squared()+pow(pose["hand_depth"],2))
			var angle := acos(clampf((distance*distance-Rig.UPPER*Rig.UPPER-Rig.FOREARM*Rig.FOREARM)/(2*Rig.UPPER*Rig.FOREARM),-1,1))
			require(rad_to_deg(angle) <= 130.001,"Elbow respects the verified Arm26 130-degree limit")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var tree := Vector2i(-4,-3)
	var aim := Aim.approach(game,tree,&"axe")
	game.start_work(aim)
	game.advance_work(game.work_duration*0.55)
	require(game.gait.working_pose and game.gait.visible,"Torso and planted legs participate during tool use")
	var body_transform := Motion.torso_transform(game.player,game.movement.facing(),0.55,&"axe",game.arm_rig.impact_material)
	for i in 2:
		var expected: Vector2 = body_transform*(game.player+Rig.ANCHORS[game.movement.facing()][i])
		require(game.arm_rig.layers[i].to_global(game.arm_rig.layers[i].shoulder).distance_to(expected) < 0.01,"Rotating torso keeps shoulders attached")
	var locked: Vector2 = game.work_contact_aim
	var facing: StringName = game.movement.facing()
	game.advance_work(game.work_duration*0.1,game.player-Vector2(80,0))
	require(game.work_contact_aim == locked and game.movement.facing() == facing,"Post-impact inertia retains its direction when the pointer changes")
	game.advance_work(game.work_duration)
	game.bag.unequip(&"hands")
	game.movement.step(Vector2.RIGHT,1,220)
	game.character.play(&"walk_right")
	game.gait.update_pose(0.03)
	require(game.gait.start_elapsed < game.gait.START_SECONDS,"Walking introduces stride amplitude gradually")
	var phase: float = game.gait.phase
	game.movement.step(Vector2.DOWN,0.02,220)
	game.character.play(game.movement.turn_animation())
	game.gait.update_pose(0.02)
	require(game.gait.active() and game.gait.phase > phase,"Turning preserves the ongoing step cycle")
	game.gait.cancel()
	game.bag.select_tool(&"axe")
	game.movement.step(Vector2.RIGHT,1,220)
	game.character.play(&"walk_right")
	game.gait.update_pose(0.15)
	game.character.play(&"idle_right")
	game.gait.update_pose(0.09)
	require(game.gait.stopping and game.character.animation == &"work_right","Stopping with an axe uses the body without duplicate original arms")
	require(game.arm_rig.modulate.a == 1 and game.original_head.modulate.a > 0 and game.original_head.modulate.a < 1,"Two-handed grip stays visible while the original head fades into rest")
	game.gait.update_pose(0.10)
	require(not game.gait.active() and game.original_head.modulate.a == 1,"Completed stop restores normal head opacity")
	print("%s: %d motion-polish checks, %d failures: anatomy, inertia, recoil, torso, contact lock, starts and turns" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	game.free()
	quit(0 if failures == 0 else 1)
