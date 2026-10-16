extends SceneTree
var failures := 0
var checks := 0
func require(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in 5: await process_frame
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new(); event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events(); await settle()
func native_mouse(point: Vector2, pressed: int) -> void:
	var args := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(point.x)),str(roundi(point.y)),str(pressed)])
	require(OS.execute("python3",args) == 0,"Native input reaches the game window")
	await settle()
func click(control: Control) -> void:
	var point := root.get_final_transform()*control.get_global_transform_with_canvas()*(control.size/2)+Vector2(root.position)
	await native_mouse(point,1); await native_mouse(point,0)
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false); await settle()
	await key(KEY_K)
	var catalog = game.item_catalog
	require(catalog.visible and game.is_paused(),"K opens the paused catalogue")
	catalog.search.text = "botella"; catalog.filter_entries("botella"); await settle()
	await click(catalog.buttons[&"botella"])
	catalog.quantity.value = 2
	var add_button: Button
	var close_button: Button
	for button in catalog.find_children("*","Button",true,false):
		if button.text == "Añadir a la mochila": add_button = button
		if button.text == "Cerrar": close_button = button
	await click(add_button)
	require(game.bag.count(&"botella") == 2,"Native catalogue click adds the selected quantity")
	await click(close_button)
	require(not catalog.visible and not game.is_paused(),"Closing the catalogue resumes gameplay")
	var index := -1
	for i in game.bag.CAPACITY:
		if game.bag.slots[i].get("id") == &"botella": index = i; break
	game.bag.slots[index].water_ml = 500; game.nutrition.hydration_ml = 1000
	game.inventory_panel.open_section(0); await settle()
	await click(game.inventory_panel.backpack_buttons[index])
	require(game.inventory_panel.equip_button.text == "Beber","Selecting a bottle exposes the drinking action")
	await click(game.inventory_panel.equip_button)
	require(game.bag.slots[index].water_ml == 250 and game.nutrition.hydration_ml == 1250,"Native inventory click drinks exactly 250 ml")
	game.inventory_panel.hide()
	game.bag.move_item(&"bag",index,&"quick",0)
	await key(KEY_1)
	game.full_avatar.update_pose(0)
	require(game.bag.held_id() == &"botella" and game.full_avatar.item_key() == "bottle_full" and game.full_avatar.texture != null,"Selecting the bottle displays its complete carried sprite")
	await native_mouse(Vector2(root.position)+Vector2(520,400),1)
	require(game.bag.quick_slots[0].water_ml == 0 and game.nutrition.hydration_ml == 1500,"Gameplay left click drinks the remaining 250 ml")
	game._process(0.25)
	require(game.bag.quick_slots[0].water_ml == 0 and not game.working,"Holding click cannot auto-drink or start a tool strike")
	await native_mouse(Vector2(root.position)+Vector2(520,400),0)
	require(game.full_avatar.item_key() == "bottle_empty","The carried sprite switches to the empty state")
	await key(KEY_1)
	require(game.bag.held_id() == &"" and game.bag.quick_slots[0].id == &"botella","Repeated key leaves hands free without removing the container")
	print("%s: %d native catalogue, inventory and carried-bottle checks" % ["PASS" if failures == 0 else "FAIL",checks])
	quit(0 if failures == 0 else 1)
