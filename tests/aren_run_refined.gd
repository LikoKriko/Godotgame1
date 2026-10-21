extends "res://tests/aren_transitions.gd"
const ROOT="res://assets/characters/prototype_3d/generated/"
var foot_points:Array=[]
var floor_m:=INF
var probe_frame:=0
var previous_ankles:Array[Quaternion]=[]
var previous_anchors:Array[Vector3]=[]
var ankle_step_deg:=0.0
var sample_dt:=1.0/120
var anchor_error_m:=0.0
func cache_feet(actor:Node3D) -> void:
 var n=actor.native;foot_points.clear()
 var feet:Dictionary={}
 for bone in n.parents.size():
  var parent:int=bone
  while parent>=0:
   if parent in [n.legs[0].ids[2],n.legs[1].ids[2]]:feet[bone]=true;break
   parent=n.parents[parent]
 for surface in n.mesh.mesh.get_surface_count():
  var arrays:Array=n.mesh.mesh.surface_get_arrays(surface)
  var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var ids:PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights:PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  var slots:int=ids.size()/vertices.size()
  var morphs:Array=n.mesh.mesh.surface_get_blend_shape_arrays(surface)
  for vertex in vertices.size():
   var weight:=0.0
   for slot in slots:
    var offset:int=vertex*slots+slot
    if feet.has(n.mesh.skin.get_bind_bone(ids[offset])):weight+=weights[offset]
   if weight<.75:continue
   # Foot vertices are outside the knee/hip corrective regions.
   for morph in morphs:check(vertices[vertex].distance_to(morph[Mesh.ARRAY_VERTEX][vertex])<.00001,"Foot skin needs corrective-aware floor sampling")
   var point:Array=[]
   for slot in slots:
    var offset:int=vertex*slots+slot;var w:float=weights[offset]
    if w<=0:continue
    var bind:int=ids[offset]
    point.append([n.mesh.skin.get_bind_bone(bind),(n.mesh.skin.get_bind_pose(bind)*vertices[vertex])*w,w])
   foot_points.append(point)
 check(foot_points.size()>50,"Missing actual foot skin samples")
func foot_floor(actor:Node3D) -> void:
 for record in foot_points:
  var point:=Vector3.ZERO
  for influence in record:point+=actor.native.posed[influence[0]].basis*influence[1]+actor.native.posed[influence[0]].origin*influence[2]
  floor_m=minf(floor_m,point.y*actor.SCALE)
func snapshot(actor:Node3D) -> Dictionary:
 var value:=super.snapshot(actor)
 var anchors:Array[Vector3]=[]
 for side in 2:
  anchors.append(actor.contacts[side].anchor)
  if actor.contacts[side].planted:anchor_error_m=maxf(anchor_error_m,value.feet[side].distance_to(anchors[side]))
  # At 30 Hz a frame can contain toe-off and a new landing. Sliding is
  # measured within one continuous support, never across different anchors.
  if previous_anchors.size()==2 and anchors[side]!=previous_anchors[side]:value.planted[side]=false
 previous_anchors=anchors
 if probe_frame%12==0:foot_floor(actor)
 probe_frame+=1
 var ankles:Array[Quaternion]=[]
 for side in 2:
  var n=actor.native;var ids:Array=n.legs[side].ids
  var thigh:Vector3=(n.posed[ids[1]].origin-n.posed[ids[0]].origin).normalized()
  var shin:Vector3=(n.posed[ids[2]].origin-n.posed[ids[1]].origin).normalized()
  check(rad_to_deg(atan2(Vector3.RIGHT.dot(thigh.cross(shin)),thigh.dot(shin)))>=-.5,"Inverted knee during transition")
  check(rad_to_deg(acos(clampf(thigh.dot(shin),-1,1)))<155,"Excessive knee flexion during transition")
  ankles.append(n.posed[ids[2]].basis.orthonormalized().get_rotation_quaternion())
  if previous_ankles.size()==2:ankle_step_deg=maxf(ankle_step_deg,rad_to_deg(ankles[side].angle_to(previous_ankles[side]))/(sample_dt*120))
 previous_ankles=ankles
 return value
