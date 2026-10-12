extends RefCounted
const SHEET = preload("res://assets/items/basic_tools.png")
const MATERIALS = preload("res://assets/items/basic_materials.png")
const MaterialRegions = preload("res://assets/items/material_regions.gd")
const StoneTools = preload("res://scripts/tool_sprites.gd")
static var textures: Dictionary = {}
static func get_icon(id: StringName) -> Texture2D:
	if id in [&"burdock_armor",&"hoja_bardana"]:
		if not textures.has(id):
			var atlas := AtlasTexture.new()
			atlas.atlas = preload("res://assets/items/burdock_armor_guide.png") if id == &"burdock_armor" else preload("res://assets/items/burdock_leaf.png")
			atlas.region = Rect2(1080,270,368,674) if id == &"burdock_armor" else Rect2(57,156,1142,945)
			textures[id] = preload("res://scripts/visual_style.gd").normalized(atlas,atlas.get_size()*28/maxf(atlas.get_width(),atlas.get_height()),true,true)
		return textures[id]
	if StoneTools.DATA.has(id):
		return preload("res://scripts/visual_style.gd").icon(StoneTools.icon(id),id)
	if not textures.has(&"apple"):
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
		for i in 4:
			var atlas := AtlasTexture.new()
			atlas.atlas = preload("res://assets/items/food.png")
			var data: Array = preload("res://assets/items/food_regions.gd").REGIONS[i]
			atlas.region = Rect2(data[0],data[1],data[2],data[3])
			textures[[&"apple",&"berries",&"ration",&"water"][i]] = atlas
		var materials := [&"palo",&"cuerda",&"piedra"]
		for i in materials.size():
			var atlas := AtlasTexture.new()
			atlas.atlas = MATERIALS
			var data: Array = MaterialRegions.REGIONS[i]
			atlas.region = Rect2(data[0],data[1],data[2],data[3])
			textures[materials[i]] = atlas
	var texture: Texture2D = textures.get(id)
	return preload("res://scripts/visual_style.gd").icon(texture,id) if texture != null else null
