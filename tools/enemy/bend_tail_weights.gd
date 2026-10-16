extends SceneTree
func _initialize():
 var path:="res://assets/enemies/first/meshy/mossclaw_skin.res"
 var original:Mesh=load(path);var arrays:=original.surface_get_arrays(0)
 var changed:=preload("res://scripts/prototype_3d/young_skin_weights.gd").correct(arrays)
 var encoded:=ArrayMesh.new();encoded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var surfaces:Array=original.get("_surfaces").duplicate(true)
 var replacement:Array=encoded.get("_surfaces")
 assert(surfaces[0].format==replacement[0].format)
 surfaces[0].skin_data=replacement[0].skin_data;surfaces[0].bone_aabbs=replacement[0].bone_aabbs
 var mesh:=ArrayMesh.new();mesh.set("_surfaces",surfaces)
 for key in original.get_meta_list():mesh.set_meta(key,original.get_meta(key))
 mesh.set_meta("tail_hinge",true)
 assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
 print("Tail hinge: ",changed," weights; geometry and materials byte-preserved");quit()
