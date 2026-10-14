extends RefCounted
## Shared raster treatment for the icon and the torso shell.
static func texture(source: Texture2D,world_size: Vector2) -> Texture2D:
 var normalized: Texture2D = preload("res://scripts/visual_style.gd").normalized(source,world_size,true,true,1.25)
 var pixels := normalized.get_image(); var result := pixels.duplicate()
 for y in range(1,pixels.get_height()-1):
  for x in range(1,pixels.get_width()-1):
   var paint := pixels.get_pixel(x,y)
   if paint.a < 0.9 or maxf(paint.r,maxf(paint.g,paint.b)) < 0.20: continue
   var neighbors := Color(0,0,0,0); var solid := true
   for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
    var neighbor := pixels.get_pixelv(Vector2i(x,y)+offset)
    if neighbor.a < 0.9: solid = false; break
    neighbors += neighbor*0.25
   if not solid: continue
   # Slight local definition retains the original leaves, lashings and colors.
   var detail := paint+(paint-neighbors)*0.16
   result.set_pixel(x,y,Color(clampf(detail.r,0,1),clampf(detail.g,0,1),clampf(detail.b,0,1),paint.a))
 return ImageTexture.create_from_image(result)
