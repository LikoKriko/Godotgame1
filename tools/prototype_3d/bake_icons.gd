extends SceneTree
const Sources=preload("res://tools/prototype_3d/icon_sources.gd")
const Icons=preload("res://scripts/prototype_3d/item_icons.gd")
const Style=preload("res://scripts/visual_style.gd")
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Icons.ROOT))
 var placeholder:=Image.create(256,256,false,Image.FORMAT_RGBA8)
 var question:PackedStringArray=["01110","11011","00011","00110","00100","00000","00100"]
 for y in question.size():
  for x in question[y].length():
   if question[y][x]=="1":placeholder.fill_rect(Rect2i(78+x*20,58+y*20,20,20),Color("c9c5b1"))
 placeholder.save_png(Icons.ROOT+"_placeholder.png")
 var ids:Array=preload("res://scripts/inventory.gd").DEFINITIONS.keys();ids.append(&"botella_full")
 var count:=0
 for id in ids:
  var raw:Texture2D=Sources.raw(id)
  if raw==null:continue
  var world:=raw.get_size()*(248.0/(maxf(raw.get_width(),raw.get_height())*Style.PIXELS_PER_WORLD))
  var clean:Texture2D=Style.normalized(raw,world,true,true)
  var image:=clean.get_image();var canvas:=Image.create(256,256,false,Image.FORMAT_RGBA8)
  canvas.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((Vector2(256,256)-Vector2(image.get_size()))*0.5))
  var error:=canvas.save_png(Icons.ROOT+String(id)+".png")
  if error!=OK:push_error("Icon export failed: "+String(id));quit(1);return
  count+=1;await process_frame
 print("PASS: %d original-art icons exported at 256x256; missing designs use one shared placeholder"%count);quit()
