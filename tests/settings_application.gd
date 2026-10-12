extends SceneTree
const Settings = preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
var skipped := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func settle() -> void:
	for i in 6: await process_frame
func native_click(button: Control) -> void:
	var point := root.get_final_transform()*button.get_global_transform_with_canvas()*(button.size/2)+Vector2(root.position)
	var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(point.x)),str(roundi(point.y))])
	for pressed in [1,0]:
		var command: PackedStringArray = args.duplicate(); command.append(str(pressed))
		require(OS.execute("python3",command) == 0,"Native click can reach settings controls after applying mode")
		await settle()
func run() -> void:
	var had_file := FileAccess.file_exists(Settings.PATH)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(Settings.PATH) if had_file else PackedByteArray()
	var app = load("res://scenes/day_zero.tscn").instantiate()
	root.add_child(app); await settle()
	app.play(); app.game.set_process(false); app.show_pause()
	for mode in [0,1,2]:
		app.menu.open_settings(); await settle()
		var panel = app.menu.settings_panel
		panel.pending["resolution"] = Vector2i(1280,720)
		panel.pending["window_mode"] = mode
		panel.pending["fps"] = 120
		panel.pending["msaa"] = 1
		panel.pending["vsync"] = false
		panel.volume_sliders["master"].value = 37
		panel.volume_sliders["music"].value = 24
		panel.volume_sliders["effects"].value = 63
		panel.hud_slider.value = mode+2
		var automatic := panel.find_child("AutomaticRun",true,false) as CheckButton
		automatic.button_pressed = true
		panel.apply_changes(); await settle()
		require(Engine.max_fps == 120 and root.msaa_2d == (Viewport.MSAA_2X if Settings.supports_msaa_2d() else Viewport.MSAA_DISABLED),"Apply changes frame limit and actual render antialiasing")
		for pair in [["Master",0.37],["Music",0.24],["Effects",0.63]]:
			var bus := AudioServer.get_bus_index(pair[0])
			require(absf(db_to_linear(AudioServer.get_bus_volume_db(bus))-pair[1]) < 0.001,"Audio sliders apply to their real buses")
		require(app.game.gameplay_settings.values.auto_run,"Running setting reaches the current game")
		require(app.game.styled_hud.quick_bar.scale.is_equal_approx(Vector2.ONE*Settings.hud_scale(mode+2)),"HUD resize applies immediately to the paused current game")
		require(root.get_visible_rect().size == Vector2(1280,720) and root.content_scale_size == Vector2i(1280,720),"Render resolution works in windowed, fullscreen and borderless modes")
		var actual := DisplayServer.window_get_mode()
		var no_manager := DisplayServer.get_name() == "X11" and OS.execute("python3",PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),"--has-wm"])) == 2
		if mode == 1 and no_manager:
			skipped += 1
			print("SKIP: native EWMH fullscreen flag requires a window manager; actual desktop coverage, render resolution and clicks are still tested")
		else:
			require(actual == [DisplayServer.WINDOW_MODE_WINDOWED,DisplayServer.WINDOW_MODE_FULLSCREEN,DisplayServer.WINDOW_MODE_WINDOWED][mode],"Actual window mode matches its selection: requested=%d actual=%d node=%d" % [mode,actual,root.mode])
		if mode == 1: require(DisplayServer.window_get_size() == DisplayServer.screen_get_size(),"Fullscreen actually covers the display")
		if mode == 2: require(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS) and DisplayServer.window_get_size() == DisplayServer.screen_get_size(),"Borderless covers the desktop without relying on window-manager maximization")
		if not Settings.supports_msaa_2d(): require(panel.smoothing.is_item_disabled(1) and panel.smoothing.is_item_disabled(2),"Unsupported MSAA options cannot pretend to apply")
		var saved := Settings.new(); saved.load_settings()
		require(saved.values.hud_size == mode+2 and saved.values.window_mode == mode and saved.values.resolution == Vector2i(1280,720) and saved.values.auto_run,"Applied settings survive reload")
		var back: Button
		for button in panel.find_children("*","Button",true,false):
			if button.text == "Volver": back = button; break
		await native_click(back)
		require(not is_instance_valid(app.menu.settings_panel),"Native click still closes settings after mode/resolution changes")
		await native_click(app.menu.play_button)
		require(not app.menu.visible and not app.game.menu_open,"Native Continue still works after applying settings")
		app.show_pause()
	# Restore preferences instead of changing the player's saved setup.
	if had_file:
		var file := FileAccess.open(Settings.PATH,FileAccess.WRITE); file.store_buffer(original); file.close()
	else: DirAccess.remove_absolute(Settings.PATH)
	print("%s: %d applied-settings checks, %d failures, %d platform-dependent checks skipped" % ["PASS" if failures == 0 else "FAIL",checks,failures,skipped])
	quit(1 if failures else 0)
