extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(value: bool,message: String):
	checks += 1
	if not value: failures += 1; push_error(message)
func settle():
	for i in 3: await process_frame
func pointer(control, local: Vector2, pressed: int = -1):
	var transform: Transform2D = control.get_global_transform_with_canvas() if control is Control else Transform2D.IDENTITY
	var p: Vector2 = root.get_final_transform()*transform*local+Vector2(root.position)
	var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(p.x)),str(roundi(p.y))])
	if pressed >= 0: args.append(str(pressed))
	require(OS.execute("python3",args) == 0,"Native drag event delivered")
	await settle()
func drag(from: Control,to: Control):
	await pointer(from,from.size/2,1)
	var begin: Vector2 = root.get_final_transform()*from.get_global_transform_with_canvas()*(from.size/2)
	var end: Vector2 = root.get_final_transform()*to.get_global_transform_with_canvas()*(to.size/2)
	for i in range(1,9):
		var p := begin.lerp(end,i/8.0)
		await pointer(root,root.get_final_transform().affine_inverse()*p)
	await pointer(to,to.size/2,0)
func shift_click(control: Control):
	await pointer(control,control.size/2)
	for pressed in [true,false]:
		var e := InputEventMouseButton.new()
		e.position = root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)
		e.global_position = e.position; e.button_index = MOUSE_BUTTON_LEFT; e.pressed = pressed; e.shift_pressed = true
		Input.parse_input_event(e); Input.flush_buffered_events(); await settle()
func run():
	if DisplayServer.get_name() != "X11": quit(1); return
	var app = load("res://scenes/day_zero.tscn").instantiate()
	root.add_child(app); await app.new_game()
	root.position = Vector2i.ZERO
	var game = app.game; game.set_process(false)
	game.inventory_panel.open_section(0); await settle()
	var ui = game.inventory_panel
	var quick = game.styled_hud.quick_buttons
	var uid: int = game.bag.slots[0].uid
	await drag(ui.backpack_buttons[0],quick[0])
	require(game.bag.slots[0].is_empty() and game.bag.quick_slots[0].get("uid") == uid,"Native drag vacates backpack and lands in visible quick bar above inventory veil")
	await drag(quick[0],ui.backpack_buttons[10])
	require(game.bag.quick_slots[0].is_empty() and game.bag.slots[10].get("uid") == uid,"Native drag returns the same instance")
	var bow_uid: int = game.bag.slots[1].uid
	await drag(ui.backpack_buttons[1],ui.gear_buttons[&"hands"])
	require(game.bag.slots[1].get("uid") == bow_uid and game.bag.equipment[&"hands"].is_empty(),"Glove slot rejects weapons without moving either item")
	await shift_click(ui.backpack_buttons[10])
	require(game.bag.slots[10].is_empty() and game.bag.quick_slots[0].get("uid") == uid,"Shift click moves to first free quick space")
	await shift_click(quick[0])
	require(game.bag.quick_slots[0].is_empty() and game.bag.item_by_uid(uid).get("id") == &"sword","Shift click returns quick storage to backpack")
	game.bag.add(&"helmet",1); ui.refresh()
	var helmet_index: int = game.bag.location(game.bag.slots.filter(func(item): return item.get("id") == &"helmet")[0].uid).index
	await shift_click(ui.backpack_buttons[helmet_index])
	require(game.bag.equipment[&"head"].get("id") == &"helmet","GUI Shift click prioritizes armor")
	var foreign := {"type":&"day_zero_item","bag":0,"uid":uid}
	require(not quick[0]._can_drop_data(Vector2.ZERO,foreign),"Foreign drag payloads are rejected")
	require(ui.get("quick_selector") == null,"Assignment dropdown is removed")
	app.show_pause()
	require(app.menu.return_button.get_theme_font("font") == app.menu.pause_font and app.menu.settings_button.text == "CONFIGURACIÓN","Pause labels use the recreated font, including accents")
	print("%s: %d drag/transfer/menu checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(0 if failures == 0 else 1)
