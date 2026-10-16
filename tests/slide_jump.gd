extends SceneTree
const Motion = preload("res://scripts/locomotion.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func run() -> void:
	for heading in [0.0,PI/2,PI,-PI+0.01]:
		for elapsed in [0.0,0.05,0.23,0.459]:
			var state := Motion.new()
			state.slide(Vector2.from_angle(heading)); state.advance(elapsed,false)
			var before: Vector2 = state.velocity(Vector2.ZERO,0.93)
			require(state.jump(0.93),"Any moment of a slide permits a jump")
			require(state.airborne() and not state.sliding() and state.from_slide,"Slide transfers into its dedicated airborne state")
			require(state.velocity(Vector2.ZERO,1).distance_to(before*0.70) < 0.0001,"Launch reduces inherited slide speed by thirty percent including modifiers")
			require(not state.jump(),"Airborne jumps cannot retrigger or stack momentum")
			state.steer_air(Vector2.from_angle(heading+PI/2),1)
			require(absf(wrapf(state.jump_heading-heading,-PI,PI)-deg_to_rad(70)) < 0.0001,"Right turn caps at seventy degrees from launch")
			state.steer_air(Vector2.from_angle(heading-PI/2),1)
			require(absf(wrapf(state.jump_heading-heading,-PI,PI)+deg_to_rad(70)) < 0.0001,"Left turn caps at seventy degrees from launch")
			require(is_equal_approx(state.velocity(Vector2.ZERO,1).length(),before.length()*0.70),"Steering preserves inherited speed")
			state.advance(Motion.JUMP_SECONDS,false)
			require(not state.airborne() and not state.from_slide and state.jump_speed == 0,"Landing clears slide inertia")
	var state := Motion.new()
	state.slide(Vector2.RIGHT); state.advance(Motion.SLIDE_SECONDS,false)
	require(state.jump() and not state.from_slide,"After a completed slide the next jump is normal")
	require(state.velocity(Vector2(70,0),1) == Vector2(70,0),"Normal jump preserves ordinary controls")
	state.advance(Motion.JUMP_SECONDS/2,false)
	require(is_equal_approx(state.height(),24),"Slide and ordinary jumps share their twenty-four-unit apex")
	print("%s: %d slide inertia checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
