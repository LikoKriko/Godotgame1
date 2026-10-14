extends SceneTree
const Style = preload("res://scripts/visual_style.gd")
func _initialize():
 var source := preload("res://assets/items/basic_materials.png")
 var regions: Array = preload("res://assets/items/material_regions.gd").REGIONS
 var a := AtlasTexture.new(); a.atlas = source; a.region = Rect2(regions[0][0],regions[0][1],regions[0][2],regions[0][3])
 var b := AtlasTexture.new(); b.atlas = source; b.region = Rect2(regions[1][0],regions[1][1],regions[1][2],regions[1][3])
 var first := Style.normalized(a,Vector2(24,24)); var second := Style.normalized(b,Vector2(24,24))
 if first == second: push_error("Different atlas crops incorrectly share the same icon"); quit(1); return
 var copy := AtlasTexture.new(); copy.atlas = source; copy.region = a.region
 if Style.normalized(copy,Vector2(24,24)) != first: push_error("Equivalent crops should still reuse their icon resource"); quit(1); return
 print("PASS: distinct crops remain distinct; equivalent crops reuse the cached icon");quit()
