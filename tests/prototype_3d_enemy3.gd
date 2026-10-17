extends SceneTree
const Actor=preload("res://scripts/prototype_3d/sprout_model.gd")
var checks:=0
var failures:=0
func check(value:bool,message:String) -> void:
 checks+=1
 if not value:
  failures+=1
  if failures<=10:push_error(message)
func _initialize():call_deferred("run")
func run() -> void:
 var actor:=Actor.new();root.add_child(actor)
 var other:=Actor.new();root.add_child(other)
 check(actor.skeleton!=other.skeleton,"Each actor owns its skeleton")
 check(actor.mesh_node.mesh==other.mesh_node.mesh,"Mesh is shared")
 check(actor.bind.size()==35,"All supplied bones including end bones survive")
 var mesh:=actor.mesh_node.mesh;var arrays:=mesh.surface_get_arrays(0)
 check(arrays[Mesh.ARRAY_INDEX].size()/3==13582,"Original triangle count")
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
 var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES]
 var influence_count:int=weights.size()/vertices.size()
 check(influence_count==8,"Use eight source influences instead of truncating to four")
 for v in vertices.size():
  var total:=0.0
  for j in influence_count:
   total+=weights[v*influence_count+j]
   check(bones[v*influence_count+j]>=0 and bones[v*influence_count+j]<35,"Valid bone bind")
  check(absf(total-1)<.0001,"Normalized weights")
 var material:StandardMaterial3D=actor.mesh_node.material_override
 var textures:=[material.albedo_texture,material.normal_texture,material.roughness_texture,material.metallic_texture]
 for i in textures.size():
  check(textures[i]!=null and textures[i].get_width()==(2048 if i<2 else 4096),"Original texture is linked")
 check(material.normal_enabled,"Normal map is active")
 check(material.texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS,"Pixel-preserving sampling with mipmaps")
 actor.animate(.31,0)
 for i in 35:check(actor.posed[i].is_equal_approx(actor.bind[i]),"Rest mode preserves authored pose")
 var skin:=actor.mesh_node.skin
 var matrices:Array[Transform3D]=[]
 var lowest:=100.0;var previous:Array[Vector3]=[]
 for sample in 241:
  var phase:=sample/240.0;actor.animate(phase)
  for i in 35:
   var local:Transform3D=actor.posed[actor.parents[i]].affine_inverse()*actor.posed[i] if actor.parents[i]>=0 else actor.posed[i]
   check(absf(local.origin.length()-actor.local_bind[i].origin.length())<.00002 or actor.parents[i]<0,"Bone lengths stay fixed")
   check(local.basis.get_scale().distance_to(actor.local_bind[i].basis.get_scale())<.00002,"No scaling bones")
   if not previous.is_empty():check(previous[i].distance_to(actor.posed[i].origin)<.015,"Continuous trajectory")
  for contact in actor.contacts:
   var actual:Vector3=actor.posed[contact.foot].origin
   check(actual.distance_to(contact.target)<.00002,"IK reaches foot target")
   check(absf(actual.y-actor.bind[contact.foot].origin.y)<.00002 if contact.stance else actual.y>=actor.bind[contact.foot].origin.y-.00002,"Support foot stays level; swing lifts")
  if sample%10==0:
   matrices.clear()
   for i in skin.get_bind_count():matrices.append(actor.skeleton.global_transform*actor.posed[skin.get_bind_bone(i)]*skin.get_bind_pose(i))
   for v in vertices.size():
    var p:=Vector3.ZERO
    for j in influence_count:p+=(matrices[bones[v*influence_count+j]]*vertices[v])*weights[v*influence_count+j]
    check(p.is_finite(),"Finite deformed geometry")
    lowest=minf(lowest,p.y)
  previous.clear()
  for transform in actor.posed:previous.append(transform.origin)
 actor.animate(0);var start:Array[Transform3D]=actor.posed.duplicate();actor.animate(1)
 for i in 35:check(start[i].is_equal_approx(actor.posed[i]),"Loop closes")
 check(lowest>-.012,"Visible feet do not penetrate ground by more than 12 mm")
 print("Enemy3: ",checks," checks; lowest skin point ",lowest," m")
 var saved=load("res://scenes/prototype_3d/enemy3.tscn").instantiate();root.add_child(saved)
 var player:AnimationPlayer=saved.get_node("AnimationPlayer")
 var saved_rig:Skeleton3D=saved.find_children("*","Skeleton3D",true,false)[0]
 check(player.has_animation("walk"),"Reusable scene exposes walk")
 check(player.get_animation("walk").loop_mode==Animation.LOOP_LINEAR,"Saved clip loops")
 for sample in 121:
  var p:=sample/120.0
  actor.animate(p);player.play("walk");player.seek(p*Actor.CYCLE_SECONDS,true);player.pause()
  for i in 35:
   var transform:=saved_rig.get_bone_global_pose(i)
   check(transform.origin.distance_to(actor.posed[i].origin)<.0008,"Saved clip matches IK within 0.8 mm")
   var parent:int=actor.parents[i]
   var local:Transform3D=saved_rig.get_bone_global_pose(parent).affine_inverse()*transform if parent>=0 else transform
   check(absf(local.origin.length()-actor.local_bind[i].origin.length())<.00002 or parent<0,"Saved clip keeps bone lengths")
 player.play("RESET");player.seek(0,true);player.pause()
 for i in 35:check(saved_rig.get_bone_global_pose(i).origin.distance_to(actor.bind[i].origin)<.00002,"RESET restores the authored pose")
 print("Saved clip: ",checks," total checks; ",failures," failures")
 actor.queue_free();other.queue_free();saved.queue_free();await process_frame;quit(0 if failures==0 else 1)
