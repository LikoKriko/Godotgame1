extends Node
var settings = preload("res://scripts/game_settings.gd").new()
var menu: Control
var game: Node2D

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
	menu.main_menu_requested.connect(return_to_title)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func play() -> void:
	if not is_instance_valid(game):
		game = preload("res://scenes/main.tscn").instantiate()
		add_child(game)
		game.menu_requested.connect(show_pause)
	game.menu_open = false
	menu.hide()

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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
