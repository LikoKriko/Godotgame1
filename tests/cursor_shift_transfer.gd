extends "res://tests/native_menu_input.gd"
var tooltip_windows := 0
class StartupCursor:
	extends "res://scripts/cursor_overlay.gd"
	func _ready() -> void: enable_canvas_cursor()
func watch_window(node: Node) -> void:
	if node is Window and node.get_flag(Window.FLAG_NO_FOCUS): tooltip_windows += 1
func shift_click(button: Control) -> void:
	await native_pointer(button,button.size/2)
	# Exercise the native tooltip lifecycle while transferring the hovered item.
	await create_timer(1.2).timeout
	for window in root.find_children("*","Window",true,false):
		if window.get_flag(Window.FLAG_NO_FOCUS): require(not window.has_meta("day_zero_canvas_cursor"),"The visible tooltip has no custom cursor canvas")
	var screen: Vector2 = root.get_final_transform()*button.get_global_transform_with_canvas()*(button.size/2)+Vector2(root.position)
	var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(screen.x)),str(roundi(screen.y)),"1","shift"])
	require(OS.execute("python3",args) == 0,"OS Shift + click is delivered")
	await settle(); await native_pointer(button,button.size/2,0)
func run() -> void:
	node_added.connect(watch_window)
	var cursor := StartupCursor.new(); root.add_child(cursor); await settle()
	var app = load("res://scenes/day_zero.tscn").instantiate(); root.add_child(app)
	app.new_game(); app.game.set_process(false)
	root.size = Vector2i(1280,720); root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var game = app.game; game.bag.add(&"palo",2)
	game.inventory_panel.open_section(0); await settle()
	var item_uid := -1
	for item in game.bag.slots:
		if item.get("id") == &"palo": item_uid = item.uid; break
	require(item_uid > 0,"Transfer fixture has sticks")
	var window_state := [root.size,root.position,root.content_scale_size,root.content_scale_mode,root.get_final_transform()]
	for _round_index in 3:
		var location: Dictionary = game.bag.location(item_uid)
		await shift_click(game.inventory_panel.backpack_buttons[location.index])
		location = game.bag.location(item_uid)
		require(location.kind == &"quick","Shift + click moves the item to quick storage")
		await shift_click(game.styled_hud.quick_buttons[location.index])
		location = game.bag.location(item_uid)
		require(location.kind == &"bag","Shift + click returns the item to the backpack")
		require(window_state == [root.size,root.position,root.content_scale_size,root.content_scale_mode,root.get_final_transform()],"Transfers preserve window size, position and input/render transforms")
		require(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,"Canvas cursor stays active after transfer")
		await boundaries(game.inventory_panel.backpack_buttons[location.index])
		for window in root.find_children("*","Window",true,false):
			if window.get_flag(Window.FLAG_NO_FOCUS): require(not window.has_meta("day_zero_canvas_cursor"),"Tooltip windows are not modified by the cursor")
	require(tooltip_windows > 0,"The test exercised actual native tooltip windows")
	require(root.has_node("DayZeroCursor"),"Main cursor remains attached")
	print("%s: %d Shift + click/cursor/tooltip checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
