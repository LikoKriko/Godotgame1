extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(condition: bool,message: String):
	checks += 1
	if not condition: failures += 1; push_error(message)
func settle():
	for i in 4: await process_frame
func run():
	var app = load("res://scenes/day_zero.tscn").instantiate(); root.add_child(app)
	app.new_game(); app.game.set_process(false); app.show_pause(); await settle()
	var before: Font = app.menu.settings_button.get_theme_font("font")
	var caption: String = app.menu.settings_button.text
	app.menu.open_settings(); await settle()
	check(app.menu.options.visible and app.menu.settings_button.text == caption,"Settings keeps the live pause captions visible over the baked background")
	check(app.menu.settings_button.get_theme_font("font") == before,"Opening settings cannot swap the underlying pause font")
	check(app.menu.settings_backdrop.mouse_filter == Control.MOUSE_FILTER_STOP,"Settings blocks the still-visible background buttons")
	for button in app.menu.pause_faces: check(app.menu.pause_faces[button].visible,"The old text baked into the template remains covered")
	app.menu.close_settings(); app.menu.hide(); app.game.menu_open = false
	var game = app.game
	for size in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = size; await settle()
		for level in range(1,7):
			game.gameplay_settings.values.hud_size = level; game.fit_hud()
			game.feedback = "Necesitas flechas para disparar el arco"; game.feedback_time = 2; game.update_hud(); await settle()
			check(game.interaction.get_global_rect().end.y <= game.styled_hud.life.get_global_rect().position.y-4,"Feedback remains above health at each HUD size and resolution")
	app.free(); print("%s: %d HUD feedback/font checks, %d failures" % ["PASS" if not failures else "FAIL",checks,failures]); quit(1 if failures else 0)
