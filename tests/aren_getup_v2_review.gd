extends "res://tests/aren_extreme_review.gd"
## New clip, actual skinned floor envelope, support stability and preserved phases.
var blend_surfaces:Array=[]
func actual_skin_floor(actor:Node3D) -> float:
 var transforms:Array[Transform3D]=[]
 for bind in actor.native.mesh.skin.get_bind_count():
  transforms.append(actor.global_transform*actor.native.posed[actor.native.mesh.skin.get_bind_bone(bind)]*actor.native.mesh.skin.get_bind_pose(bind))
 var minimum:=INF
 for surface in surfaces.size():
  var arrays:Array=surfaces[surface];var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=bones.size()/vertices.size()
  for vertex in vertices.size():
   var p:Vector3=vertices[vertex]
   for shape in blend_surfaces[surface].size():
    var weight:float=actor.native.mesh.get_blend_shape_value(shape)
    if is_zero_approx(weight):continue
    var morph:Vector3=blend_surfaces[surface][shape][Mesh.ARRAY_VERTEX][vertex]
    p+=(morph if actor.native.mesh.mesh.blend_shape_mode==Mesh.BLEND_SHAPE_MODE_RELATIVE else morph-vertices[vertex])*weight
   var point:=Vector3.ZERO
   for slot in slots:
    var at:=vertex*slots+slot
    if weights[at]>0:point+=(transforms[bones[at]]*p)*weights[at]
   minimum=minf(minimum,point.y)
 return minimum
