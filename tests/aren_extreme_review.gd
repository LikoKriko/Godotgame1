extends SceneTree
## Actual floor sweep, Blender clip continuity and both post-impact outcomes.
var failures:Array[String]=[]
var checks:=0
var timings:Array[float]=[]
var worst_angle:=0.0
var worst_at:=""
var lowest_skin:=0.0
var label:=""
var surfaces:Array=[]
var owners:Array[PackedInt32Array]=[]
func _initialize():call_deferred("run")
func check(ok:bool,message:String) -> void:
 checks+=1
 var text:=label+": "+message
 if not ok and text not in failures:failures.append(text);push_error(text)
func scan_skin(actor:Node3D) -> Vector4:
 var minima:=Vector4(INF,INF,INF,INF)
 var transforms:Array[Transform3D]=[]
 for bind in actor.native.mesh.skin.get_bind_count():
  transforms.append(actor.global_transform*actor.native.posed[actor.native.mesh.skin.get_bind_bone(bind)]*actor.native.mesh.skin.get_bind_pose(bind))
 for surface in surfaces.size():
  var arrays:Array=surfaces[surface]
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=bones.size()/vertices.size()
  for vertex in vertices.size():
   var point:=Vector3.ZERO
   for slot in slots:
    var at:=vertex*slots+slot
    if weights[at]>0:point+=(transforms[bones[at]]*vertices[vertex])*weights[at]
   minima.x=minf(minima.x,point.y)
   if absf(point.x-actor.position.x)<.16 and point.z-actor.position.z>.15 and point.z-actor.position.z<.38:minima.w=minf(minima.w,point.y)
   for side in 2:
    if owners[surface][vertex]==side+1:minima[side+1]=minf(minima[side+1],point.y)
 return minima
func angular_step(a:Quaternion,b:Quaternion) -> Vector3:
 var q:=a.inverse()*b
 if q.w<0:q=-q
 return q.get_axis()*q.get_angle()
func check_shoulder_phase(actor:Node3D) -> void:
 label="fresh shoulder circles"
 var first:Array[Transform3D]=[];var previous:Array[Transform3D]=[]
 var excursion:=Vector2.ZERO
 var bilateral_offset:=0.0
 for frame in 34:
  var pose:Array[Transform3D]=actor.extreme_sampler.sample("extreme",frame/60.0).poses
  if first.is_empty():first=pose.duplicate()
  var globals:Array[Transform3D]=[]
  for bone in pose.size():
   var parent:int=actor.native.parents[bone]
   globals.append(globals[parent]*pose[bone] if parent>=0 else pose[bone])
  for side in 2:
   var ids:Array[int]=actor.native.arms[side].ids
   var upper:Vector3=globals[ids[2]].origin-globals[ids[1]].origin
   var lower:Vector3=globals[ids[3]].origin-globals[ids[2]].origin
   var flex:float=rad_to_deg(upper.angle_to(lower))
   check(flex>=15 and flex<=25,"passive elbows stay between 15 and 25 degrees")
   var wrist:Quaternion=pose[ids[3]].basis.orthonormalized().get_rotation_quaternion()
   var rest_wrist:Quaternion=first[ids[3]].basis.orthonormalized().get_rotation_quaternion()
   check(1-absf(wrist.dot(rest_wrist))<.000001,"wrist has no independent rotation")
   for index in [1,2]:
    var q:Quaternion=pose[ids[index]].basis.orthonormalized().get_rotation_quaternion()
    var initial:Quaternion=first[ids[index]].basis.orthonormalized().get_rotation_quaternion()
    var distance:float=rad_to_deg(angular_step(initial,q).length())
    if index==1:excursion[side]=maxf(excursion[side],distance)
    else:check(distance<3,"elbow variation cannot drive the circle")
    if not previous.is_empty():
     var before:Quaternion=previous[ids[index]].basis.orthonormalized().get_rotation_quaternion()
     check(rad_to_deg(angular_step(before,q).length())*60<(260 if index==1 else 25),"moderate shoulder and passive elbow speeds")
  var right:Array[int]=actor.native.arms[0].ids;var left:Array[int]=actor.native.arms[1].ids
  var lateral:Vector3=(globals[left[1]].origin-globals[right[1]].origin).normalized()
  var r:Vector3=(globals[right[2]].origin-globals[right[1]].origin).normalized()
  var l:Vector3=(globals[left[2]].origin-globals[left[1]].origin).normalized()
  var offset:float=rad_to_deg((r-2*lateral*r.dot(lateral)).angle_to(l))
  bilateral_offset=maxf(bilateral_offset,offset)
  check(offset<12,"bilateral circles have only a small phase offset")
  previous=pose
 check(bilateral_offset>3,"bilateral circles retain a visible slight offset")
 for side in 2:check(excursion[side]>20,"shoulder generates a circular excursion")
 for seam in [33,45]: # Source frames 34 and 46; exact baked velocity matching.
  for arm in actor.native.arms:
   for bone in arm.ids:
    var q:Array[Quaternion]=[]
    for frame in [seam-1,seam,seam+1]:q.append(actor.extreme_sampler.sample("extreme",frame/60.0).poses[bone].basis.orthonormalized().get_rotation_quaternion())
    check(rad_to_deg((angular_step(q[0],q[1])-angular_step(q[1],q[2])).length())*60<.05,"continuous arm angular velocity at entry seam")
