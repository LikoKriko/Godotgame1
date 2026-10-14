extends SceneTree
func _initialize():
 var source := Image.load_from_file("res://entregables/items/mesaelaboración1.png")
 source.convert(Image.FORMAT_RGBA8)
 for y in source.get_height():
  for x in source.get_width():
   var color := source.get_pixel(x,y)
   if maxf(color.r,maxf(color.g,color.b)) < 0.035: source.set_pixel(x,y,Color.TRANSPARENT)
 source = source.get_region(source.get_used_rect())
 if source.save_png("res://assets/environment/imported/workbench_basic.png") != OK: quit(1); return
 print("PASS workbench sprite crop: ",source.get_size()); quit()
