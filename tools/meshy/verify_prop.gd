extends SceneTree
## Independently compare every source triangle corner after the recorded transform.
func _initialize():call_deferred("run")
func run() -> void:
 var args:=OS.get_cmdline_user_args();var mesh:Mesh=load(args[0])
 var document:=GLTFDocument.new();var state:=GLTFState.new();assert(document.append_from_file(args[1],state)==OK)
 var scene:=document.generate_scene(state);var node:MeshInstance3D=scene.find_children("*","MeshInstance3D",true,false)[0]
 var raw:=node.mesh.surface_get_arrays(0);var native:=mesh.surface_get_arrays(0)
 var indices:PackedInt32Array=raw[Mesh.ARRAY_INDEX];var result:PackedInt32Array=native[Mesh.ARRAY_INDEX]
 assert(indices.size()==result.size())
 var position_error:=0.0;var uv_error:=0.0
 var rotation:Basis=mesh.get_meta("rotation");var factor:float=mesh.get_meta("uniform_scale");var offset:Vector3=mesh.get_meta("translation")
 for i in indices.size():
  var source:int=indices[i];var target:int=result[i]
  position_error=maxf(position_error,(rotation*raw[Mesh.ARRAY_VERTEX][source]*factor+offset).distance_to(native[Mesh.ARRAY_VERTEX][target]))
  uv_error=maxf(uv_error,raw[Mesh.ARRAY_TEX_UV][source].distance_to(native[Mesh.ARRAY_TEX_UV][target]))
 assert(position_error<.000002 and uv_error<.000002)
 print("PASS: ",indices.size()/3," source triangles; position error ",position_error,"; UV error ",uv_error)
 scene.free();quit()
