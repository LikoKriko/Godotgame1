extends Node
var settings = preload("res://scripts/game_settings.gd").new()
var menu: Control
var game: Node2D
var loading_busy := false
var loading_screen: CanvasLayer
var build_thread: Thread
const Save = preload("res://scripts/save_game.gd")

func _ready() -> void:
	add_to_group("day_zero_apps")
	settings.load_settings()
	settings.apply(get_viewport())
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	menu = preload("res://scripts/day_zero_menu.gd").new()
	layer.add_child(menu)
	menu.configure(settings)
	menu.play_requested.connect(play)
	menu.new_game_requested.connect(new_game)
	menu.save_requested.connect(save_current_game)
	menu.main_menu_requested.connect(return_to_title)
	menu.set_saved_available(not Save.read_state().is_empty())
	loading_screen = preload("res://scripts/loading_screen.gd").new(); add_child(loading_screen)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func play() -> void:
	if loading_busy: return
	if not is_instance_valid(game):
		var state := Save.read_state()
		await build_game(not state.is_empty(),state.get("seed",preload("res://scripts/main.gd").WORLD_SEED))
		loading_screen.set_progress(0.9)
		if not state.is_empty() and not Save.restore(game,state,game.world):
			remove_child(game)
			game.queue_free()
			game = null
			menu.message.text = "No se pudo recuperar la partida."
			await finish_loading()
			return
		await finish_loading()
	game.menu_open = false
	menu.hide()

func new_game() -> void:
	if loading_busy: return
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	await build_game(false,preload("res://scripts/main.gd").WORLD_SEED)
	await finish_loading()
	game.menu_open = false
	menu.hide()

func build_game(restoring: bool, seed_value: int) -> void:
	loading_busy = true; loading_screen.begin(restoring)
	get_tree().root.get_node("GameCursor").set_loading_active(true)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	# Prepare shared raster masks on the render thread; the worker only builds data.
	preload("res://scripts/raised_ground.gd").prepare()
	game = preload("res://scenes/main.tscn").instantiate()
	game.gameplay_settings = settings
	var job = preload("res://scripts/world_build_job.gd").new()
	job.world = game.world; job.seed_value = seed_value
	build_thread = Thread.new()
	var error := build_thread.start(job.build)
	if error != OK: job.build()
	else:
		while build_thread.is_alive():
			loading_screen.set_progress(job.fraction()*0.7)
			await get_tree().process_frame
		build_thread.wait_to_finish()
	build_thread = null
	loading_screen.set_progress(0.75); game.world_prepared = true
	await get_tree().process_frame
	game.menu_open = true; add_child(game)
	game.menu_requested.connect(show_pause)
	game.settings_requested.connect(func(): show_pause(); menu.open_settings())
	loading_screen.set_progress(0.85)

func finish_loading() -> void:
	loading_screen.set_progress(1)
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
	loading_screen.hide(); loading_busy = false
	get_tree().root.get_node("GameCursor").set_loading_active(false)

func _exit_tree() -> void:
	if build_thread != null and build_thread.is_started(): build_thread.wait_to_finish()

func save_current_game() -> void:
	if not is_instance_valid(game): return
	var result := Save.write(game)
	menu.message.text = "Partida guardada." if result == OK else "No se pudo guardar (%s)." % error_string(result)
	if result == OK: menu.set_saved_available(true)

func show_pause() -> void:
	game.menu_open = true
	game.cancel_work()
	menu.set_resume(true)
	menu.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func return_to_title() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
		game = null
	menu.set_resume(false)
	menu.set_saved_available(not Save.read_state().is_empty())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
