extends SceneTree
## Numerical preservation of approach/recovery plus contact-timed body impact.
var errors:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String) -> void:
 checks+=1
 if not ok and label not in errors:errors.append(label);push_error(label)
func record(actor,frame:float,previous:bool) -> Dictionary:
 actor.previous_clip=previous;actor.apply_clip((frame-1)/60.0)
 var n=actor.native;var points:Array[Vector3]=[];var knees:Array[float]=[];var ankles:Array[Basis]=[]
 for leg in n.legs:
  var ids:Array=leg.ids
  points.append(n.posed[ids[2]].origin*actor.SCALE)
  knees.append((n.posed[ids[1]].origin-n.posed[ids[0]].origin).angle_to(n.posed[ids[2]].origin-n.posed[ids[1]].origin))
  ankles.append(n.posed[ids[1]].basis.inverse()*n.posed[ids[2]].basis)
 for arm in n.arms:points.append(n.posed[arm.ids[3]].origin*actor.SCALE)
 return {"hip":n.posed[n.binding.bone(&"root")].origin.y*actor.SCALE,"points":points,"knees":knees,"ankles":ankles}
func run() -> void:
 var actor=load("res://scenes/prototype_3d/aren_blender_landing_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 var max_position:=0.0;var max_rotation:=0.0;var max_contact:=0.0
 for pair in [[actor.PilotClip,actor.PreviousClip],[actor.HeavyClip,actor.PreviousHeavyClip]]:
  var current:Animation=pair[0];var old:Animation=pair[1]
  check(is_equal_approx(current.length,old.length),"baked duration unchanged")
  for frame in range(1,157):
   if frame>48 and frame<60:continue
   var seconds:float=(frame-1)/60.0
   for track in current.get_track_count():
    match current.track_get_type(track):
     Animation.TYPE_POSITION_3D:
      var delta:float=current.position_track_interpolate(track,seconds).distance_to(old.position_track_interpolate(track,seconds))*actor.SCALE
      max_position=maxf(max_position,delta);check(delta<.00005,"body positions outside absorption preserved")
     Animation.TYPE_ROTATION_3D:
      var q:=current.rotation_track_interpolate(track,seconds).normalized()*old.rotation_track_interpolate(track,seconds).normalized().inverse()
      var angle:=2*atan2(Vector3(q.x,q.y,q.z).length(),absf(q.w))
      max_rotation=maxf(max_rotation,angle);check(angle<.00001,"body orientations outside absorption preserved")
     Animation.TYPE_SCALE_3D:check(current.scale_track_interpolate(track,seconds).is_equal_approx(old.scale_track_interpolate(track,seconds)),"bone and hand scale preserved")
 for height in [3.0,5.5,7.9]:
  actor.review_height=height;actor.begin_preview("idle_to_fall")
  var before:=record(actor,52,true);var compressed:=record(actor,52,false)
  check(before.hip-compressed.hip>.015,"reactive pelvis compression at "+str(height))
  check(compressed.knees[1]-before.knees[1]>deg_to_rad(1),"front knee reacts against fixed foot")
  var ankle:Quaternion=compressed.ankles[1].orthonormalized().get_rotation_quaternion()
  check(ankle.angle_to(before.ankles[1].orthonormalized().get_rotation_quaternion())>deg_to_rad(1),"ankle flexion accompanies knee absorption")
  var previous_height:float=record(actor,48,false).hip
  for half_frame in range(97,121):
   var frame:float=half_frame*.5
   var current:=record(actor,frame,false)
   if frame<=54:check(current.hip<=previous_height+.00001,"single controlled compression")
   else:check(current.hip>=previous_height-.00001,"no second impact during release")
   previous_height=current.hip
   var old:=record(actor,frame,true)
   for point in 4:
    var delta:float=current.points[point].distance_to(old.points[point]);max_contact=maxf(max_contact,delta)
    # Native linear sampling of local rotations adds sub-millimetre curvature
    # between Blender bake samples; integer-frame contact targets stay exact.
    var tolerance:=.0001 if is_equal_approx(frame,roundf(frame)) else .0005
    check(delta<tolerance,"authored feet and palm/hand paths preserved")
  actor.previous_clip=false;actor.begin_preview("idle_to_fall")
  var impact:float=actor.Fall.LEAD_IN+actor.Fall.flight_duration(height)
  var scale:float=actor.landing_profile().scale
  actor.advance_jump_preview(impact+.1*scale)
  check(actor.preview_stage=="landing" and absf(actor.stage_time-.1*scale)<.00001,"compression synchronized with physical ground contact")
 actor.free()
 print("ABSORPTION ",checks," checks; preserved position max ",max_position," m; rotation ",rad_to_deg(max_rotation)," deg; contact target max ",max_contact," m; failures ",errors)
 quit(0 if errors.is_empty() else 1)
