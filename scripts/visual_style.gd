extends RefCounted
## Permanent shared art policy. Width scales with drawing/world size, never zoom.
const PIXELS_PER_WORLD := 1.53125
const OUTLINE_PIXELS := 1
const OUTLINE_COLOR := Color(0.18,0.12,0.075,0.9)
static var cache: Dictionary = {}
static var cache_order: Array[String] = []
const CACHE_LIMIT := 512

static func normalized(texture: Texture2D,world_size: Vector2,outline: bool = true,clear_black: bool = false) -> Texture2D:
	var target := Vector2i(maxi(3,roundi(world_size.x*PIXELS_PER_WORLD)),maxi(3,roundi(world_size.y*PIXELS_PER_WORLD)))
	var key := "%s:%s:%s:%s" % [texture.get_rid().get_id(),target,outline,clear_black]
	if cache.has(key): return cache[key]
	var source := texture.get_image()
	# AtlasTexture.get_image returns its own isolated region.
	source.convert(Image.FORMAT_RGBA8)
	if clear_black:
		for y in source.get_height():
			for x in source.get_width():
				var paint := source.get_pixel(x,y)
				if maxf(paint.r,maxf(paint.g,paint.b)) < 0.035: source.set_pixel(x,y,Color.TRANSPARENT)
	source.resize(target.x,target.y,Image.INTERPOLATE_NEAREST)
	var result := clean_border(source)
	if outline: result = outlined(result)
	var image := ImageTexture.create_from_image(result)
	cache[key] = image
	cache_order.append(key)
	if cache_order.size() > CACHE_LIMIT: cache.erase(cache_order.pop_front())
	return image

static func clean_border(source: Image) -> Image:
	var result := source.duplicate()
	var size := source.get_size()
	# Restrict replacement to dark paint near the alpha boundary. Interior marks
	# and naturally dark shaded regions are not globally recolored.
	for y in size.y:
		for x in size.x:
			var paint := source.get_pixel(x,y)
			if paint.a < 0.5 or maxf(paint.r,maxf(paint.g,paint.b)) >= 0.18: continue
			var near_edge := false
			var nearest := 100.0
			var pigment := paint
			for dy in range(-5,6):
				for dx in range(-5,6):
					var point := Vector2i(x+dx,y+dy)
					if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y:
						near_edge = true; continue
					var other := source.get_pixelv(point)
					if other.a < 0.5: near_edge = true
					var distance := float(dx*dx+dy*dy)
					if other.a > 0.8 and maxf(other.r,maxf(other.g,other.b)) >= 0.22 and distance < nearest:
						nearest = distance
						pigment = other
			if near_edge and nearest < 100:
				pigment.a = paint.a
				result.set_pixel(x,y,pigment)
	return result

static func outlined(source: Image) -> Image:
	var result := source.duplicate()
	for y in range(1,source.get_height()-1):
		for x in range(1,source.get_width()-1):
			if source.get_pixel(x,y).a > 0.01: continue
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if source.get_pixelv(Vector2i(x,y)+offset).a > 0.8:
					result.set_pixel(x,y,OUTLINE_COLOR); break
	return result

static func icon(texture: Texture2D,id: StringName) -> Texture2D:
	var span: float = {&"axe":32.0,&"pickaxe":32.0,&"sword":32.0,&"bow":28.0}.get(id,24.0)
	return normalized(texture,texture.get_size()*span/maxf(texture.get_width(),texture.get_height()),true,id == &"bow")
