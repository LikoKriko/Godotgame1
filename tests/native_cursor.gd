extends "res://tests/native_menu_input.gd"
func cursor_art():
	var output := []
	require(OS.execute("python3",PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),"--cursor-art"]),output) == 0,"The OS exposes the active cursor image")
	require(output[0].strip_edges() == "22 24 11 12","The native cursor has the uploaded image dimensions and exact central hotspot")
	require(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"The game uses the native cursor instead of a hidden OS pointer")
func run():
	root.size = Vector2i(1280,720); root.position = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_factor = 1.5
	var app = load("res://scenes/day_zero.tscn").instantiate(); root.add_child(app); await settle()
	await native_pointer(app.menu.play_button,app.menu.play_button.size/2)
	cursor_art()
	await app.new_game(); app.game.set_process(false); app.game.world_view.hide()
	app.game.inventory_panel.open_section(0); await settle()
	var button: Control = app.game.inventory_panel.backpack_buttons[0]
	await native_pointer(button,Vector2(3,3))
	await create_timer(1.2).timeout
	cursor_art()
	await native_pointer(button,button.size-Vector2(3,3))
	require(root.gui_get_hovered_control() == button,"A tooltip cannot intercept movement over the inventory slot")
	await boundaries(button)
	print("%s: %d native cursor/tooltip checks, %d failures" % ["PASS" if not failures else "FAIL",checks,failures]); quit(1 if failures else 0)
