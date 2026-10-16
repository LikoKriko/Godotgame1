extends SceneTree
## Independent comparison against an unrigged export of the original FBX.
## Godot --headless --script tools/meshy/verify_source.gd -- source.glb native.res
func _initialize():call_deferred("run")
func digest(bytes:PackedByteArray) -> String:
 var h:=HashingContext.new();h.start(HashingContext.HASH_SHA256);h.update(bytes);return h.finish().hex_encode()
func run():
 var args:=OS.get_cmdline_user_args();assert(args.size()==2)
 var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_file(args[0],state)==OK)
 var scene:=doc.generate_scene(state);root.add_child(scene)
 var nodes:=scene.find_children("*","MeshInstance3D",true,false);assert(nodes.size()==1)
 var surface:=SurfaceTool.new();surface.create_from(nodes[0].mesh,0);surface.generate_tangents()
 var original:=surface.commit().surface_get_arrays(0)
 var mesh:Mesh=load(args[1]);var actual:=mesh.surface_get_arrays(0)
 var points:PackedVector3Array=original[Mesh.ARRAY_VERTEX]
 var factor:float=mesh.get_meta("uniform_scale");var offset:Vector3=mesh.get_meta("translation")
 var rotation:Basis=mesh.get_meta("rotation",Basis.IDENTITY)
 for i in points.size():points[i]=rotation*points[i]*factor+offset
 var actual_points:PackedVector3Array=actual[Mesh.ARRAY_VERTEX]
 assert(points.size()==actual_points.size(),"Source vertex count must match")
 var max_position_error:=0.0;var max_normal_error:=0.0;var max_uv_error:=0.0
 var uv:PackedVector2Array=original[Mesh.ARRAY_TEX_UV];var actual_uv:PackedVector2Array=actual[Mesh.ARRAY_TEX_UV]
 var normals:PackedVector3Array=original[Mesh.ARRAY_NORMAL];var actual_normals:PackedVector3Array=actual[Mesh.ARRAY_NORMAL]
 for i in points.size():
  max_position_error=maxf(max_position_error,points[i].distance_to(actual_points[i]))
  max_uv_error=maxf(max_uv_error,uv[i].distance_to(actual_uv[i]))
  max_normal_error=maxf(max_normal_error,(rotation*normals[i]).distance_to(actual_normals[i]))
 print("Source comparison: vertices=",points.size()," max position error=",max_position_error," max UV error=",max_uv_error," max normal error=",max_normal_error)
 assert(max_position_error<0.002,"Every source position must be preserved within Godot mesh packing precision")
 assert(max_uv_error<0.00003,"Every source UV must be preserved")
 assert((original[Mesh.ARRAY_INDEX] as PackedInt32Array)==(actual[Mesh.ARRAY_INDEX] as PackedInt32Array),"Every source triangle must be preserved")
 assert(max_normal_error<0.006,"Every source normal must be preserved within Godot mesh packing precision")
 print("PASS: independent source identity: positions, UVs, normals and triangle indices match ",args[1])
 scene.free();quit()
