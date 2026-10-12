extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func require(value: bool,message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func settle() -> void:
	await process_frame
	await process_frame
func hover(button: Control,local: Vector2) -> bool:
	var event := InputEventMouseMotion.new()
	event.position = button.get_global_transform_with_canvas()*local
	event.global_position = event.position
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await settle()
	return root.gui_get_hovered_control() == button
func boundaries(button: Control) -> void:
	await settle()
	for point in [Vector2(2,2),Vector2(button.size.x-2,2),button.size-Vector2(2,2),Vector2(2,button.size.y-2),button.size/2]:
		require(await hover(button,point),"Visible button interior receives hover at "+str(point))
	for point in [Vector2(-2,button.size.y/2),Vector2(button.size.x+2,button.size.y/2),Vector2(button.size.x/2,-2),Vector2(button.size.x/2,button.size.y+2)]:
		require(not await hover(button,point),"Outside the painted border never receives hover")
func run() -> void:
	var app = load("res://scenes/day_zero.tscn").instantiate()
	root.add_child(app)
	await settle()
	for dimensions in [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080)]:
		root.size = dimensions
		await settle()
		await boundaries(app.menu.play_button)
		await boundaries(app.menu.settings_button)
		app.menu.open_settings()
		await settle()
		var panel = app.menu.settings_panel
		var buttons: Array[Node] = panel.find_children("*","Button",true,false)
		for button in buttons:
			if button.visible and button.text in ["Volver","Aplicar"]: await boundaries(button)
		app.menu.close_settings()
		app.play()
		app.game.set_process(false)
		app.game.world_view.hide()
		await settle()
		app.game.inventory_panel.show()
		await settle()
		await boundaries(app.game.inventory_panel.backpack_buttons[0])
		await boundaries(app.game.inventory_panel.craft_button)
		app.game.inventory_panel.hide()
		app.show_pause()
	print("%s: %d menu boundary checks across three window sizes, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(1 if failures else 0)
