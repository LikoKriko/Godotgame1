extends SceneTree
func _initialize(): call_deferred("run")
func clean(picture: Image) -> Image:
 picture.convert(Image.FORMAT_RGBA8)
 for y in picture.get_height():
  for x in picture.get_width():
   var color := picture.get_pixel(x,y)
   if maxf(color.r,maxf(color.g,color.b)) < 0.045: picture.set_pixel(x,y,Color.TRANSPARENT)
 return picture.get_region(picture.get_used_rect())
func run():
 var source := Image.load_from_file("res://entregables/entorno/terreno/suelo_elevado_1.png")
 var regions := [Rect2i(20,310,530,310),Rect2i(550,310,550,310),Rect2i(1095,310,577,330)]
 for i in 3:
  var result := clean(source.get_region(regions[i]))
  result.save_png("res://assets/environment/imported/platform_%02d.png" % (i+1))
 var hut := Image.load_from_file("res://entregables/edificio/choza1.png")
 hut.get_region(Rect2i(577,622,190,45)).save_png("res://assets/environment/imported/hut_timber.png")
 clean(hut).save_png("res://assets/environment/imported/hut_01.png")
 print("PASS building and three platform sprites: originals preserved"); quit()
