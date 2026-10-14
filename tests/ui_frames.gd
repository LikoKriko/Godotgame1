extends SceneTree
const StyledButton = preload("res://scripts/menu_button.gd")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func validate(button: Button):
 if button.text.is_empty(): return
 var font := button.get_theme_font("font"); var fontsize := button.get_theme_font_size("font_size")
 var padding := font.get_height(fontsize)*0.15
 for state in ["normal","hover","pressed","disabled","focus"]:
  var box := button.get_theme_stylebox(state)
  for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]: require(is_equal_approx(box.get_content_margin(side),padding),"Text buttons use exact fifteen-percent padding: "+button.text)
 require(button.get_theme_stylebox("normal").rim != null,"Fitting a button preserves its new frame texture")
 require(button.get_theme_stylebox("focus").fill == null,"Keyboard focus cannot obscure its own text")
func run():
 var app = load("res://scenes/day_zero.tscn").instantiate(); root.add_child(app)
 for i in 3: await process_frame
 for node in app.menu.rects: validate(node)
 var main_font = app.menu.play_button.get_theme_font("font")
 app.menu.set_resume(true); app.menu.open_settings()
 for i in 3: await process_frame
 require(app.menu.play_button.get_theme_font("font") == main_font,"Opening configuration preserves pause-menu typography")
 for node in app.menu.settings_panel.find_children("*","Button",true,false):
  validate(node)
 require(app.menu.settings_panel.theme == preload("res://scripts/ui_style.gd").theme(&"menu"),"Configuration uses the menu frame scope")
 app.menu.settings_panel.closed.emit(); app.new_game(); app.game.set_process(false)
 app.game.inventory_panel.open_section(0)
 for i in 3: await process_frame
 var ui = app.game.inventory_panel
 for button in ui.navigation.buttons: validate(button)
 for button in [ui.improve_button,ui.repair_button,ui.dismantle_button]: validate(button)
 var last = ui.navigation.buttons.back()
 require(last.position.x+last.size.x <= ui.navigation.size.x,"Seven fitted tabs remain within the navigation frame")
 require(ui.sections.size() == 7 and ui.navigation.get_tab_title(5) == "Misiones" and ui.navigation.get_tab_title(6) == "Logros","New tabs follow Map without changing old indices")
 print("%s: %d UI frame/font/margin checks, %d failures" % ["PASS" if failures == 0 else "FAIL",checks,failures]); app.free(); quit(1 if failures else 0)
