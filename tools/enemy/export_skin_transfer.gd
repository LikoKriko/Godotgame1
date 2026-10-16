extends SceneTree
## Export the existing native skin as a donor; no runtime behavior changes.
func _initialize():
 var args:=OS.get_cmdline_user_args();assert(args.size()==2,"Pass donor.res output_folder")
 var mesh:Mesh=load(args[0]);var arrays:=mesh.surface_get_arrays(0)
 DirAccess.make_dir_recursive_absolute(args[1])
 for record in [["positions",Mesh.ARRAY_VERTEX],["indices",Mesh.ARRAY_INDEX],["bones",Mesh.ARRAY_BONES],["weights",Mesh.ARRAY_WEIGHTS]]:
  var file:=FileAccess.open(args[1].path_join(record[0]+".bin"),FileAccess.WRITE)
  file.store_buffer(arrays[record[1]].to_byte_array());file.close()
 var file:=FileAccess.open(args[1].path_join("donor.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"sha256":FileAccess.get_sha256(args[0]),"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"triangles":arrays[Mesh.ARRAY_INDEX].size()/3}));file.close()
 print("Exported donor: ",arrays[Mesh.ARRAY_VERTEX].size()," vertices, ",arrays[Mesh.ARRAY_INDEX].size()/3," triangles")
 quit()
