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
 await physics_frame
 var probe:bool="--probe" in OS.get_cmdline_user_args()
 for height in ([8.0] if probe else [8.0,12.0,16.0]):
  for outcome in (["survive"] if probe else ["survive","die"]):
   label=str(height)+"/"+outcome;actor.review_height=height;actor.outcome=outcome;actor.begin_preview("idle_to_fall")
   var previous:Array[Transform3D]=[]
   var phases:Dictionary={};var floor_seen:=false
   for tick in 800:
    await physics_frame
    var started:=Time.get_ticks_usec();actor.advance_jump_preview(1.0/60);timings.append((Time.get_ticks_usec()-started)/1000.0)
    phases[actor.phase_index]=true
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
      if actor.clip_time>=2.75 and actor.clip_time<=4.0:
       check(minima.y<.025 and minima.z<.025,"both palms support chest push")
      if actor.clip_time>=3.65 and actor.clip_time<=4.45:
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
    var idle:Dictionary=actor.sampler.sample("idle",0);var final:Dictionary=actor.capture_pose()
    for bone in idle.poses.size():check(final.poses[bone].is_equal_approx(idle.poses[bone]),"exact approved Idle endpoint")
   print(label," tilt ",actor.tilt_fraction," flight ",actor.fall_time," lift ",actor.ground_lift)
 actor.free();await process_frame
 timings.sort()
 print("EXTREME ",checks," checks; pose max step ",worst_angle," deg at ",worst_at,"; skin ",lowest_skin,"; p95 ",timings[int(timings.size()*.95)]," ms; failures ",failures)
 quit(0 if failures.is_empty() else 1)
