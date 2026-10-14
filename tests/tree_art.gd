extends SceneTree
const TreeArt = preload("res://scripts/tree_art.gd")
const Style = preload("res://scripts/visual_style.gd")
var checks := 0
var failures := 0
func require(ok: bool,message: String):
 checks += 1
 if not ok: failures += 1; push_error(message)
func _initialize():
 var restored := 0
 for design in 9:
  var texture: Texture2D = preload("res://scripts/large_tree_art.gd").texture(design)
  for multiplier in [1.0]:
   var dimensions: Vector2 = preload("res://scripts/large_tree_art.gd").dimensions(design)*multiplier
   var picture := TreeArt.raster(texture,dimensions)
   var original := texture.get_image(); original.resize(picture.get_width(),picture.get_height(),Image.INTERPOLATE_NEAREST)
   var previous := Style.outlined(Style.clean_border(original))
   require(picture.get_used_rect().size.y > 100,"Tree raster retains its full drawing")
   var same_alpha := true
   for y in picture.get_height():
    for x in picture.get_width():
     var a := previous.get_pixel(x,y); var b := picture.get_pixel(x,y)
     if a.a != b.a: same_alpha = false
     if a != b:
      restored += 1
      require(absf(b.r-TreeArt.INK.r) < 0.004 and absf(b.g-TreeArt.INK.g) < 0.004 and absf(b.b-TreeArt.INK.b) < 0.004,"New structural lines are thin near-black original ink")
   require(same_alpha,"Structural ink never changes the tree silhouette or transparency")
   require(TreeArt.texture(texture,dimensions) == TreeArt.texture(texture,dimensions),"Tree resources are reused across instances")
 require(restored > 0,"Original branch and foliage separators are restored")
 print("%s: %d tree art checks, %d restored interior pixels" % ["PASS" if failures == 0 else "FAIL",checks,restored]);quit(1 if failures else 0)
