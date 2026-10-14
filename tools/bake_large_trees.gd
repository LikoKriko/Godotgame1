extends SceneTree
func _initialize():
 var source := Image.load_from_file(ProjectSettings.globalize_path("res://entregables/entorno/plantas/arboles_clase1.png"))
 source.convert(Image.FORMAT_RGBA8)
 for y in source.get_height():
  for x in source.get_width():
   var paint := source.get_pixel(x,y)
   if maxf(paint.r,maxf(paint.g,paint.b)) < 0.035: source.set_pixel(x,y,Color.TRANSPARENT)
 var bands := [0,287,523,870,1131,1306,1489,1698,1882,2172]
 var sizes := []
 for i in 9:
  var part := source.get_region(Rect2i(bands[i],0,bands[i+1]-bands[i],source.get_height()))
  var used := part.get_used_rect().grow(2).intersection(Rect2i(Vector2i.ZERO,part.get_size()))
  part = part.get_region(used)
  part.save_png("res://assets/environment/imported/tree_%02d.png" % (i+1))
  sizes.append([part.get_width(),part.get_height()])
 var file := FileAccess.open("res://assets/environment/imported/tree_sizes.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(sizes))
 print(sizes)
 quit()