func run() -> void:
 Engine.physics_ticks_per_second=240
 var actor=load("res://scenes/prototype_3d/aren_extreme_review_actor.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 for surface in actor.native.mesh.mesh.get_surface_count():
  var arrays:Array=actor.native.mesh.mesh.surface_get_arrays(surface);surfaces.append(arrays)
  var bones:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var count:int=arrays[Mesh.ARRAY_VERTEX].size();var slots:int=bones.size()/count
  var owned:=PackedInt32Array();owned.resize(count)
  for vertex in count:
   var totals:=Vector2.ZERO
   for slot in slots:
    var at:=vertex*slots+slot
    if weights[at]<=0:continue
    var ancestor:int=actor.native.mesh.skin.get_bind_bone(bones[at])
    for side in 2:
     if ancestor==actor.native.arms[side].ids[3]:totals[side]+=weights[at]
   if maxf(totals.x,totals.y)>.9:owned[vertex]=1 if totals.x>totals.y else 2
  owners.append(owned)
 check_shoulder_phase(actor)
 check(is_equal_approx(actor.END-actor.GETUP,8.0),"eight-second survival getup")
 await physics_frame
 var probe:bool="--probe" in OS.get_cmdline_user_args()
 var rate:float=.25 if "--quarter" in OS.get_cmdline_user_args() else 1.0
 for height in ([8.0] if probe else [8.0,12.0,16.0]):
  for outcome in (["survive"] if probe else ["survive","die"]):
   label=str(height)+"/"+outcome;actor.review_height=height;actor.outcome=outcome;actor.begin_preview("idle_to_fall")
   var previous:Array[Transform3D]=[]
   var phases:Dictionary={};var floor_seen:=false
   var getup_feet:Array[Vector3]=[];var leg_onsets:Dictionary={}
   var early_left_palm:=Vector3.ZERO;var early_palm_seen:=false
   for tick in int(800/rate):
    await physics_frame
    var started:=Time.get_ticks_usec();actor.advance_jump_preview(rate/60);timings.append((Time.get_ticks_usec()-started)/1000.0)
    phases[actor.phase_index]=true
    if actor.preview_stage=="getup":
     var contact_time:float=actor.support_time(actor.clip_time)
     var feet:Array[Vector3]=[]
     for leg in actor.native.legs:feet.append(actor.global_transform*actor.native.posed[leg.ids[2]].origin)
     if getup_feet.is_empty():getup_feet=feet.duplicate()
     for side in 2:
      if not leg_onsets.has(side) and feet[side].z-getup_feet[side].z>.01:
       leg_onsets[side]=actor.clip_time
       if side==1:check(feet[0].z-getup_feet[0].z>.01 and feet[0].z-getup_feet[0].z<.70,"left leg begins while right still advances")
     if contact_time>=2.64 and contact_time<2.69:
      var wrist:Vector3=actor.global_transform*actor.native.posed[actor.native.arms[1].ids[3]].origin
      if not early_palm_seen:early_left_palm=wrist;early_palm_seen=true
      check(Vector2(wrist.x,wrist.z).distance_to(Vector2(early_left_palm.x,early_left_palm.z))<.0015,"early left palm stays planted")
      check(scan_skin(actor).z<.025,"left palm supports before bilateral contact")
    for pose in actor.native.posed:check(pose.is_finite(),"finite whole body pose")
    for leg in actor.native.legs:
     for index in 2:
      var length:float=actor.native.posed[leg.ids[index]].origin.distance_to(actor.native.posed[leg.ids[index+1]].origin)*actor.SCALE
      check(absf(length-(leg.a if index==0 else leg.b)*actor.SCALE)<.0002,"native leg lengths")
    for chain in actor.native.legs+actor.native.arms:
     var first:int=0 if chain.ids.size()==3 else 1
     var a:Vector3=actor.native.posed[chain.ids[first]].origin
     var b:Vector3=actor.native.posed[chain.ids[first+1]].origin
     var c:Vector3=actor.native.posed[chain.ids[first+2]].origin
     check(absf(a.distance_to(b)-chain.a)*actor.SCALE<.0002 and absf(b.distance_to(c)-chain.b)*actor.SCALE<.0002,"native limb lengths")
     check(rad_to_deg((b-a).angle_to(c-b))<155,"anatomical elbow/knee flexion")
    if not previous.is_empty():
     for bone in actor.native.parents.size():
      var parent:int=actor.native.parents[bone]
      var before:Transform3D=previous[parent].affine_inverse()*previous[bone] if parent>=0 else previous[bone]
      var after:Transform3D=actor.native.posed[parent].affine_inverse()*actor.native.posed[bone] if parent>=0 else actor.native.posed[bone]
      var angle:float=rad_to_deg(before.basis.orthonormalized().get_rotation_quaternion().angle_to(after.basis.orthonormalized().get_rotation_quaternion()))
      if angle>worst_angle:worst_at=label+" bone "+str(bone)+" time "+str(actor.clip_time)
      worst_angle=maxf(worst_angle,angle)
      check(angle<30,"continuous bone "+str(bone))
    if actor.impact_events>0:
     floor_seen=true;check(actor.position.y<.003,"impact follows real floor collision")
     if tick%20==0:
      var minima:=scan_skin(actor);lowest_skin=minf(lowest_skin,minima.x)
      check(minima.x>=-.002,"full visible skin clears floor")
      if actor.preview_stage=="prone":check(minima.w<.05,"prone torso rests near floor")
      if actor.support_time(actor.clip_time)>=2.75 and actor.support_time(actor.clip_time)<=4.0:
       check(minima.y<.025 and minima.z<.025,"both palms support chest push")
      if actor.support_time(actor.clip_time)>=3.65 and actor.support_time(actor.clip_time)<=4.45:
       for side in 2:
        var sole:=INF
        for point in actor.contact_writer.sole_support.world_skin_points(actor.native,side,actor.global_transform):sole=minf(sole,point.y)
        check(sole<.025,"both soles carry getup")
    check(actor.controls_locked or (outcome=="survive" and actor.preview_done),"actions locked until recovery")
    previous=actor.native.posed.duplicate()
    if actor.preview_done:break
   check(floor_seen and actor.impact_events==1,"one physical impact")
   check(actor.tilt_fraction>=.19 and actor.tilt_fraction<.205,"19 percent actual vertical travel")
   check(absf(actor.fall_time-sqrt(2*height/9.8))<.035,"physical flight timing")
   check(phases.size()==(5 if outcome=="survive" else 4),"all requested phases")
   check(actor.preview_done,"sequence completes")
   if outcome=="die":
    var frozen:Dictionary=actor.capture_pose();actor.advance_jump_preview(2.0)
    check(actor.controls_locked and actor.preview_stage=="prone","death never gets up or unlocks")
    for bone in frozen.poses.size():check(frozen.poses[bone].is_equal_approx(actor.capture_pose().poses[bone]),"dead body remains prone")
   else:
    check(absf(actor.phase_clock-8.0)<=rate/60+.00001,"getup respects eight-second playback clock")
    check(early_palm_seen,"early left support sampled")
    check(leg_onsets.size()==2 and leg_onsets.get(1,0)-leg_onsets.get(0,0)>.26 and leg_onsets.get(1,0)-leg_onsets.get(0,0)<.60,"distinct overlapping right then left leg timing")
    var idle:Dictionary=actor.sampler.sample("idle",0);var final:Dictionary=actor.capture_pose()
    for bone in idle.poses.size():check(final.poses[bone].is_equal_approx(idle.poses[bone]),"exact approved Idle endpoint")
   print(label," tilt ",actor.tilt_fraction," flight ",actor.fall_time," lift ",actor.ground_lift)
 actor.free();await process_frame
 timings.sort()
 print("EXTREME ",checks," checks; pose max step ",worst_angle," deg at ",worst_at,"; skin ",lowest_skin,"; p95 ",timings[int(timings.size()*.95)]," ms; failures ",failures)
 quit(0 if failures.is_empty() else 1)
