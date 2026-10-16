extends SceneTree
var checks := 0
var failures := 0
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
 for id in ["menu_button","game_button","menu_frame","game_frame"]:
  var rim: Image = load("res://assets/ui/styles/"+id+".png").get_image()
  var filled: Image = load("res://assets/ui/styles/"+id+"_filled.png").get_image()
  require(rim.get_size() == filled.get_size(),"Fill and border share the same source geometry")
  require(filled.get_pixel(filled.get_width()/2,filled.get_height()/2).a > 0.99,"Enclosed frame interior has opaque paper")
  for x in filled.get_width():
   for y in [0,filled.get_height()-1]:
    require(filled.get_pixel(x,y).a == rim.get_pixel(x,y).a,"Paper cannot spill beyond the top/bottom contour")
  for y in filled.get_height():
   for x in [0,filled.get_width()-1]:
    require(filled.get_pixel(x,y).a == rim.get_pixel(x,y).a,"Paper cannot spill beyond the side contour")
 for id in ["settings","pause"]:
  var icon: Image = load("res://assets/ui/styles/"+id+"_icon.png").get_image()
  var outline := false
  for y in icon.get_height():
   for x in icon.get_width():
    var color := icon.get_pixel(x,y)
    if color.a > 0.9 and maxf(color.r,maxf(color.g,color.b)) < 0.2: outline = true
  require(outline,"HUD glyph has a thin dark outline")
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game); game.set_process(false)
 var panel = game.inventory_panel.content.get_child(0)
 require(panel.get_theme_stylebox("panel").edge == 24,"Inventory frame is three times the old eight-unit border")
 var tabs = game.inventory_panel.navigation
 require(tabs.position.y == 16 and tabs.buttons[0].position.y == 0,"Tabs sit a few pixels below the visible enlarged top border")
 var clock = preload("res://scripts/day_cycle.gd").new()
 for hour in [7.0,9.0,13.0,17.0,19.0]:
  clock.hour = hour; var sun := clock.sun_state()
  var old := lerpf(2.6,0.36,float(sun.elevation))
  require(is_equal_approx(float(sun.stretch)-0.36,(old-0.36)*0.8),"Extra shadow elongation reduced by twenty percent")
 print("%s: %d UI raster/spacing/shadow length checks" % ["PASS" if failures == 0 else "FAIL",checks]); quit(1 if failures else 0)
