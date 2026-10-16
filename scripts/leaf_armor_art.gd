extends RefCounted
## Icon and torso use the same restrained leaf/rope palette and separators.
static func texture(source: Texture2D,world_size: Vector2) -> Texture2D:
	var normalized: Texture2D = preload("res://scripts/visual_style.gd").normalized(source,world_size,true,true,1.25)
	var pixels := normalized.get_image()
	var result := pixels.duplicate()
	for y in pixels.get_height():
		for x in pixels.get_width():
			var paint := pixels.get_pixel(x,y)
			if paint.a < 0.9 or paint.v < 0.20: continue
			var leaf := paint.g > paint.r*1.06 and paint.g > paint.b*1.2
			# Three main leaf tones replace the many local muscle-like highlights.
			if leaf:
				var value := 0.30 if paint.v < 0.37 else (0.44 if paint.v < 0.56 else 0.58)
				paint = Color.from_hsv(0.225,0.65,value,paint.a)
			else:
				paint = Color.from_hsv(paint.h,roundf(paint.s*5)/5,roundf(paint.v*5)/5,paint.a)
			# A one-raster-pixel line separates rope from overlapping leaves.
			if leaf:
				for offset in [Vector2i.LEFT,Vector2i.UP]:
					var point: Vector2i = Vector2i(x,y)+offset
					if point.x < 0 or point.y < 0: continue
					var other := pixels.get_pixelv(point)
					if other.a > 0.9 and other.v > 0.3 and other.r > other.g*1.1:
						paint = Color(0.12,0.15,0.07,paint.a); break
			result.set_pixel(x,y,paint)
	return ImageTexture.create_from_image(result)
