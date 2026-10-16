extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(ok: bool,message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func run() -> void:
	var app = load("res://scenes/day_zero.tscn").instantiate(); root.add_child(app)
	app.new_game()
	require(app.loading_busy and app.loading_screen.visible,"A visible loading screen precedes world creation")
	require(app.loading_screen.caption.text == "Generando mundo","New worlds show the requested caption")
	var previous := 0.0
	var deadline := Time.get_ticks_msec()+15000
	while app.loading_busy and Time.get_ticks_msec() < deadline:
		var progress: float = app.loading_screen.progress.value
		require(progress >= previous and progress >= 0 and progress <= 1,"Actual build progress is monotonic and bounded")
		previous = progress
		await process_frame
	require(not app.loading_busy and is_instance_valid(app.game) and not app.loading_screen.visible,"Generation completes and reveals the world")
	require(app.loading_screen.progress.value == 1 and app.build_thread == null,"Completed jobs join their worker and finish the bar")
	if not is_instance_valid(app.game): quit(1); return
	require(app.game.world_prepared and app.game.world.platforms.size() == 4,"The generated world is reused by scene initialization")
	app.game.set_process(false)
	var snapshot: Dictionary = preload("res://scripts/save_game.gd").capture(app.game)
	require(preload("res://scripts/save_game.gd").restore(app.game,snapshot,app.game.world),"Save restoration accepts the prepared matching world")
	app.loading_screen.begin(true)
	require(app.loading_screen.caption.text == "Cargando mundo","Saved worlds show the requested loading caption")
	print("%s: %d world-loading checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