func advance(actor:Node3D,seconds:float,dt:float=1.0/120) -> void:
 previous_ankles.clear();previous_anchors.clear();sample_dt=dt
 super.advance(actor,seconds,dt)
func cycles(old:Node3D,actor:Node3D,state:String) -> void:
 var before:Animation=old.library.get_animation(&"run");var after:Animation=actor.library.get_animation(&"run")
 var info:Dictionary=after.get_meta("cycle");var source:Dictionary=before.get_meta("cycle")
 check(absf(after.length/before.length-.95)<.000001,"Unexpected cadence")
 check(absf(info.speed_mps/source.speed_mps-.9/.95)<.000001,"Unexpected displacement speed")
 check(absf(info.distance_m/after.length-info.speed_mps)<.000001,"Speed and cycle distance disagree")
 for name in [&"walk",&"idle"]:
  check(actor.library.get_animation(name)==old.library.get_animation(name),"Approved nonrunning clip replaced")
  check(actor.sampler.sample(name,.173)==old.sampler.sample(name,.173),"Approved nonrunning pose changed")
 var gaps:=Vector2.ZERO;var heights:=Vector2.ZERO;var pitches:=Vector2(INF,-INF)
 var slip:=0.0;var previous:Array[Vector3]=[];var planted:Array[bool]=[]
 for frame in 721:
  var phase:float=frame/720.0
  old.seek_cycle("run",phase*before.length);actor.seek_cycle("run",phase*after.length)
  var n=actor.native;var old_n=old.native
  var a:Vector3=n.posed[n.legs[0].ids[2]].origin;var b:Vector3=n.posed[n.legs[1].ids[2]].origin
  var old_a:Vector3=old_n.posed[old_n.legs[0].ids[2]].origin;var old_b:Vector3=old_n.posed[old_n.legs[1].ids[2]].origin
  gaps.x=maxf(gaps.x,absf(old_a.z-old_b.z)*actor.SCALE);gaps.y=maxf(gaps.y,absf(a.z-b.z)*actor.SCALE)
  heights.x=maxf(heights.x,old_a.y*actor.SCALE);heights.y=maxf(heights.y,a.y*actor.SCALE)
  var pitch:float=rad_to_deg((n.posed[n.legs[0].ids[2]].basis*n.inverse_rest[n.legs[0].ids[2]].basis).orthonormalized().get_euler().x)
  pitches.x=minf(pitches.x,pitch);pitches.y=maxf(pitches.y,pitch)
  for side in 2:
   var id:int=n.legs[side].ids[2]
   var support:bool=fposmod(phase+side*.5,1)<info.support
   var world:Vector3=n.posed[id].origin*actor.SCALE+Vector3.BACK*phase*info.distance_m
   if frame>0 and support and planted[side]:slip=maxf(slip,world.distance_to(previous[side])/(after.length/720))
   if frame==0:previous.append(world);planted.append(support)
   else:previous[side]=world;planted[side]=support
   var q:Quaternion=n.posed[id].basis.orthonormalized().get_rotation_quaternion()
   var original:Quaternion=old_n.posed[id].basis.orthonormalized().get_rotation_quaternion()
   if support or side==1:check(q.angle_to(original)<.002,"Support or left foot orientation changed")
  for bone in n.spine:check(n.posed[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(old_n.posed[bone].basis.orthonormalized().get_rotation_quaternion())<.002,"Approved running torso changed")
  for bone in n.parents.size():
   var local:Transform3D=n.skeleton.get_bone_pose(bone)
   if n.parents[bone]>=0:check(absf(local.origin.length()-n.binding.locals[bone].origin.length())<.0001,"Bone length changed")
   check(local.basis.get_scale().distance_to(old_n.skeleton.get_bone_pose(bone).basis.get_scale())<.0001,"Bone scale changed")
  if frame%8==0:foot_floor(actor)
 check(absf(gaps.y/gaps.x-.9)<.002,"Actual leg separation not reduced ten percent")
 check(heights.y<heights.x-.015,"Right-foot recovery is still excessively high")
 check(pitches.x< -1 and pitches.x>=-8 and pitches.y>8 and pitches.y<=20,"Right ankle lacks natural phase-dependent articulation")
 check(slip<.025,"Steady support slips")
 var start:Dictionary=actor.sampler.sample("run",0);var end:Dictionary=actor.sampler.sample("run",after.length-.000001)
 for bone in actor.native.parents.size():check(start.poses[bone].origin.distance_to(end.poses[bone].origin)<.001 and start.poses[bone].basis.get_rotation_quaternion().angle_to(end.poses[bone].basis.get_rotation_quaternion())<.002,"Run loop seam")
 var sample:Dictionary=actor.sampler.sample("run",after.length*.417)
 actor.sampler.sample("walk",.2);actor.sampler.sample("run",after.length*.8)
 check(sample==actor.sampler.sample("run",after.length*.417),"Foot correction accumulates across samples")
 print(state," split_ratio=",gaps.y/gaps.x," gap_m=",gaps.y," right_ankle_height_m=",heights," ankle_pitch_deg=",pitches," slip_mps=",slip)
func run() -> void:
 var old=load(ROOT+"aren_walk_launch_v1/aren.tscn").instantiate();root.add_child(old);old.set_process(false)
 var actor=load(ROOT+"aren_run_refined_v1/aren.tscn").instantiate();root.add_child(actor);actor.set_process(false)
 for path in actor.profile.source_hashes:check(preload("res://tests/aren_branch_cache.gd").source_matches(path,actor.profile.source_hashes[path]),"Changed source: "+path)
 cache_feet(actor)
 for state in ["normal","cautious","tired"]:
  actor.set_style(state);old.set_style(state);cycles(old,actor,state)
  for fps in [30,60,120]:
   var dt:float=1.0/fps
   for name in actor.profile.recipes:
    actor.reset_motion(actor.profile.recipes[name].from);actor.request_transition(name)
    advance(actor,actor.transition_duration+.3,dt)
    check(actor.recipe.is_empty() and is_equal_approx(actor.current_speed,actor.speed_for(actor.profile.recipes[name].to)),"Wrong transition endpoint")
   actor.reset_motion()
   for name in ["idle_to_walk","walk_to_run","run_to_walk","walk_to_idle","idle_to_run","run_to_idle"]:
    actor.request_transition(name);advance(actor,actor.transition_duration+.2,dt)
   for item in [["idle_to_run",.55],["run_to_walk",.18],["walk_to_idle",.22],["idle_to_run",.35],["run_to_idle",.24],["idle_to_walk",.32],["walk_to_run",3.0]]:
    actor.request_transition(item[0]);advance(actor,item[1],dt)
   print("PASS refined transitions: ",state," fps=",fps)
  for phase in [.37,.75]:
   for name in ["idle_to_run","walk_to_run","run_to_walk","run_to_idle"]:
    actor.reset_motion(actor.profile.recipes[name].from,phase);actor.request_transition(name);advance(actor,actor.transition_duration+.2)
 check(stats.slip_mps<.025,"Transition support slips")
 check(anchor_error_m<.001,"Planted foot leaves its world anchor")
 check(stats.max_ik_error_m<.001,"Unreachable foot target")
 check(stats.pelvis_step_m<.012 and stats.torso_step_deg<3,"Abrupt pelvis or torso change")
 check(stats.foot_step_m<.15 and ankle_step_deg<6,"Foot discontinuity")
 check(floor_m>=-.004,"Actual foot skin penetrates the floor")
 print("skin_floor_m=",floor_m," anchor_error_m=",anchor_error_m," ankle_step_deg_per_120hz=",ankle_step_deg," stats=",JSON.stringify(stats))
 old.free();actor.free()
 if errors.is_empty():print("PASS: ten-percent shorter split, articulated lower right recovery, preserved left/torso/walk/idle, natural transitions")
 quit(0 if errors.is_empty() else 1)
