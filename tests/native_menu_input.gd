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
	var screen: Vector2 = root.get_final_transform()*button.get_global_transform_with_canvas()*point+Vector2(root.position)
	var arguments := PackedStringArray([ProjectSettings.globalize_path("res://tests/native_pointer.py"),str(DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)),str(roundi(screen.x)),str(roundi(screen.y))])
	if pressed != -1: arguments.append(str(pressed))
	var error := OS.execute("python3",arguments)
	require(error == 0,"Native pointer injection succeeds")
	await settle()


func boundaries(button: Control) -> void:
	await settle()
	for point in [Vector2(3,3),button.size-Vector2(3,3),button.size/2]:
		await native_pointer(button,point)
		require(root.gui_get_hovered_control() == button,"Real OS pointer hovers exactly inside the rendered button")
	for point in [Vector2(-3,button.size.y/2),Vector2(button.size.x+3,button.size.y/2)]:
		await native_pointer(button,point)
		require(root.gui_get_hovered_control() != button,"Real OS pointer outside the button cannot hover it")
func click(button: Control) -> void:
	await native_pointer(button,button.size/2,1)
	await native_pointer(button,button.size/2,0)
func stale_event_click(button: Control) -> void:
	await native_pointer(button,button.size/2)
	var correct := button.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT; event.pressed = pressed
		event.position = correct+Vector2(28,24)
		event.global_position = event.position
		Input.parse_input_event(event); Input.flush_buffered_events()
		await settle()

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
		await stale_event_click(app.menu.settings_button)
		require(is_instance_valid(app.menu.settings_panel),"Visible native cursor opens settings despite a stale event offset")
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
		await boundaries(inventory.equip_button)
		await click(inventory.equip_button)
		require(app.game.bag.held_id() == &"sword","Native click equips the selected item")
		inventory.hide(); app.show_pause()
	print("%s: %d native mouse checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
