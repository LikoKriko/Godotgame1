extends SceneTree
const BASE="res://assets/enemies/first/rig/"
func _initialize():call_deferred("run")
func run():
 var args:=OS.get_cmdline_user_args();assert(args.size()==1,"Pass the output directory from optimize_surface.py")
 var original_document:=GLTFDocument.new();var original_state:=GLTFState.new()
 assert(original_document.append_from_file("res://entregables/enemigos/enemigo1/source/Meshy_AI_Character_output.glb",original_state)==OK)
 var source:=original_document.generate_scene(original_state);root.add_child(source)
 var source_mesh:MeshInstance3D=source.find_children("*","MeshInstance3D",true,false)[0];var source_rig:Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
 var doc:=GLTFDocument.new();var state:=GLTFState.new();assert(doc.append_from_file(args[0]+"/low.glb",state)==OK)
 var imported:=doc.generate_scene(state);root.add_child(imported)
 var low:MeshInstance3D=imported.find_children("*","MeshInstance3D",true,false)[0];var rig:Skeleton3D=imported.find_children("*","Skeleton3D",true,false)[0]
 var arrays:=low.mesh.surface_get_arrays(0).duplicate(true)
 var mapping:Dictionary={}
 for i in source_mesh.skin.get_bind_count():mapping[source_rig.get_bone_name(source_mesh.skin.get_bind_bone(i))]=i
 var remap:Array[int]=[]
 for i in low.skin.get_bind_count():remap.append(mapping[rig.get_bone_name(low.skin.get_bind_bone(i))])
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 for i in bones.size():bones[i]=remap[bones[i]]
 arrays[Mesh.ARRAY_BONES]=bones
 var original_frame:=source_rig.global_transform*source_rig.get_bone_global_pose(source_mesh.skin.get_bind_bone(0))*source_mesh.skin.get_bind_pose(0)
 var low_frame:=rig.global_transform*rig.get_bone_global_pose(low.skin.get_bind_bone(0))*low.skin.get_bind_pose(0)
 var frame:=original_frame.affine_inverse()*low_frame
 print("FRAME ",frame)
 var points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 for i in points.size():points[i]=frame*points[i];normals[i]=(frame.basis*normals[i]).normalized()
 arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
 var temp:=ArrayMesh.new();temp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var tool:=SurfaceTool.new();tool.create_from(temp,0);tool.generate_tangents()
 var mesh:=tool.commit()
 var material:StandardMaterial3D=source_mesh.mesh.surface_get_material(0).duplicate()
 material.albedo_texture=load("res://assets/enemies/first/meshy/albedo.png")
 material.metallic_texture=load("res://assets/enemies/first/meshy/metallic_roughness.png");material.roughness_texture=material.metallic_texture
 material.normal_texture=load(BASE+"surface_normal.png");material.normal_enabled=true
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 mesh.surface_set_material(0,material)
 var original_bounds:=source_mesh.mesh.get_aabb()
 assert(mesh.get_aabb().position.distance_to(original_bounds.position)<.000002 and mesh.get_aabb().size.distance_to(original_bounds.size)<.000002)
 var authoring:Mesh=load("res://assets/enemies/first/meshy/mossclaw_skin.res")
 var factor:float=authoring.get_aabb().size.y/source_mesh.mesh.get_aabb().size.y
 var face_frame:=Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*factor),authoring.get_aabb().position-source_mesh.mesh.get_aabb().position*factor)
 var head:Array[int]=[]
 for i in source_mesh.skin.get_bind_count():
  if source_rig.get_bone_name(source_mesh.skin.get_bind_bone(i)) in ["Bone_016","Bone_015"]:head.append(i)
 var face:=preload("res://scripts/prototype_3d/young_face.gd").mesh(mesh,head,face_frame)
 assert(ResourceSaver.save(face,BASE+"face.res",ResourceSaver.FLAG_COMPRESS)==OK)
 source_mesh.mesh=mesh
 var packed:=PackedScene.new();assert(packed.pack(source)==OK)
 assert(ResourceSaver.save(packed,BASE+"model.scn",ResourceSaver.FLAG_COMPRESS)==OK)
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(BASE+"source.json"))
 manifest.source_geometry_preserved=false
 manifest.rig_method="Original joint hierarchy, bind axes and inverse bind matrices; existing skin weights interpolated on the reduced surface, without a replacement rig"
 manifest["optimization"]={"method":"Protected collapse with selected-to-active tangent-space normal bake","ratio":.55,"source_mesh_vertices":2020,"runtime_vertices":mesh.surface_get_array_len(0),"runtime_triangles":mesh.surface_get_array_index_len(0)/3,"facial_vertices":face.surface_get_array_len(0),"facial_surface_triangles":face.surface_get_array_index_len(0)/3,"protected_features":["head","soles","bounds"],"normal_map":"surface_normal.png","normal_map_size":2048,"normal_map_sha256":FileAccess.get_sha256(BASE+"surface_normal.png")}
 var file:=FileAccess.open(BASE+"source.json",FileAccess.WRITE);file.store_string(JSON.stringify(manifest,"  ")+"\n");file.close()
 print("LOW native vertices ",mesh.surface_get_array_len(0)," tris ",mesh.surface_get_array_index_len(0)/3," bounds ",mesh.get_aabb())
 print("FACE vertices ",face.surface_get_array_len(0)," triangles ",face.surface_get_array_index_len(0)/3)
 source.queue_free();imported.queue_free();await process_frame;quit()
