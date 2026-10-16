extends "res://tests/native_menu_input.gd"
const Settings = preload("res://scripts/game_settings.gd")
func run() -> void:
	var had_settings := FileAccess.file_exists(Settings.PATH)
	var original := FileAccess.get_file_as_bytes(Settings.PATH) if had_settings else PackedByteArray()
	root.get_node("GameCursor").enable_canvas_cursor(); await settle()
	var app = load("res://scenes/day_zero.tscn").instantiate()
	app.settings.resolution_locked = true
	root.add_child(app); await settle()
	var initial_resolution: Vector2i = app.settings.values.resolution
	var geometry := [root.size,root.position,root.content_scale_size,root.get_final_transform()]
	app.menu.open_settings(); await settle()
	var panel = app.menu.settings_panel
	panel.find_children("*","TabContainer",true,false)[0].current_tab = 1; await settle()
	require(panel.resolution.disabled,"Windows resolution selector is disabled")
	await click(panel.resolution)
	require(not panel.resolution.get_popup().visible,"Click cannot open the locked resolution selector")
	panel.pending.resolution = Vector2i(2560,1440); panel.pending.fps = 144
	panel.apply_changes(); await settle()
	require(app.settings.values.resolution == initial_resolution,"Apply rejects a stale pending resolution")
	require(Engine.max_fps == 144,"FPS remains configurable")
	require(geometry == [root.size,root.position,root.content_scale_size,root.get_final_transform()],"Apply preserves the window and input transform")
	app.settings.values.resolution = Vector2i(1280,720) if initial_resolution != Vector2i(1280,720) else Vector2i(1600,900)
	app.settings.apply(root); await settle()
	require(app.settings.values.resolution == initial_resolution,"The settings model also rejects direct resolution changes")
	require(geometry == [root.size,root.position,root.content_scale_size,root.get_final_transform()],"Direct apply cannot resize the viewport")
	await boundaries(panel.frame_limit)
	require(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN,"Canvas cursor remains active")
	if had_settings:
		var file := FileAccess.open(Settings.PATH,FileAccess.WRITE); file.store_buffer(original)
	else: DirAccess.remove_absolute(Settings.PATH)
	print("%s: %d resolution-lock/cursor checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