func run() -> void:
 var actor=load("res://scenes/prototype_3d/aren_getup_v2_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false);actor.position=Vector3.ZERO
 var old=load("res://scenes/prototype_3d/aren_extreme_review_actor.tscn").instantiate();root.add_child(old);old.set_process(false);old.position=Vector3.ZERO
 check(actor.native.skeleton.get_bone_count()==66,"original rig")
 check(is_equal_approx(actor.END-actor.GETUP,6.25),"independent getup duration")
 check(actor.GetupClip.get_meta("whole_body_keys").size()==12,"twelve authored whole-body poses")
 for frame in 145:
  var t:=frame/60.0;actor.apply_extreme(t);old.apply_extreme(t)
  for bone in 66:check(actor.native.posed[bone].is_equal_approx(old.native.posed[bone]),"preceding phases unchanged")
 actor.set_getup_variant(false)
 for t in [2.5,3.5,6.0,10.4]:
  actor.apply_extreme(t);old.apply_extreme(t)
  for bone in 66:check(actor.native.posed[bone].is_equal_approx(old.native.posed[bone]),"Anterior retains original getup")
 actor.set_getup_variant(true)
 for surface in actor.native.mesh.mesh.get_surface_count():
  var arrays:Array=actor.native.mesh.mesh.surface_get_arrays(surface);surfaces.append(arrays)
  blend_surfaces.append(actor.native.mesh.mesh.surface_get_blend_shape_arrays(surface))
 var previous:Array[Transform3D]=[];var hand_start:Array[Vector3]=[];var foot_start:Dictionary={}
 var idle=actor.sampler.sample("idle",0)
 actor.contact_writer.restore(actor,idle.poses)
 var flat:Array[Quaternion]=[]
 for leg in actor.native.legs:flat.append(actor.native.posed[leg.ids[2]].basis.orthonormalized().get_rotation_quaternion())
 var rate:float=.25 if "--quarter" in OS.get_cmdline_user_args() else 1.0
 for tick in int(6.25*60/rate)+1:
  var t:float=minf(tick*rate/60,6.25);actor.apply_extreme(actor.GETUP+t)
  for pose in actor.native.posed:check(pose.is_finite(),"finite pose")
  for chain in actor.native.legs+actor.native.arms:
   var first:int=0 if chain.ids.size()==3 else 1
   var a:Vector3=actor.native.posed[chain.ids[first]].origin;var b:Vector3=actor.native.posed[chain.ids[first+1]].origin;var c:Vector3=actor.native.posed[chain.ids[first+2]].origin
   check(absf(a.distance_to(b)-chain.a)*actor.SCALE<.0002 and absf(b.distance_to(c)-chain.b)*actor.SCALE<.0002,"native limb lengths")
   check(rad_to_deg((b-a).angle_to(c-b))<155,"anatomical elbow and knee flexion")
  if not previous.is_empty():
   for bone in 66:
    var parent:int=actor.native.parents[bone]
    var before:Transform3D=previous[parent].affine_inverse()*previous[bone] if parent>=0 else previous[bone]
    var after:Transform3D=actor.native.posed[parent].affine_inverse()*actor.native.posed[bone] if parent>=0 else actor.native.posed[bone]
    var angle:float=rad_to_deg(before.basis.orthonormalized().get_rotation_quaternion().angle_to(after.basis.orthonormalized().get_rotation_quaternion()))
    worst_angle=maxf(worst_angle,angle)
    check(angle<12*rate+.2,"continuous joint %s at %.4f (%.2f°)"%[actor.native.skeleton.get_bone_name(bone),t,angle])
  previous=actor.native.posed.duplicate()
  if t>=.75 and t<=2.4:
   var hands:Array[Vector3]=[]
   for arm in actor.native.arms:hands.append(actor.global_transform*actor.native.posed[arm.ids[3]].origin)
   if hand_start.is_empty():hand_start=hands.duplicate()
   for side in 2:check(Vector2(hands[side].x,hands[side].z).distance_to(Vector2(hand_start[side].x,hand_start[side].z))<.002,"planted palm %s at %.4f"%[side,t])
  for side in 2:
   var swing:Array=actor.getup_contacts.foot_swings[side]
   var loaded:bool=t>=float(actor.getup_contacts.feet[side]) and (t<float(swing[0]) or t>=float(swing[1]))
   if not loaded:foot_start.erase(side);continue
   var leg:Dictionary=actor.native.legs[side];var point:Vector3=actor.global_transform*actor.native.posed[leg.ids[2]].origin
   if not foot_start.has(side):foot_start[side]=point
   check(Vector2(point.x,point.z).distance_to(Vector2(foot_start[side].x,foot_start[side].z))<.002,"loaded soles stay planted")
   var shin:Vector3=(actor.native.posed[leg.ids[1]].origin-actor.native.posed[leg.ids[2]].origin).normalized()
   maximum_loaded_shin=maxf(maximum_loaded_shin,rad_to_deg(shin.angle_to(Vector3.UP)))
   check(rad_to_deg(shin.angle_to(Vector3.UP))<40,"loaded ankle %s at %.4f"%[side,t])
   check(rad_to_deg(actor.native.posed[leg.ids[2]].basis.orthonormalized().get_rotation_quaternion().angle_to(flat[side]))<3,"loaded sole orientation")
  var low:=actual_skin_floor(actor);lowest_skin=minf(lowest_skin,low);check(low>=-.002,"actual full mesh clears floor at "+str(t))
 actor.apply_extreme(actor.END)
 var ended:Array[Transform3D]=actor.native.posed.duplicate();actor.contact_writer.restore(actor,idle.poses)
 for bone in 66:check(ended[bone].is_equal_approx(actor.native.posed[bone]),"exact approved Idle")
 old.free() # Remove its preview collider before testing the real floor.
 await physics_frame
 for outcome in ["survive","die"]:
  actor.outcome=outcome;actor.review_height=8;actor.begin_preview("idle_to_fall")
  for tick in int(700/rate):
   actor.advance_jump_preview(rate/60)
   if actor.preview_done:break
  check(actor.impact_events==1,"single physical impact")
  check(actor.position.y<.003,"impact is against the physical floor")
  check(actor.preview_stage==("idle" if outcome=="survive" else "prone"),"correct outcome "+outcome)
  check(actor.controls_locked==(outcome=="die"),"control lock follows outcome")
 actor.free()
 print("GETUP V2 ",checks," checks; rate ",rate,"; worst joint step ",worst_angle,"; loaded shin ",maximum_loaded_shin,"; full mesh floor ",lowest_skin,"; failures ",failures)
 quit(0 if failures.is_empty() else 1)
