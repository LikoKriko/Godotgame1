extends RefCounted
## Validate playback, not control intent. Skin checks include knee morphs.
const SCALE=1.75/64.0
func validate(model:Node3D,player:AnimationPlayer,name:StringName) -> Dictionary:
 var skeleton:Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
 var mesh:MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
 var clip:Animation=player.get_animation(name)
 var root:Node3D=player.get_node(player.root_node)
 var frame:Transform3D=root.global_transform.affine_inverse()*skeleton.global_transform
 var info:Dictionary=clip.get_meta("cycle")
 var errors:Array[String]=[]
 var min_floor:=INF;var max_slip:=0.0;var max_length:=0.0;var max_loop:=0.0
 var first:Array[Transform3D]=[];var rest_lengths:Array[float]=[]
 var previous:Array[Vector3]=[]
 var surfaces:Array=[];var shapes:Array=[]
 for s in mesh.mesh.get_surface_count():surfaces.append(mesh.mesh.surface_get_arrays(s));shapes.append(mesh.mesh.surface_get_blend_shape_arrays(s))
 for bone in skeleton.get_bone_count():rest_lengths.append(skeleton.get_bone_rest(bone).origin.length())
 for index in range(241):
  var phase:=index/240.0
  player.play(name);player.seek(phase*clip.length,true);skeleton.force_update_all_bone_transforms()
  for bone in skeleton.get_bone_count():
   var local:Transform3D=skeleton.get_bone_pose(bone)
   if not local.is_finite():errors.append("Nonfinite bone pose");break
   var expected:float=rest_lengths[bone]
   if skeleton.get_bone_parent(bone)>=0:max_length=maxf(max_length,absf(local.origin.length()-expected))
   if index==0:first.append(local)
   elif index==240:
    max_loop=maxf(max_loop,local.origin.distance_to(first[bone].origin))
    max_loop=maxf(max_loop,local.basis.orthonormalized().get_rotation_quaternion().angle_to(first[bone].basis.orthonormalized().get_rotation_quaternion()))
  var feet:Array[Vector3]=[]
  for side in 2:
   var bone:=skeleton.find_bone("smartrig_"+("Right" if side==0 else "Left")+"Foot")
   feet.append(frame*skeleton.get_bone_global_pose(bone).origin*SCALE)
   if info.has("support") and not previous.is_empty():
    var contact:=fposmod(phase+side*.5,1.0)
    if contact>.03 and contact<info.support-.03:
     var velocity:Vector3=(feet[side]-previous[side])/(clip.length/240.0)+Vector3.BACK*info.speed_mps
     max_slip=maxf(max_slip,Vector2(velocity.x,velocity.z).length())
  previous=feet
  var matrices:Array[Transform3D]=[]
  for bind in mesh.skin.get_bind_count():matrices.append(frame*skeleton.get_bone_global_pose(mesh.skin.get_bind_bone(bind))*mesh.skin.get_bind_pose(bind))
  # Sample the actual skin at eight evenly spaced frames and the seam.
  if index%30!=0:continue
  for s in surfaces.size():
   var arrays:Array=surfaces[s];var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
   var slots:int=ids.size()/vertices.size()
   for vertex in vertices.size():
    var source:Vector3=vertices[vertex]
    for shape in shapes[s].size():source+=(shapes[s][shape][Mesh.ARRAY_VERTEX][vertex]-vertices[vertex])*mesh.get_blend_shape_value(shape)
    var point:=Vector3.ZERO
    for slot in slots:
     var offset:=vertex*slots+slot
     if weights[offset]>0:point+=(matrices[ids[offset]]*source)*weights[offset]
    if not point.is_finite():errors.append("Nonfinite deformed skin")
    min_floor=minf(min_floor,point.y*SCALE)
 if max_length>.0001:errors.append("Changed native local bone lengths")
 if max_loop>.002:errors.append("Loop discontinuity")
 if max_slip>.06:errors.append("Support sliding exceeds 6 cm/s")
 if min_floor<-.004:errors.append("Skin penetrates the floor by more than 4 mm")
 return {"ok":errors.is_empty(),"errors":errors,"floor_min_m":min_floor,"max_slip_mps":max_slip,"max_length_error_native":max_length,"max_loop_error":max_loop,"samples":241,"skin_samples":9,"visual_review":"required_separately"}
