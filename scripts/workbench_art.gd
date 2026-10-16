extends RefCounted
const SOURCE = preload("res://assets/environment/imported/workbench_basic.png")
static var SHADOW_CONTACTS := PackedVector2Array([Vector2(0.083,0.746),Vector2(0.334,0.585),Vector2(0.631,0.992),Vector2(0.919,0.85)])
const HEIGHT := 32.0
static var world_texture: Texture2D
static var icon_texture: Texture2D
static var surface_mask: BitMap
static func dimensions() -> Vector2: return Vector2(HEIGHT*SOURCE.get_width()/SOURCE.get_height(),HEIGHT)
static func texture() -> Texture2D:
	if world_texture == null: world_texture = preload("res://scripts/visual_style.gd").normalized(SOURCE,dimensions(),true)
	return world_texture
static func icon() -> Texture2D:
	if icon_texture == null: icon_texture = preload("res://scripts/visual_style.gd").normalized(SOURCE,SOURCE.get_size()*28/maxf(SOURCE.get_width(),SOURCE.get_height()),true)
	return icon_texture

static func contains(point: Vector2, rect: Rect2) -> bool:
	if not rect.has_point(point): return false
	if surface_mask == null:
		var pixels := SOURCE.get_image()
		var size := dimensions()*preload("res://scripts/visual_style.gd").PIXELS_PER_WORLD
		pixels.resize(roundi(size.x),roundi(size.y),Image.INTERPOLATE_NEAREST)
		pixels = preload("res://scripts/visual_style.gd").outlined(preload("res://scripts/visual_style.gd").clean_border(pixels))
		surface_mask = BitMap.new(); surface_mask.create_from_image_alpha(pixels,0.05)
	var pixel := Vector2i((point-rect.position)/rect.size*Vector2(surface_mask.get_size()))
	return surface_mask.get_bitv(pixel)
