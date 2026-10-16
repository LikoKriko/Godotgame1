extends RefCounted
## Keep the user's original one-pixel structural ink when normalizing the rim.
const Style = preload("res://scripts/visual_style.gd")
const INK := Color8(9,9,10,255)
static var cache: Dictionary = {}
static func texture(source: Texture2D, world_size: Vector2) -> Texture2D:
	var atlas := source as AtlasTexture
	var crop := str(atlas.region)+":"+str(atlas.margin) if atlas != null else ""
	var key := str(source.get_rid().get_id())+":"+crop+":"+str(world_size)
	if cache.has(key): return cache[key]
	var resource := ImageTexture.create_from_image(raster(source,world_size))
	cache[key] = resource
	return resource

static func raster(source: Texture2D, world_size: Vector2) -> Image:
	var original := source.get_image(); original.convert(Image.FORMAT_RGBA8)
	original.resize(maxi(3,roundi(world_size.x*Style.PIXELS_PER_WORLD)),maxi(3,roundi(world_size.y*Style.PIXELS_PER_WORLD)),Image.INTERPOLATE_NEAREST)
	var result := Style.outlined(Style.clean_border(original))
	for y in range(1,result.get_height()-1):
		for x in range(1,result.get_width()-1):
			var pixel := original.get_pixel(x,y)
			if pixel.a < 0.8 or maxf(pixel.r,maxf(pixel.g,pixel.b)) > 0.18: continue
			# An interior ink line has solid, brighter drawing on opposite sides.
			# This excludes the thick outer rim and never grows the silhouette.
			var structural := false
			for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
				var a := original.get_pixelv(Vector2i(x,y)+axis)
				var b := original.get_pixelv(Vector2i(x,y)-axis)
				if a.a > 0.8 and b.a > 0.8 and maxf(a.r,maxf(a.g,a.b)) > 0.22 and maxf(b.r,maxf(b.g,b.b)) > 0.22: structural = true
			if structural:
				var ink := INK; ink.a = result.get_pixel(x,y).a
				result.set_pixel(x,y,ink)
	return result
