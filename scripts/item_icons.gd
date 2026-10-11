extends RefCounted
const SHEET = preload("res://assets/items/basic_tools.png")
static var textures: Dictionary = {}
static func get_icon(id: StringName) -> Texture2D:
	if textures.is_empty():
		var image := SHEET.get_image()
		var half := Vector2i(image.get_width() / 2, image.get_height() / 2)
		var ids := [&"sword", &"bow", &"pickaxe", &"axe"]
		for i in 4:
			var cell := Rect2i(Vector2i(i % 2, i / 2) * half, half)
			var used := image.get_region(cell).get_used_rect()
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(cell.position + used.position, used.size)
			textures[ids[i]] = atlas
	return textures.get(id)
