extends SceneTree
## Verify that the in-game asset is the user's Meshy mesh, with original UVs and
## PNGs, rather than the removed procedural reconstruction.
const Model=preload("res://scripts/prototype_3d/young_model.gd")
const Motion=preload("res://scripts/prototype_3d/young_pose.gd")
var checks:=0
var failures:=0
func require(value:bool,message:String) -> void:
 checks+=1
 if not value:failures+=1;push_error(message)
func digest(bytes:PackedByteArray) -> String:
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func _initialize():call_deferred("run")
func deform(point:Vector3,index:int,ids:PackedInt32Array,weights:PackedFloat32Array,actor:Node3D) -> Vector3:
 var result:=Vector3.ZERO
 for slot in 4:
  var bone:=ids[index*4+slot]
  result+=(actor.posed[bone]*(actor.rest[bone].affine_inverse()*point))*weights[index*4+slot]
 return result
func run():
 var actor:=Model.new();root.add_child(actor)
 var second:=Model.new();root.add_child(second)
 var mesh:Mesh=actor.mesh_node.mesh
 var data:=mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=data[Mesh.ARRAY_VERTEX]
 var uv:PackedVector2Array=data[Mesh.ARRAY_TEX_UV]
 var indices:PackedInt32Array=data[Mesh.ARRAY_INDEX]
 var bones:PackedInt32Array=data[Mesh.ARRAY_BONES]
 var weights:PackedFloat32Array=data[Mesh.ARRAY_WEIGHTS]
 var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/enemies/first/meshy/source.json"))
 require(mesh==second.mesh_node.mesh,"All enemies share the imported mesh resource")
 require(actor.skeleton!=second.skeleton,"Each imported creature has an independent skeleton")
 require(FileAccess.get_sha256(manifest.source_fbx_path)==manifest.source_fbx_sha256,"The original FBX is retained byte-for-byte for the animation department")
 require(mesh.get_meta("source_zip_sha256")==manifest.source_zip_sha256,"Runtime asset identifies the verified user archive")
 require(indices.size()/3==977782,"Every original Meshy triangle is retained")
 require(digest(vertices.to_byte_array())==mesh.get_meta("normalized_positions_sha256"),"Baked skin keeps every imported position after the uniform normalization")
 require(digest(uv.to_byte_array())==mesh.get_meta("source_uv_sha256"),"Original texture coordinates survive skin binding")
 var original:AABB=mesh.get_meta("source_bounds")
 require((mesh.get_aabb().size-original.size*float(mesh.get_meta("uniform_scale"))).length()<0.0001,"Normalization preserves all three source proportions")
 require(absf(mesh.get_aabb().size.y-32)<0.0001,"The source mesh uses a consistent authoring height")
 var material:StandardMaterial3D=actor.body_material
 var maps:={"albedo.png":material.albedo_texture,"normal.png":material.normal_texture,"roughness.png":material.roughness_texture,"metallic.png":material.metallic_texture}
 for filename in maps:
  var path:String="res://assets/enemies/first/meshy/"+String(filename)
  require(FileAccess.get_sha256(path)==manifest.textures[filename].sha256,"Original PNG remains byte-identical: "+filename)
  require(maps[filename]!=null and maps[filename].resource_path==path,"The in-game material uses "+filename)
 require(material.normal_enabled,"Original UV material replaces procedural projection shaders")
 require(not FileAccess.file_exists("res://scripts/prototype_3d/young_reference_mesh.gd"),"The rejected procedural geometry is removed")
 var valid:=bones.size()==vertices.size()*4 and weights.size()==bones.size()
 var probes:Array[int]=[]
 for i in vertices.size():
  var sum:=0.0
  valid=valid and vertices[i].is_finite() and uv[i].is_finite()
  for j in 4:
   sum+=weights[i*4+j]
   valid=valid and bones[i*4+j]>=0 and bones[i*4+j]<15 and weights[i*4+j]>=0
  valid=valid and absf(sum-1)<0.0001
  if i%503==0:probes.append(i)
 require(valid,"Every source vertex has finite coordinates, UVs and normalized four-bone bindings")
 actor.animate(&"reference",0,true)
 var error:=0.0
 for i in probes:error=maxf(error,vertices[i].distance_to(deform(vertices[i],i,bones,weights,actor)))
 require(error<0.001,"Reference stance reproduces the supplied geometry without deformation")
 var independent:Transform3D=second.skeleton.get_bone_pose(0)
 for state in preload("res://scripts/prototype_3d/animation_review.gd").YOUNG_STATES:
  for left in [false,true]:
   for frame in 17:
    actor.animate(state,frame/16.0,left)
    var finite:=true
    for i in probes:
     var p:=deform(vertices[i],i,bones,weights,actor)
     finite=finite and p.is_finite() and p.length()<100
    require(finite,"Imported skin remains finite in %s / %s / %d"%[state,left,frame])
    for side in 2:
     var start:=8+side*3
     require(absf(actor.posed[start].origin.distance_to(actor.posed[start+1].origin)-Motion.ARM_A)<0.001,"Upper arm retains its bone length")
     require(absf(actor.posed[start+1].origin.distance_to(actor.posed[start+2].origin)-Motion.ARM_B)<0.001,"Forearm retains its bone length")
 require(actor.mesh_node.mesh==mesh,"Actions never rebuild or replace the Meshy surface")
 require(second.skeleton.get_bone_pose(0).is_equal_approx(independent),"Animating one enemy cannot move a second enemy")
 print("Meshy vertices=",vertices.size()," triangles=",indices.size()/3)
 actor.free();second.free()
 print("%s: %d imported Meshy, source integrity, material and skin checks"%["PASS" if failures==0 else "FAIL",checks])
 quit(1 if failures else 0)
