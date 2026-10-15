extends SceneTree
## Apply the torso correction to the shipped bind mesh; preserve every other array.
func _initialize():
 var path:="res://assets/characters/prototype_3d/meshy/survivor_skin.res"
 var original:Mesh=load(path)
 var arrays:=original.surface_get_arrays(0)
 var before:=arrays.duplicate(true)
 var changed:=preload("res://scripts/prototype_3d/human_skin_weights.gd").correct(arrays)
 for i in arrays.size():
  if i not in [Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:assert(var_to_bytes(before[i])==var_to_bytes(arrays[i]),"Only skin influences may change")
 # Retain packed vertex/normal/tangent/UV/index buffers byte-for-byte.
 # Rebuilding the whole surface would quantize octahedral normals a second time.
 var encoded:=ArrayMesh.new();encoded.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var surfaces:Array=original.get("_surfaces").duplicate(true)
 var replacement:Array=encoded.get("_surfaces")
 assert(surfaces[0].format==replacement[0].format)
 surfaces[0].skin_data=replacement[0].skin_data
 surfaces[0].bone_aabbs=replacement[0].bone_aabbs
 var mesh:=ArrayMesh.new();mesh.set("_surfaces",surfaces)
 for key in original.get_meta_list():mesh.set_meta(key,original.get_meta(key))
 mesh.set_meta("torso_weight_profile","meshy_torso_v1")
 assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
 print("Corrected torso influences on ",changed," vertices; original geometry, UV, normals and materials retained");quit()
