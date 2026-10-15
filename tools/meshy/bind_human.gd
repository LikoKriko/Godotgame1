extends SceneTree
## Bake only skin weights and a uniform authoring transform. Positions, UVs,
## normals and triangle topology come from the user's FBX, exported as glTF.
const DEST="res://assets/characters/prototype_3d/meshy/survivor_skin.res"
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
 var bounds:=source.get_aabb();var factor:=64.0/bounds.size.y
 var translation:=Vector3(-bounds.get_center().x,-bounds.position.y,0)*factor+Vector3(0,0,2.6)
 for i in vertices.size():vertices[i]=vertices[i]*factor+translation
 arrays[Mesh.ARRAY_VERTEX]=vertices
 var normalized_hash:=digest(vertices.to_byte_array())
 var imported_bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 assert(not imported_bones.is_empty(),"Convert with the supplied bone-heat rig first")
 var imported_node:MeshInstance3D=nodes[0]
 var imported_skeleton:Skeleton3D=imported_node.get_node(imported_node.skeleton)
 var names:=["pelvis","chest","neck","head","upper_arm_0","forearm_0","hand_0","upper_arm_1","forearm_1","hand_1","thigh_0","shin_0","foot_0","thigh_1","shin_1","foot_1"]
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
 # Preserve hinge volume with the same collars used by the shared pose rig.
 var holder:=Node3D.new();root.add_child(holder)
 var dummy:=MeshInstance3D.new();holder.add_child(dummy)
 var rig=preload("res://scripts/prototype_3d/humanoid_rig.gd").new()
 rig.initialize_imported(holder,dummy)
 var final_bones:=PackedInt32Array();var final_weights:=PackedFloat32Array()
 var albedo:Image=(load("res://assets/characters/prototype_3d/meshy/albedo.png") as Texture2D).get_image()
 var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 for i in vertices.size():
  var influences:Dictionary={}
  for j in 4:
   var id:=bones[i*4+j];influences[id]=float(influences.get(id,0.0))+weights[i*4+j]
  for chain in 4:
   var start:int=[4,7,10,13][chain]
   var point:Vector3=vertices[i];var joint:Vector3=rig.rest[start+1].origin
   var axis:Vector3=rig.rest[start].origin.direction_to(rig.rest[start+2].origin)
   var total:float=float(influences.get(start,0.0))+float(influences.get(start+1,0.0))
   var collar_weight:float=(1-smoothstep(0.6,2.0,absf((point-joint).dot(axis))))*total
   if point.distance_to(joint)<3.6 and total>0.75 and collar_weight>0.001:
    var fraction:=collar_weight/total
    influences[start]=float(influences.get(start,0.0))*(1-fraction)
    influences[start+1]=float(influences.get(start+1,0.0))*(1-fraction)
    influences[20+chain]=collar_weight
  # Only the imported dark cloth receives the existing hem inertia controls.
  if vertices[i].y>23 and vertices[i].y<31:
   var uv:=uvs[i]
   var color:=albedo.get_pixel(clampi(int(uv.x*albedo.get_width()),0,albedo.get_width()-1),clampi(int(uv.y*albedo.get_height()),0,albedo.get_height()-1))
   if color.r<0.45 and color.g<0.45:
    var side:=0 if vertices[i].x<0 else 1
    var thigh:=10+side*3;var panel:=0 if vertices[i].z>=2 else 1
    var share:float=float(influences.get(thigh,0.0))*0.55*(1-smoothstep(27,31,vertices[i].y))
    influences[thigh]=float(influences.get(thigh,0.0))-share
    influences[16+side*2+panel]=share
  var order:Array=influences.keys()
  order.sort_custom(func(a,b):return influences[a]>influences[b])
  var total:=0.0
  for j in mini(4,order.size()):total+=influences[order[j]]
  for j in 4:
   final_bones.append(order[j] if j<order.size() else 0)
   final_weights.append(influences[order[j]]/total if j<order.size() else 0.0)
 arrays[Mesh.ARRAY_BONES]=final_bones;arrays[Mesh.ARRAY_WEIGHTS]=final_weights
 preload("res://scripts/prototype_3d/human_skin_weights.gd").correct(arrays)
 holder.free()
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var material:=StandardMaterial3D.new()
 var path:="res://assets/characters/prototype_3d/meshy/"
 material.albedo_texture=load(path+"albedo.png")
 material.normal_enabled=true;material.normal_texture=load(path+"normal.png")
 material.roughness_texture=load(path+"roughness.png");material.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic_texture=load(path+"metallic.png");material.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
 material.metallic=1;material.roughness=1
 material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
 mesh.surface_set_material(0,material)
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var triangle_count:=indices.size()/3 if not indices.is_empty() else vertices.size()/3
 assert(triangle_count==491218,"Preserve all original triangles")
 mesh.set_meta("torso_weight_profile","meshy_shoulders_v3")
 mesh.set_meta("source_zip_sha256","554eb761d7799caf1239e0a33f74e23846f61cd13eb1d71d5b55c03b6ae7767e")
 mesh.set_meta("normalized_positions_sha256",normalized_hash)
 mesh.set_meta("source_triangles",triangle_count)
 mesh.set_meta("source_bounds",bounds)
 mesh.set_meta("uniform_scale",factor)
 mesh.set_meta("translation",translation)
 mesh.set_meta("nose_tip",nose)
 mesh.set_meta("source_uv_sha256",digest((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).to_byte_array()))
 assert(ResourceSaver.save(mesh,DEST,ResourceSaver.FLAG_COMPRESS)==OK)
 print("Baked Meshy: vertices=",vertices.size()," triangles=",triangle_count," bounds=",mesh.get_aabb()," nose_tip=",nose," source geometry preserved")
 scene.free();quit()
