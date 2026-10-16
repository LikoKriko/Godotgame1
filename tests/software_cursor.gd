extends "res://tests/native_menu_input.gd"
const Overlay = preload("res://scripts/cursor_overlay.gd")
class StartupCursor:
	extends "res://scripts/cursor_overlay.gd"
	func _ready() -> void:
		enable_canvas_cursor()
func run() -> void:
	require(not Overlay.use_native_cursor("Windows","Windows"),"Windows uses the GUI-coordinate cursor")
	require(Overlay.use_native_cursor("Linux","X11"),"Linux retains its native cursor")
	# Exercise the Windows startup path from _ready while the parent is busy.
	var startup_cursor := StartupCursor.new(); root.add_child(startup_cursor)
	await settle()
	require(root.has_node("DayZeroCursor"),"Windows startup creates the cursor after the root finishes adding children")
	require(root.get_node("DayZeroCursor").get_child_count() == 1,"The actual cursor is attached, not only its installation marker")
	var app = load("res://scenes/day_zero.tscn").instantiate(); root.add_child(app)
	for mode in [Window.CONTENT_SCALE_MODE_VIEWPORT,Window.CONTENT_SCALE_MODE_CANVAS_ITEMS]:
		root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(1920,1080)
		root.content_scale_mode = mode; await settle()
		await boundaries(app.menu.play_button); await boundaries(app.menu.settings_button)
		require(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,"Only the canvas cursor is visible")
	app.menu.set_saved_available(true); await click(app.menu.play_button); await settle()
	var popup: Control = app.menu.confirmation
	require(popup.visible and popup.get_window() == root,"New-game confirmation stays in the game window")
	await click(popup.get_cancel_button())
	require(not popup.visible,"The in-game confirmation cancels with the same pointer coordinates")
	popup.popup_centered(); await settle(); await click(popup.get_ok_button())
	require(is_instance_valid(app.game) and not app.menu.visible,"Confirming the in-game panel starts the new game")
	app.game.set_process(false)
	app.game.inventory_panel.open_section(0); await settle()
	await boundaries(app.game.inventory_panel.backpack_buttons[0])
	print("%s: %d software cursor/menu/popup checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
