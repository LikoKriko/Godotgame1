extends RefCounted
const MATERIALS = preload("res://assets/items/basic_materials.png")
const MaterialRegions = preload("res://assets/items/material_regions.gd")
const StoneTools = preload("res://scripts/tool_sprites.gd")
static var textures: Dictionary = {}
static func for_item(item: Dictionary) -> Texture2D:
	if item.get("id") == &"botella":
		return preload("res://scripts/container_art.gd").icon(1 if item.get("water_ml",0) > 0 else 0)
	return get_icon(item.get("id",&""))

static func get_icon(id: StringName) -> Texture2D:
	if id == &"basic_workbench": return preload("res://scripts/workbench_art.gd").icon()
	if id == &"flecha": return preload("res://scripts/arrow_art.gd").data().texture
	if id in [&"botella",&"water",&"cuero",&"hilo"]:
		return preload("res://scripts/container_art.gd").icon({&"botella":0,&"water":1,&"cuero":2,&"hilo":3}[id])
	if id == &"apple":
		if not textures.has(&"new_apple"):
			var apple := AtlasTexture.new()
			apple.atlas = preload("res://assets/items/apple.png")
			apple.region = Rect2(324,158,549,642)
			textures[&"new_apple"] = preload("res://scripts/visual_style.gd").icon(apple,id)
		return textures[&"new_apple"]
	if id == &"piedra":
		var rock := preload("res://scripts/imported_nature.gd")
		var stone: Texture2D = rock.texture(rock.ROCKS[0])
		return preload("res://scripts/visual_style.gd").normalized(stone,stone.get_size()*24/maxf(stone.get_width(),stone.get_height()),true,true,0.9)
	if id in [&"burdock_armor",&"hoja_bardana"]:
		if not textures.has(id):
			var atlas := AtlasTexture.new()
			atlas.atlas = preload("res://assets/items/burdock_armor_guide.png") if id == &"burdock_armor" else preload("res://assets/items/burdock_leaf.png")
			atlas.region = Rect2(1080,270,368,674) if id == &"burdock_armor" else Rect2(57,156,1142,945)
			textures[id] = preload("res://scripts/leaf_armor_art.gd").texture(atlas,atlas.get_size()*28/maxf(atlas.get_width(),atlas.get_height())) if id == &"burdock_armor" else preload("res://scripts/visual_style.gd").normalized(atlas,atlas.get_size()*28/maxf(atlas.get_width(),atlas.get_height()),true,true)
		return textures[id]
	if StoneTools.DATA.has(id):
		return preload("res://scripts/visual_style.gd").icon(StoneTools.icon(id),id)
	if not textures.has(&"apple"):
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
