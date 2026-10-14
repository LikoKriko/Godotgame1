extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(message)
func settle() -> void:
	for i in 4: await process_frame
func native_pointer(button: Control, point: Vector2, pressed: int = -1) -> void:
	var expected := button.get_global_transform_with_canvas()*point
	var screen: Vector2 = root.get_final_transform()*button.get_global_transform_with_canvas()*point+Vector2(root.position)
	var arguments := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(screen.x)),str(roundi(screen.y))])
	if pressed != -1: arguments.append(str(pressed))
	var error := OS.execute("python3",arguments)
	require(error == 0,"Native pointer injection succeeds")
	await settle()
	# XTest delivery is asynchronous, especially while software rendering.
	# Wait for the actual requested coordinates, never for a desired hover result.
	for frame in 12:
		if root.get_mouse_position().distance_to(expected) <= 1.5: break
		await process_frame
	require(root.get_mouse_position().distance_to(expected) <= 1.5,"The engine receives the native pointer coordinates before testing hit areas")


func boundaries(button: Control) -> void:
	await settle()
	for point in [Vector2(3,3),button.size-Vector2(3,3),button.size/2]:
		await native_pointer(button,point)
		require(root.gui_get_hovered_control() == button,"Real OS pointer hovers exactly inside the rendered button: %s, local=%s, screen=%s, hover=%s, mouse=%s" % [button.get_path(),point,root.get_final_transform()*button.get_global_transform_with_canvas()*point+Vector2(root.position),root.gui_get_hovered_control(),root.get_mouse_position()])
	for point in [Vector2(-3,button.size.y/2),Vector2(button.size.x+3,button.size.y/2)]:
		await native_pointer(button,point)
		require(root.gui_get_hovered_control() != button,"Real OS pointer outside the button cannot hover it")
func click(button: Control) -> void:
	await native_pointer(button,button.size/2,1)
	await native_pointer(button,button.size/2,0)
	for app in get_nodes_in_group("day_zero_apps"):
		while app.loading_busy: await process_frame

func run() -> void:
	if DisplayServer.get_name() != "X11": push_error("Requires X11 native-pointer runner"); quit(1); return
	var app = load("res://scenes/day_zero.tscn").instantiate()
	root.add_child(app); await settle()
	for case in [[Vector2i(1280,720),1.0],[Vector2i(1280,720),1.25],[Vector2i(1280,720),1.5],[Vector2i(1920,1080),1.0]]:
		root.size = case[0]; root.position = Vector2i(0,0)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_factor = case[1]
		await settle()
		await boundaries(app.menu.play_button)
		await boundaries(app.menu.settings_button)
		await click(app.menu.settings_button)
		require(is_instance_valid(app.menu.settings_panel),"The real native cursor opens the rendered settings button")
		if not is_instance_valid(app.menu.settings_panel): quit(1); return
		var panel = app.menu.settings_panel
		var buttons: Array[Node] = panel.find_children("*","Button",true,false)
		for button in buttons:
			if button.text == "Volver": await boundaries(button); await click(button); break
		require(not is_instance_valid(app.menu.settings_panel),"Native click closes settings")
		await click(app.menu.play_button)
		require(is_instance_valid(app.game) and not app.menu.visible,"Native click starts or resumes the game")
		app.game.set_process(false)
		app.game.restart()
		var inventory = app.game.inventory_panel
		inventory.open_section(0)
		await boundaries(inventory.backpack_buttons[0])
		await click(inventory.backpack_buttons[0])
		require(inventory.chosen == 0,"Native click selects the visible inventory slot")
		await boundaries(inventory.gear_buttons[&"hands"])
		require(not inventory.equip_button.visible,"Weapons use dragging; the consumable action stays hidden")
		inventory.hide(); app.show_pause()
	print("%s: %d native mouse checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
