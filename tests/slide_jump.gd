extends SceneTree
const Motion = preload("res://scripts/locomotion.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func distance(enhanced: bool) -> float:
	var state := Motion.new()
	if enhanced: state.slide(Vector2.RIGHT); state.advance(Motion.SLIDE_SECONDS/2,false)
	state.jump()
	var travelled := 0.0
	for step in 66:
		travelled += state.velocity(Vector2(70,0),1).length()*0.01
		state.advance(0.01,false)
	return travelled
func run() -> void:
	var state := Motion.new()
	require(state.slide(Vector2.RIGHT),"Running slide starts")
	state.advance(0.229,false)
	require(not state.slide_jump_window() and not state.jump() and state.sliding(),"First half cannot be cancelled with a jump")
	state.advance(0.001,false)
	require(state.slide_jump_window() and state.jump(),"Window opens exactly at half duration")
	require(state.airborne() and not state.sliding() and state.jump_multiplier == 1.15,"Window jump cancels slide and gains fifteen percent distance")
	require(not state.jump(),"Holding or repeating jump cannot stack the advantage in the air")
	state.advance(Motion.JUMP_SECONDS/2,false)
	require(is_equal_approx(state.height(),24),"Boosted jump keeps the normal height")
	state.advance(Motion.JUMP_SECONDS/2,false)
	require(not state.airborne() and state.jump_multiplier == 1,"Landing clears the bonus")
	require(state.jump() and state.jump_multiplier == 1,"Following normal jump cannot inherit the bonus")
	state.reset(); state.slide(Vector2.LEFT); state.advance(0.459,false)
	require(state.jump() and state.jump_multiplier == 1.15,"Window remains available near the end of the slide")
	state.reset(); state.slide(Vector2.LEFT); state.advance(0.46,false)
	require(not state.slide_jump_window() and state.jump() and state.jump_multiplier == 1,"After slide end jump is normal")
	require(absf(distance(true)/distance(false)-1.15) < 0.001,"Full jump travels precisely fifteen percent farther under the same input")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game); game.set_process(false)
	game.running = true
	game.locomotion.slide(Vector2.RIGHT)
	game.locomotion.advance(0.23,false)
	require(game.start_jump() and game.locomotion.jump_multiplier == 1.15,"Game jump command accepts the slide window")
	game.inventory_panel.open_section(0)
	require(not game.start_jump(),"Inventory prevents jump input")
	game.inventory_panel.hide()
	game.locomotion.reset(); game.progression.health = 0
	require(not game.start_jump(),"Zero health prevents jumping")
	print("%s: %d slide-jump checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
