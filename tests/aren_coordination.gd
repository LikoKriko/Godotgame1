extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
var errors:Array[String]=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 if not value and message not in errors:errors.append(message);push_error(message)
func bend(n:RefCounted,side:int,signed_angle:bool) -> float:
 var ids:Array=n.legs[side].ids
 var a:Vector3=(n.posed[ids[1]].origin-n.posed[ids[0]].origin).normalized()
 var b:Vector3=(n.posed[ids[2]].origin-n.posed[ids[1]].origin).normalized()
 return rad_to_deg(atan2(Vector3.RIGHT.dot(a.cross(b)),a.dot(b))) if signed_angle else rad_to_deg(acos(clampf(a.dot(b),-1,1)))
func correlation(values:Array[Vector2]) -> float:
 var centre:=Vector2.ZERO
 for value in values:centre+=value
 centre/=values.size()
 var covariance:=0.0;var aa:=0.0;var bb:=0.0
 for value in values:
  var delta:Vector2=value-centre;covariance+=delta.x*delta.y;aa+=delta.x*delta.x;bb+=delta.y*delta.y
 return covariance/sqrt(aa*bb)
func run() -> void:
 var old:Node3D=load(ROOT+"aren_run_launch_v1/aren.tscn").instantiate();root.add_child(old);old.set_process(false)
 var new:Node3D=load(ROOT+"aren_coordination_v1/aren.tscn").instantiate();root.add_child(new);new.set_process(false)
 for path in new.profile.source_hashes:check(FileAccess.get_sha256(path)==new.profile.source_hashes[path],"Stale source: "+path)
 var max_flexion_delta:=0.0;var minimum:=INF;var maximum:=0.0
 for state in ["normal","cautious","tired"]:
  old.set_style(state);new.set_style(state)
  check(old.library==new.library,"Approved cycle library changed")
  var samples:Array=[[],[]]
  var duration:float=new.library.get_animation(&"walk").length
  for frame in 120:
   var t:float=frame/120.0*duration
   var original:Dictionary=old.sampler.sample("walk",t)
   var shifted:Dictionary=old.sampler.sample("walk",t+duration*.5)
   var corrected:Dictionary=new.sampler.sample("walk",t)
   for bone in new.native.parents.size():
    check(corrected.poses[bone]==(shifted.poses[bone] if bone in new.sampler.arm_bones else original.poses[bone]),"Walking correction changed an unrelated pose or arm amplitude")
   check(corrected.feet==original.feet and corrected.shapes==original.shapes,"Walking contacts/correctives changed")
   new.seek_cycle("walk",t)
   var n=new.native;var chest:Transform3D=n.posed[n.spine[2]]
   var body:Basis=(chest.basis*n.inverse_rest[n.spine[2]].basis).orthonormalized()
   for side in 2:
    var hand:Vector3=body.inverse()*(n.posed[n.arms[side].ids[3]].origin-chest.origin)
    var foot:Vector3=n.posed[n.legs[side].ids[2]].origin-n.posed[n.legs[side].ids[0]].origin
    samples[side].append(Vector2(foot.z,hand.z))
   for name in ["idle","run"]:check(old.sampler.sample(name,t)==new.sampler.sample(name,t),"Idle or steady running posture changed")
  var correlations:Array=[]
  for side in 2:
   var values:Array[Vector2]=[];values.assign(samples[side]);var corr:=correlation(values)
   check(corr<-.7,"Walking arms are not contralateral");correlations.append(corr)
  print("PASS walk ",state," same-side correlation=",correlations)
  old.reset_motion();new.reset_motion();old.request_transition("idle_to_run");new.request_transition("idle_to_run")
  var plateau:=0;var maximum_extra:=0.0;var at_three:=INF
  for frame in 660:
   old.advance_transition(1.0/120);new.advance_transition(1.0/120)
   check(absf(old.current_speed-new.current_speed)<.000001 and absf(old.phase-new.phase)<.000001,"Movement speed or gait clock changed")
   var chest:int=new.native.spine[2]
   var delta:float=rad_to_deg((new.native.posed[chest].basis*old.native.posed[chest].basis.inverse()).orthonormalized().get_euler().x)
   maximum_extra=maxf(maximum_extra,delta)
   if new.launch_charge>=.9 and new.recovery_progress==0:
    plateau+=1;check(absf(delta-1.5)<.001,"Initial torso increment is not exactly 1.5 degrees")
   for side in 2:
    minimum=minf(minimum,bend(new.native,side,true));maximum=maxf(maximum,bend(new.native,side,false))
    max_flexion_delta=maxf(max_flexion_delta,absf(bend(new.native,side,false)-bend(old.native,side,false)))
    var foot:int=new.native.legs[side].ids[2]
    check(new.native.posed[foot].origin.distance_to(old.native.posed[foot].origin)*new.SCALE<.001,"Anatomical correction displaced a foot")
   if new.recovery_steps_done>=3 and at_three==INF:at_three=rad_to_deg(absf(new.lean)+absf(new.impulse_extra))
  check(plateau>0 and absf(maximum_extra-1.5)<.001,"Exact initial impulse plateau missing")
  check(at_three<.25,"Initial impulse does not settle after three steps")
  check(absf(new.impulse_extra)<.000001,"Steady running retains the extra impulse")
  print("PASS launch ",state," exact_extra_deg=",maximum_extra," residual_at_3_deg=",at_three," knee_plane_corrections=",new.knee_corrections)
  # Every shared transition, including interruptions, must keep anatomical knees.
  new.reset_motion()
  for name in ["idle_to_walk","walk_to_run","run_to_walk","walk_to_idle","idle_to_run","run_to_idle"]:
   new.request_transition(name)
   for frame in ceili((new.transition_duration+.2)*120):
    new.advance_transition(1.0/120)
    for side in 2:check(bend(new.native,side,true)>=-.5 and bend(new.native,side,false)<155,"Invalid knee in chained "+state+"/"+name)
  new.reset_motion();new.request_transition("idle_to_run")
  for change in [[.55,"run_to_walk"],[.18,"walk_to_idle"],[1.8,""]]:
   for frame in ceili(change[0]*120):
    new.advance_transition(1.0/120)
    for side in 2:check(bend(new.native,side,true)>=-.5 and bend(new.native,side,false)<155,"Invalid knee during interruption: "+state)
   if not change[1].is_empty():new.request_transition(change[1])
 check(minimum>=-.5 and maximum<155,"Anatomically inverted or excessive knee flexion")
 check(max_flexion_delta<.01,"A valid flexion angle was modified")
 print("signed_knee_min_deg=",minimum," flexion_max_deg=",maximum," max_magnitude_change_deg=",max_flexion_delta)
 old.free();new.free();quit(0 if errors.is_empty() else 1)
