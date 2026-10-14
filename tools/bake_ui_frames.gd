extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var folder := "res://assets/ui/styles/"
 DirAccess.make_dir_recursive_absolute(folder)
 var records := {
  "menu_frame":["menu_pause_borde.png",Rect2i(50,30,1340,1038)],
  "menu_button":["Menu_pause_boton.png",Rect2i(60,118,2052,496)],
  "game_frame":["juego_borde.png",Rect2i(32,22,1388,1040)],
  "game_button":["juego_boton.png",Rect2i(48,118,2070,486)],
  "fill":["relleno_todo.png",Rect2i(48,245,1320,600)]
 }
 for id in records:
  var source := Image.load_from_file("res://entregables/interfaces/"+records[id][0])
  var picture := source.get_region(records[id][1]); picture.convert(Image.FORMAT_RGBA8)
  for y in picture.get_height():
   for x in picture.get_width():
    var paint := picture.get_pixel(x,y)
    if paint.a < 0.60: picture.set_pixel(x,y,Color.TRANSPARENT)
  if picture.save_png(folder+id+".png") != OK: quit(1); return
 var hud := Image.load_from_file("res://assets/ui/hud_template.png")
 var title := Image.load_from_file("res://assets/ui/title_template.png")
 var glyphs := {"settings":[hud,Rect2(50,45,35,34)],"pause":[hud,Rect2(129,47,24,28)],"map":[hud,Rect2(1600,46,33,32)],"mute":[title,Rect2(1548,809,54,45)]}
 for id in glyphs:
  var source: Image = glyphs[id][0]; var rect: Rect2 = glyphs[id][1]
  var scale := Vector2(source.get_size())/Vector2(1672,941)
  var picture := source.get_region(Rect2i(rect.position*scale,rect.size*scale)); picture.convert(Image.FORMAT_RGBA8)
  for y in picture.get_height():
   for x in picture.get_width():
    var color := picture.get_pixel(x,y)
    if minf(color.r,minf(color.g,color.b)) < 0.55: picture.set_pixel(x,y,Color.TRANSPARENT)
  picture.save_png(folder+id+"_icon.png")
 var inventory := Image.load_from_file("res://assets/ui/inventory_template.png")
 var inventory_glyphs := {"gear_head":Rect2i(211,270,79,67),"gear_torso":Rect2i(600,269,74,68),"gear_hands":Rect2i(210,412,77,63),"gear_legs":Rect2i(600,450,78,82),"gear_feet":Rect2i(210,555,77,66),"improve":Rect2i(924,278,52,47),"repair":Rect2i(924,391,52,49),"dismantle":Rect2i(924,503,52,49)}
 for id in inventory_glyphs:
  var picture := inventory.get_region(inventory_glyphs[id]); picture.convert(Image.FORMAT_RGBA8)
  for y in picture.get_height():
   for x in picture.get_width():
    var color := picture.get_pixel(x,y)
    if minf(color.r,minf(color.g,color.b)) < 0.60: picture.set_pixel(x,y,Color.TRANSPARENT)
  picture.save_png(folder+id+"_icon.png")
 for id in ["life","food"]:
  var rect := Rect2(47,820,30,29) if id == "life" else Rect2(47,865,29,29)
  var scale := Vector2(hud.get_size())/Vector2(1672,941)
  var picture := hud.get_region(Rect2i(rect.position*scale,rect.size*scale)); picture.convert(Image.FORMAT_RGBA8)
  for y in picture.get_height():
   for x in picture.get_width():
    var color := picture.get_pixel(x,y)
    var foreground := minf(color.r,minf(color.g,color.b)) >= 0.60
    if id == "life": foreground = foreground or (color.r > 0.20 and color.r > color.g*1.5 and color.r > color.b*1.4)
    if not foreground: picture.set_pixel(x,y,Color.TRANSPARENT)
  picture.save_png(folder+id+"_icon.png")
 print("PASS native UI frame crops and isolated glyphs: originals preserved");quit()
