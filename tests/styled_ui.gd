extends SceneTree
const Save = preload("res://scripts/save_game.gd")
const Settings = preload("res://scripts/game_settings.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func settle() -> void:
	for i in 4: await process_frame
func pointer(button: Control, point: Vector2, pressed: int = -1) -> void:
	var screen: Vector2 = root.get_final_transform()*button.get_global_transform_with_canvas()*point+Vector2(root.position)
	var arguments := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(screen.x)),str(roundi(screen.y))])
	if pressed != -1: arguments.append(str(pressed))
	require(OS.execute("python3",arguments) == 0,"Native pointer delivered")
	await settle()
func click(button: Control) -> void:
	await pointer(button,button.size/2,1)
	await pointer(button,button.size/2,0)
func boundaries(button: Control) -> void:
	for point in [Vector2(3,3),button.size/2,button.size-Vector2(3,3)]:
		await pointer(button,point)
		require(root.gui_get_hovered_control() == button,"Visible HUD/button interior receives hover")
	await pointer(button,Vector2(-3,button.size.y/2))
	require(root.gui_get_hovered_control() != button,"Outside the button does not hover")
func key(code: Key) -> void:
	for pressed in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code; event.physical_keycode = code; event.pressed = pressed
		Input.parse_input_event(event); Input.flush_buffered_events()
	await settle()
func run() -> void:
	if DisplayServer.get_name() != "X11": push_error("Requires native X11 pointer"); quit(1); return
	var preserved := {}
	for path in [Save.PATH, Settings.PATH]:
		preserved[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var app = load("res://scenes/day_zero.tscn").instantiate()
	root.add_child(app); await settle()
	root.position = Vector2i.ZERO
	require(app.menu.continue_button.disabled and app.menu.shop_button.disabled,"Continue requires a saved game; store remains disabled")
	require(not app.menu.save_button.visible,"Save belongs only to pause")
	var volume: float = app.settings.values.master
	await boundaries(app.menu.mute_button)
	await click(app.menu.mute_button)
	require(app.settings.values.muted and AudioServer.is_bus_mute(0),"Mute button disables Master audio")
	require(app.settings.values.master == volume,"Mute preserves chosen volume")
	await click(app.menu.mute_button)
	require(not AudioServer.is_bus_mute(0),"Second click restores sound")
	await click(app.menu.new_game_button)
	var game = app.game
	game.set_process(false)
	require(is_instance_valid(game) and not app.menu.visible,"Play opens a new game")
	var hud = game.styled_hud
	require(hud.quick_buttons.size() == 6 and hud.skill_buttons.size() == 4,"Six inventory and four skill spaces")
	require(hud.skill_buttons[2].disabled and hud.skill_buttons[3].disabled,"Future skills stay inactive")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = dimensions; root.position = Vector2i.ZERO
		root.content_scale_size = dimensions
		await settle()
		for level in range(1,7):
			app.settings.values.hud_size = level; app.settings.changed.emit()
			await settle()
			await boundaries(hud.setting_button)
			await boundaries(hud.shortcuts[0])
			var quick: Rect2 = hud.quick_bar.get_global_rect()
			var skills: Rect2 = hud.skill_bar.get_global_rect()
			require(not quick.intersects(skills) and not quick.intersects(hud.water.get_global_rect()) and not skills.intersects(hud.shortcuts[2].get_global_rect()),"Bottom widgets never overlap")
			require(is_equal_approx(hud.water.get_global_rect().position.y,hud.food.get_global_rect().end.y),"Hydration directly adjoins calories")
	app.settings.values.hud_size = 1; app.settings.changed.emit(); await settle()
	await click(hud.shortcuts[0])
	require(game.inventory_panel.visible,"Inventory HUD button works")
	game.inventory_panel.select_backpack(0)
	game.inventory_panel.assign_selected_quick(1)
	var sword_uid: int = game.bag.slots[0].uid
	require(game.quick_items[0] == sword_uid,"Assignment references the selected item")
	game.inventory_panel.hide(); hud.refresh()
	await click(hud.quick_buttons[0])
	require(game.bag.equipment[&"hands"].uid == sword_uid,"HUD equips exactly the assigned sword")
	game.bag.unequip(&"hands")
	game.equipping = false
	await key(KEY_1)
	require(game.bag.equipment[&"hands"].uid == sword_uid,"Keyboard shortcut follows the item after changing slots")
	game.equipping = false
	for i in game.bag.CAPACITY:
		if game.bag.slots[i].get("id") == &"ration":
			game.assign_quick_item(5,game.bag.slots[i].uid); break
	var rations: int = game.bag.count(&"ration")
	await key(KEY_6)
	require(game.bag.count(&"ration") == rations-1 and game.nutrition.calories_today == 400,"Quick access consumes exactly one selected food")
	await click(hud.shortcuts[1])
	require(game.inventory_panel.navigation.current_tab == 1,"Create HUD button opens recipes")
	game.inventory_panel.hide()
	await click(hud.map_button)
	require(game.world_map.visible and game.is_paused(),"Map icon opens full map")
	game.world_map.hide()
	await click(hud.setting_button)
	require(game.menu_open and is_instance_valid(app.menu.settings_panel),"Settings HUD button pauses and opens preferences")
	app.menu.close_settings()
	await click(app.menu.continue_button)
	await click(hud.pause_button)
	require(game.menu_open and app.menu.save_button.visible,"Pause exposes manual saving")
	var snapshot: Dictionary = Save.capture(game)
	await click(app.menu.save_button)
	require(app.menu.message.text == "Partida guardada.","Manual save reports success: "+app.menu.message.text)
	var saved: Dictionary = Save.read_state()
	for field in snapshot:
		# ConfigFile stores decimal text; sub-microlitre float rounding is not
		# lost water. Inventories, quantities and points still compare exactly.
		var equal: bool = absf(float(saved.get(field))-snapshot[field]) < 0.000001 if snapshot[field] is float else saved.get(field) == snapshot[field]
		require(equal,"Manual save preserves field: "+field)
	app.return_to_title()
	require(app.menu.continue_button.disabled == false,"Saved game makes Continue available")
	await click(app.menu.continue_button)
	app.game.set_process(false)
	# A few elapsed frames can advance time after continuing; compare stable data.
	require(app.game.bag.equipment == snapshot.equipment and app.game.quick_items == snapshot.quick_items and app.game.nutrition.calories_today == snapshot.calories,"Continue recovers inventory, shortcuts and nutrition from disk")
	app.show_pause()
	await click(app.menu.new_game_button)
	require(app.menu.confirmation.visible and app.game.menu_open,"New game asks before discarding the open game")
	app.menu.confirmation.hide()
	app.free()
	for path in preserved:
		if preserved[path] == null: DirAccess.remove_absolute(path)
		else:
			var file := FileAccess.open(path,FileAccess.WRITE)
			file.store_buffer(preserved[path]); file.close()
	print("%s: %d styled HUD/menu checks, %d failures" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
