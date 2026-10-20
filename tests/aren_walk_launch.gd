extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
var errors:Array[String]=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 if not value and message not in errors:errors.append(message);push_error(message)
func arm(n:RefCounted,side:int) -> Vector2:
 var ids:Array=n.arms[side].ids
 var upper:Vector3=(n.posed[ids[2]].origin-n.posed[ids[1]].origin).normalized();var lower:Vector3=(n.posed[ids[3]].origin-n.posed[ids[2]].origin).normalized()
 var chest:Basis=(n.posed[n.spine[2]].basis*n.inverse_rest[n.spine[2]].basis).orthonormalized()
 var relative:=chest.inverse()*upper
 return Vector2(rad_to_deg(atan2(relative.z,-relative.y)),rad_to_deg(acos(clampf(upper.dot(lower),-1,1))))
func run() -> void:
 var old=load(ROOT+"aren_short_run_v1/aren.tscn").instantiate();root.add_child(old);old.set_process(false)
 var new=load(ROOT+"aren_walk_launch_v1/aren.tscn").instantiate();root.add_child(new);new.set_process(false)
 for path in new.profile.source_hashes:check(FileAccess.get_sha256(path)==new.profile.source_hashes[path],"Stale source: "+path)
 for state in ["normal","cautious","tired"]:
  old.set_style(state);new.set_style(state)
  var before:Array=[[],[],[]];var after:Array=[[],[],[]]
  var n=new.native
  for frame in 120:
   var time:float=frame/120.0*new.sampler.clips.walk.length
   var expected:Dictionary=new.sampler.sample("walk",time)
   for i in 3:new.sampler.sample("walk",(i+.37)*new.sampler.clips.walk.length);new.sampler.sample("run",i*.19)
   var repeated:Dictionary=new.sampler.sample("walk",time)
   check(expected==repeated,"Walking accumulates transformations across samples")
   var source:Dictionary=old.sampler.sample("walk",time)
   check(source.feet==expected.feet and source.shapes==expected.shapes,"Walking contacts or correctives changed")
   for name in ["run","idle"]:check(old.sampler.sample(name,time)==new.sampler.sample(name,time),"Approved running/idle cycle changed")
   old.seek_cycle("walk",time);new.seek_cycle("walk",time)
   for i in 3:
    var bone:int=n.spine[i];var local:Transform3D=n.skeleton.get_bone_pose(bone)
    before[i].append(old.native.skeleton.get_bone_pose(bone).basis.orthonormalized().get_euler().x);after[i].append(local.basis.orthonormalized().get_euler().x)
    check(absf(local.origin.length()-n.binding.locals[bone].origin.length())<.0001,"Spine segment stretches")
    check(local.basis.get_scale().distance_to(old.native.skeleton.get_bone_pose(bone).basis.get_scale())<.00001,"Spine scale changed")
   for side in 2:
    var id:int=n.legs[side].ids[2];check(n.posed[id].origin.distance_to(old.native.posed[id].origin)*new.SCALE<.000001,"Walking foot trajectory changed")
  for i in 3:check((after[i].max()-after[i].min())<(before[i].max()-before[i].min())*.5,"Lumbar/abdominal flexion remains excessive")
  old.reset_motion();new.reset_motion();old.request_transition("idle_to_run");new.request_transition("idle_to_run")
  var onset:Array[float]=[INF,INF];var first_step:=INF;var asymmetric:=0.0;var early_forward:=0.0;var previous:Array[Vector2]=[arm(n,0),arm(n,1)];var max_step:=0.0
  for frame in 720:
   old.advance_transition(1.0/120);new.advance_transition(1.0/120)
   check(absf(old.current_speed-new.current_speed)<.000001 and absf(old.phase-new.phase)<.000001 and absf(old.distance_m-new.distance_m)<.000001,"Movement plan changed")
   if new.phase>.00001 and first_step==INF:first_step=(frame+1)/120.0
   var changes:Array[Vector2]=[]
   for side in 2:
    var pose:=arm(n,side);var delta:=pose-arm(old.native,side);changes.append(delta)
    max_step=maxf(max_step,(pose-previous[side]).length());previous[side]=pose
    if delta.y>.4 and onset[side]==INF:onset[side]=(frame+1)/120.0
    if new.phase==0:early_forward=maxf(early_forward,delta.x)
    check(pose.y<125,"Elbow preparation overflexes")
   if new.phase==0:asymmetric=maxf(asymmetric,absf(changes[0].y-changes[1].y))
  check(onset[1]-onset[0]>=.025 and onset[1]<first_step,"Arm preparation is simultaneous or starts after stepping")
  check(asymmetric>5 and early_forward>2,"Arm preparation lacks asymmetric flexion/advance")
  check(new.arm_amounts[0]+new.arm_amounts[1]<.00001,"Arm preparation persists in steady running")
  check(max_step<8,"Arm preparation produces abrupt angular changes")
  print(state," arm_onsets_s=",onset," first_step_s=",first_step," pre_step_asymmetry_deg=",asymmetric," advance_deg=",early_forward," max_arm_step_deg=",max_step)
  for initial_phase in [.0,.37,.75]:
   new.reset_motion("walk",initial_phase);new.request_transition("walk_to_run")
   for frame in 48:new.advance_transition(1.0/120)
   new.request_transition("run_to_walk")
   for frame in 240:new.advance_transition(1.0/120)
   check(new.arm_amounts[0]+new.arm_amounts[1]<.00001,"Interrupted arm preparation does not settle")
  # Resuming acceleration with the other side leading must keep arm continuity.
  new.reset_motion("walk",.45);new.request_transition("walk_to_run")
  var last:Array[Vector2]=[arm(n,0),arm(n,1)]
  for frame in 240:
   if frame==30:new.request_transition("run_to_walk")
   if frame==42:new.request_transition("walk_to_run")
   new.advance_transition(1.0/120)
   for side in 2:
    var current:=arm(n,side)
    check((current-last[side]).length()<8,"Resuming acceleration jumps an arm pose");last[side]=current
  var start:Dictionary=new.sampler.sample("walk",0);var end:Dictionary=new.sampler.sample("walk",new.sampler.clips.walk.length-.000001)
  for bone in n.parents.size():check(start.poses[bone].origin.distance_to(end.poses[bone].origin)<.001 and start.poses[bone].basis.get_rotation_quaternion().angle_to(end.poses[bone].basis.get_rotation_quaternion())<.002,"Walking loop seam")
 old.free();new.free()
 if errors.is_empty():print("PASS: moderated spine without accumulation, staggered asymmetric arms before stepping, smooth release and preserved approved cycles")
 quit(0 if errors.is_empty() else 1)
