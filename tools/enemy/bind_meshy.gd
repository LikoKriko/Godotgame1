extends SceneTree
## Bake only skin weights and a uniform authoring transform. Positions, UVs,
## normals and triangle topology come from the user's FBX, exported as glTF.
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
const DEST="res://assets/enemies/first/meshy/mossclaw_skin.res"
func _initialize():call_deferred("run")
func digest(bytes:PackedByteArray) -> String:
 var context:=HashingContext.new();context.start(HashingContext.HASH_SHA256);context.update(bytes);return context.finish().hex_encode()
func run():
 var args:=OS.get_cmdline_user_args()
 if args.is_empty():push_error("Pass -- /absolute/path/to/source.glb");quit(1);return
 var document:=GLTFDocument.new();var state:=GLTFState.new()
 if document.append_from_file(args[0],state)!=OK:quit(1);return
 var scene:=document.generate_scene(state);root.add_child(scene)
 var nodes:=scene.find_children("*","MeshInstance3D",true,false)
 assert(nodes.size()==1,"The supplied FBX contains exactly one mesh")
 var source:Mesh=nodes[0].mesh
 assert(source.get_surface_count()==1)
 # MikkTSpace tangents permit the supplied normal map; no remeshing/decimation.
 var surface:=SurfaceTool.new();surface.create_from(source,0);surface.generate_tangents()
 var prepared:=surface.commit()
 var arrays:Array=prepared.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var bounds:=source.get_aabb();var factor:=32.0/bounds.size.y
 var translation:=Vector3(-bounds.get_center().x,-bounds.position.y,0)*factor
 for i in vertices.size():vertices[i]=vertices[i]*factor+translation
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var normalized_hash:=digest(vertices.to_byte_array())
 var imported_bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 assert(not imported_bones.is_empty(),"Convert with the supplied bone-heat rig first")
 var imported_node:MeshInstance3D=nodes[0]
 var imported_skeleton:Skeleton3D=imported_node.get_node(imported_node.skeleton)
 var names:=["body","head","thigh_0","shin_0","foot_0","thigh_1","shin_1","foot_1","upper_arm_0","forearm_0","fist_0","upper_arm_1","forearm_1","fist_1"]
 var remap:Dictionary={}
 for i in imported_node.skin.get_bind_count():
  var name:=String(imported_node.skin.get_bind_name(i))
  if name.is_empty():name=imported_skeleton.get_bone_name(imported_node.skin.get_bind_bone(i))
  assert(names.has(name),"Unexpected source bone: "+name)
  remap[i]=names.find(name)
 var bones:=PackedInt32Array()
 for id in imported_bones:bones.append(remap[id])
 var nose:=Vector3(0,0,-INF)
 for point in vertices:
  if absf(point.x)<0.5 and point.z>nose.z:nose=point
 for i in vertices.size():
  var total:=0.0
  for j in 4:total+=weights[i*4+j]
  assert(total>0.0001,"Every imported vertex must be bound")
  for j in 4:weights[i*4+j]/=total
 arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
 preload("res://scripts/prototype_3d/young_skin_weights.gd").correct(arrays)
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new()
 var path:="res://assets/enemies/first/meshy/"
 material.albedo_texture=load(path+"albedo.png")
 material.normal_enabled=true;material.normal_texture=load(path+"normal.png")
 material.roughness_texture=load(path+"roughness.png");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic_texture=load(path+"metallic.png");material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic=1;material.roughness=1
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 mesh.surface_set_material(0,material)
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var triangle_count:=indices.size()/3 if not indices.is_empty() else vertices.size()/3
 assert(triangle_count==977782,"Preserve all original triangles")
 mesh.set_meta("tail_hinge",true)
 mesh.set_meta("source_zip_sha256","f0af7cc7091dfa1c6219a23b6c609e695a1a7dae90206889fab21802ed4c3655")
 mesh.set_meta("normalized_positions_sha256",normalized_hash)
 mesh.set_meta("source_triangles",triangle_count)
 mesh.set_meta("source_bounds",bounds)
 mesh.set_meta("uniform_scale",factor)
 mesh.set_meta("translation",translation)
 mesh.set_meta("nose_tip",nose)
 mesh.set_meta("source_uv_sha256",digest((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).to_byte_array()))
 assert(ResourceSaver.save(mesh,DEST,ResourceSaver.FLAG_COMPRESS)==OK)
 print("Baked Meshy: vertices=",vertices.size()," triangles=",triangle_count," bounds=",mesh.get_aabb()," nose_tip=",nose," nose_offset=",nose-Motion.HEAD_ANCHOR)
 scene.free();quit()
