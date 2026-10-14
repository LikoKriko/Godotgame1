extends "res://tests/native_menu_input.gd"
func visible_cursor_at(point: Vector2) -> void:
	await RenderingServer.frame_post_draw
	var before := root.get_texture().get_image()
	var cursors: Array = []
	for layer in root.find_children("DayZeroCursor","CanvasLayer",true,false):
		var drawing: Control = layer.get_child(0)
		if drawing.visible: cursors.append(drawing); drawing.hide()
	await process_frame; await RenderingServer.frame_post_draw
	var after := root.get_texture().get_image()
	for drawing in cursors: drawing.show()
	var pixel := Vector2i(point)
	var changed := 0
	for y in range(pixel.y-12,pixel.y+12):
		for x in range(pixel.x-12,pixel.x+12):
			if x < 0 or y < 0 or x >= before.get_width() or y >= before.get_height(): continue
			var a := before.get_pixel(x,y); var b := after.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.02: changed += 1
	require(changed > 10,"The cursor is actually rendered at the click point, including over dropdowns")
func run() -> void:
	var path: String = preload("res://scripts/game_settings.gd").PATH
	var had_settings := FileAccess.file_exists(path)
	var original := FileAccess.get_file_as_bytes(path) if had_settings else PackedByteArray()
	root.get_node("GameCursor").enable_canvas_cursor(); await settle()
	var app = load("res://scenes/day_zero.tscn").instantiate(); root.add_child(app); await settle()
	app.menu.set_saved_available(true); await click(app.menu.play_button)
	require(app.menu.confirmation.visible and app.menu.confirmation.get_window() == root,"New game opens an in-game panel")
	await click(app.menu.confirmation.get_cancel_button())
	require(not app.menu.confirmation.visible,"Cancel closes only the confirmation")
	app.menu.open_settings(); await settle()
	var panel = app.menu.settings_panel
	panel.find_children("*","TabContainer",true,false)[0].current_tab = 1; await settle()
	for selector in [panel.frame_limit,panel.resolution,panel.mode,panel.smoothing]:
		await click(selector)
		var popup: PopupMenu = selector.get_popup()
		require(popup.visible and popup.is_embedded(),"Every graphics selector displays its list inside the game")
		require(popup.size.x > 0 and popup.size.y > 0 and popup.get_item_count() > 0,"The option list has visible dimensions and entries")
		var top := popup.get_theme_stylebox("panel").get_content_margin(SIDE_TOP)
		var row_height := popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size"))+popup.get_theme_constant("v_separation")
		var local := Vector2(popup.size.x/2.0,top+row_height/2)
		var screen: Vector2 = root.get_final_transform()*(Vector2(popup.position)+local)+Vector2(root.position)
		var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(screen.x)),str(roundi(screen.y))])
		require(OS.execute("python3",args) == 0,"Native pointer hovers the visible list")
		await settle(); await visible_cursor_at(Vector2(popup.position)+local)
		for pressed in [1,0]:
			var command := args.duplicate(); command.append(str(pressed))
			require(OS.execute("python3",command) == 0,"Native click reaches the embedded choice")
			await settle()
		require(not popup.visible and selector.selected == 0,"Click selects the first option and closes its list")
	for resolution in [Vector2i(1280,720),Vector2i(1600,900)]:
		panel.pending.resolution = resolution; panel.pending.window_mode = 0
		panel.apply_changes(); await settle()
		await boundaries(panel.frame_limit); await boundaries(panel.resolution)
		await visible_cursor_at(root.get_mouse_position())
		require(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,"Applying graphics keeps the canvas cursor")
		var geometry := [root.size,root.position,root.content_scale_size,root.get_final_transform()]
		panel.pending.fps = 120; panel.apply_changes(); await settle()
		require(Engine.max_fps == 120,"FPS changes apply")
		require(geometry == [root.size,root.position,root.content_scale_size,root.get_final_transform()],"Changing only FPS does not resize or move the window")
		await boundaries(panel.frame_limit)
	if had_settings:
		var file := FileAccess.open(path,FileAccess.WRITE); file.store_buffer(original)
	else: DirAccess.remove_absolute(path)
	print("%s: %d settings/cursor/dropdown checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
