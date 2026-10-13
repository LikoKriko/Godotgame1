extends RefCounted
const SHEET = preload("res://assets/items/containers_and_materials.png")
const REGIONS := [Rect2i(0,0,618,745),Rect2i(618,0,618,745),Rect2i(0,745,618,527),Rect2i(618,745,618,527)]
static var parts: Dictionary = {}
static func part(index: int) -> AtlasTexture:
	if not parts.has(index):
		var region: Rect2i = REGIONS[index]
		var used := SHEET.get_image().get_region(region).get_used_rect()
		var texture := AtlasTexture.new()
		texture.atlas = SHEET
		texture.region = Rect2(region.position+used.position,used.size)
		parts[index] = texture
	return parts[index]

static func icon(index: int) -> Texture2D:
	var image := part(index)
	return preload("res://scripts/visual_style.gd").normalized(image,image.get_size()*28/maxf(image.get_width(),image.get_height()),true,true)
