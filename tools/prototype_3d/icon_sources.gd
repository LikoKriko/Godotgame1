extends RefCounted
## Source artwork belongs to the bake tool, not the runtime icon provider.
const Tools=preload("res://scripts/tool_sprites.gd")
const Legacy=preload("res://scripts/item_icons.gd")
static func crop(texture:Texture2D,rect:Rect2) -> AtlasTexture:
 var result:=AtlasTexture.new();result.atlas=texture;result.region=rect;return result
static func raw(id:StringName) -> Texture2D:
 if id in [&"botella",&"botella_full",&"water"]:return load("res://assets/items/prototype_3d/bottle_meshy/icon.png")
 if id in [&"axe",&"pickaxe",&"bow",&"burdock_armor",&"piedra"]:
  var name:String={&"burdock_armor":"leaf_armor",&"piedra":"rock1"}.get(id,String(id))
  return load("res://assets/models/meshy/"+name+"/icon.png")
 if Tools.DATA.has(id):return Tools.icon(id)
 if id in [&"cuero_curtido",&"cuero_sin_refinar",&"saco_sal"]:return load("res://assets/items/"+{&"cuero_curtido":"tanned_leather",&"cuero_sin_refinar":"raw_hide",&"saco_sal":"salt_bag"}[id]+".png")
 if id==&"basic_workbench":return preload("res://scripts/workbench_art.gd").SOURCE
 if id==&"flecha":return crop(preload("res://scripts/arrow_art.gd").SOURCE,preload("res://scripts/arrow_art.gd").REGION)
 if id in [&"cuero",&"hilo"]:return preload("res://scripts/container_art.gd").part({&"botella":0,&"botella_full":1,&"water":1,&"cuero":2,&"hilo":3}[id])
 if id==&"apple":return crop(preload("res://assets/items/apple.png"),Rect2(324,158,549,642))
 if id==&"piedra":
  var rocks:=preload("res://scripts/imported_nature.gd");return rocks.texture(rocks.ROCKS[0])
 if id==&"burdock_armor":return crop(preload("res://assets/items/burdock_armor_guide.png"),Rect2(1080,270,368,674))
 if id==&"hoja_bardana":return crop(preload("res://assets/items/burdock_leaf.png"),Rect2(57,156,1142,945))
 if id in [&"palo",&"cuerda"]:
  var index:=0 if id==&"palo" else 1;var record:Array=preload("res://assets/items/material_regions.gd").REGIONS[index]
  return crop(Legacy.MATERIALS,Rect2(record[0],record[1],record[2],record[3]))
 if id in [&"berries",&"ration"]:
  var index:=1 if id==&"berries" else 2;var record:Array=preload("res://assets/items/food_regions.gd").REGIONS[index]
  return crop(preload("res://assets/items/food.png"),Rect2(record[0],record[1],record[2],record[3]))
 return null
