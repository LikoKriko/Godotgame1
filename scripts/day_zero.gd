extends Node
var settings = preload("res://scripts/game_settings.gd").new()
var menu: Control
var game: Node2D
const Save = preload("res://scripts/save_game.gd")

func _ready() -> void:
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func play() -> void:
	if not is_instance_valid(game):
		var state := Save.read_state()
		create_game()
		if not state.is_empty() and not Save.restore(game,state):
			remove_child(game)
			game.queue_free()
			game = null
			menu.message.text = "No se pudo recuperar la partida."
			return
	game.menu_open = false
	menu.hide()

func create_game() -> void:
	game = preload("res://scenes/main.tscn").instantiate()
	game.gameplay_settings = settings
	add_child(game)
	game.menu_requested.connect(show_pause)
	game.settings_requested.connect(func(): show_pause(); menu.open_settings())

func new_game() -> void:
	if is_instance_valid(game):
		remove_child(game)
		game.queue_free()
	create_game()
	game.menu_open = false
	menu.hide()

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
