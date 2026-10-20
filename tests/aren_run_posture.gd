extends SceneTree
const ROOT="res://assets/characters/prototype_3d/generated/"
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(value:bool,message:String) -> void:
 if not value and message not in failures:failures.append(message);push_error(message)
func global_poses(actor:Node3D,sampled:Dictionary) -> Array[Transform3D]:
 var globals:Array[Transform3D]=[];var posed:Array[Transform3D]=[]
 for i in actor.native.parents.size():
  var parent:int=actor.native.parents[i]
  globals.append(globals[parent]*sampled.poses[i] if parent>=0 else sampled.poses[i])
  posed.append(actor.native.frame*globals[i])
 return posed
func run() -> void:
 var before:Node3D=load(ROOT+"aren_transitions_v1/aren.tscn").instantiate();root.add_child(before);before.set_process(false)
 var after:Node3D=load(ROOT+"aren_run_launch_v1/aren.tscn").instantiate();root.add_child(after);after.set_process(false)
 for path in after.profile.source_hashes:check(FileAccess.get_sha256(path)==after.profile.source_hashes[path],"Stale source: "+path)
 var max_foot:=0.0;var max_arm:=0.0;var max_knee:=0.0
 for state in ["normal","cautious","tired"]:
  before.set_style(state);after.set_style(state)
  check(before.library==after.library,"Approved library duplicated or replaced")
  var clip:Animation=after.library.get_animation(&"run")
  var angle:float=deg_to_rad(after.profile.posture[state].steady_deg)
  var loop_first:Array=[]
  for frame in 121:
   var t:float=frame/120.0*clip.length
   var original:Dictionary=before.sampler.sample("run",t)
   var old:=global_poses(before,original)
   after.seek_cycle("run",t)
   var posed:Array=after.native.posed
   if frame==0:loop_first=posed.duplicate()
   if frame==120:
    for bone in posed.size():
     check(posed[bone].origin.distance_to(loop_first[bone].origin)<.0001,"Steady run loop position seam")
     check(posed[bone].basis.orthonormalized().get_rotation_quaternion().angle_to(loop_first[bone].basis.orthonormalized().get_rotation_quaternion())<.002,"Steady run loop angular seam")
   var chest:int=after.native.spine[2];var hip:int=after.native.binding.bone(&"root")
   var chest_delta:float=(posed[chest].basis*old[chest].basis.inverse()).orthonormalized().get_euler().x
   var hip_delta:float=(posed[hip].basis*old[hip].basis.inverse()).orthonormalized().get_euler().x
   check(absf(chest_delta-angle)<.0001,"Wrong steady chest inclination")
   check(absf(hip_delta-angle*.35)<.0001,"Pelvis not coordinated with torso")
   for side in 2:
    var leg:Dictionary=after.native.legs[side];var id:int=leg.ids[2]
    max_foot=maxf(max_foot,posed[id].origin.distance_to(old[id].origin)*after.SCALE)
    check(posed[id].basis.orthonormalized().get_rotation_quaternion().angle_to(old[id].basis.orthonormalized().get_rotation_quaternion())<.002,"Foot orientation changed")
    max_knee=maxf(max_knee,posed[leg.ids[1]].origin.distance_to(old[leg.ids[1]].origin)*after.SCALE)
    for bone in after.native.arms[side].ids:
     var a:Transform3D=posed[chest].affine_inverse()*posed[bone]
     var b:Transform3D=old[chest].affine_inverse()*old[bone]
     max_arm=maxf(max_arm,a.origin.distance_to(b.origin)*after.SCALE)
     check(a.basis.orthonormalized().get_rotation_quaternion().angle_to(b.basis.orthonormalized().get_rotation_quaternion())<.002,"Arm gesture changed relative to torso")
   for name in ["walk","idle"]:
    var untouched:Dictionary=after.sampler.sample(name,t)
    var reference:Dictionary=before.sampler.sample(name,t)
    check(untouched==reference,"Unrelated cycle changed")
  print("PASS steady posture state=",state," extra_chest_deg=",rad_to_deg(angle))
 check(max_foot<.001,"Approved foot trajectory changed")
 check(max_arm<.00001,"Arm swing changed relative to torso")
 check(max_knee<.005,"Excessive change in approved leg movement")
 print("steady max_foot_error_m=",max_foot," max_relative_arm_error_m=",max_arm," knee_adjustment_m=",max_knee)
 check_launch(before,after)
 before.free();after.free();quit(0 if failures.is_empty() else 1)

func check_launch(before:Node3D,after:Node3D) -> void:
 var max_slip:=0.0;var max_turn:=0.0;var max_hip_step:=0.0
 for state in ["normal","cautious","tired"]:
  before.set_style(state);after.set_style(state)
  before.request_transition("idle_to_run");after.request_transition("idle_to_run")
  var previous_feet:Array[Vector3]=[];var previous_planted:Array[bool]=[]
  var hip:int=after.native.binding.bone(&"root");var chest:int=after.native.spine[2]
  var previous_hip:Vector3=after.native.posed[hip].origin*after.SCALE
  var previous_torso:Quaternion=after.native.posed[chest].basis.orthonormalized().get_rotation_quaternion()
  var recovered:=-1.0;var at_three:=INF;var actual_peak:=0.0
  for frame in 660:
   before.advance_transition(1.0/120);after.advance_transition(1.0/120)
   check(absf(before.current_speed-after.current_speed)<.000001,"Launch displacement speed changed")
   check(absf(before.distance_m-after.distance_m)<.000001 and absf(before.phase-after.phase)<.000001,"Launch phase/displacement differs from approved plan")
   for side in 2:
    var foot:int=after.native.legs[side].ids[2]
    var current:Vector3=after.native.posed[foot].origin*after.SCALE+Vector3.BACK*after.distance_m
    if previous_feet.size()<2:previous_feet.append(current);previous_planted.append(after.contacts[side].planted)
    if previous_planted[side] and after.contacts[side].planted:max_slip=maxf(max_slip,current.distance_to(previous_feet[side])*120)
    previous_feet[side]=current;previous_planted[side]=after.contacts[side].planted
   var position:Vector3=after.native.posed[hip].origin*after.SCALE
   var rotation:Quaternion=after.native.posed[chest].basis.orthonormalized().get_rotation_quaternion()
   var actual_pitch:float=(after.native.posed[chest].basis*after.native.inverse_rest[chest].basis).orthonormalized().get_euler().x
   actual_peak=maxf(actual_peak,rad_to_deg(actual_pitch-after.steady_chest_pitch))
   max_turn=maxf(max_turn,rad_to_deg(previous_torso.angle_to(rotation)))
   max_hip_step=maxf(max_hip_step,position.distance_to(previous_hip));previous_torso=rotation;previous_hip=position
   if after.recovery_steps_done>=2 and absf(after.lean)<deg_to_rad(.25) and recovered<0:recovered=after.recovery_steps_done
   if after.recovery_steps_done>=3 and at_three==INF:at_three=rad_to_deg(absf(after.lean))
  if at_three==INF and not after.launch_session and recovered>=2 and recovered<3:at_three=rad_to_deg(absf(after.lean))
  var peak:float=after.profile.posture[state].launch_deg
  check(actual_peak>peak*.9 and actual_peak<peak*1.05,"First impulse is not above the new steady running posture")
  check(rad_to_deg(after.launch_peak)>peak*.9 and rad_to_deg(after.launch_peak)<=peak+.05,"Wrong first-impulse intensity")
  check(recovered>=2 and recovered<=3.05,"Launch does not settle during the following 2–3 steps")
  check(at_three<.25,"Excessive residual lean after three steps")
  check(absf(after.lean)<deg_to_rad(.01),"Launch does not converge to new steady posture")
  print("PASS launch ",state," actual_extra_deg=",actual_peak," steady_pitch_deg=",rad_to_deg(after.steady_chest_pitch)," settled_steps=",recovered," residual_at_3_deg=",at_three)
 # Elapsed time alone must not recover a stationary support/velocity snapshot.
 after.set_style("normal");after.request_transition("idle_to_run")
 for i in 90:after.advance_transition(1.0/120)
 var retained:float=after.recovery_progress
 after.transition_time+=20;after.tick_dt=1.0/120;after.render_pose(0)
 check(is_equal_approx(retained,after.recovery_progress),"Recovery follows elapsed time without support or speed change")
 after.current_speed=lerpf(after.recovery_speed,after.speed_for("run"),.95);after.render_pose(0)
 check(after.recovery_progress>retained,"Recovery does not respond to actual gained speed")
 after.tick_dt=0
 check(max_slip<.025,"Planted feet slide")
 check(max_turn<3 and max_hip_step<.012,"Abrupt pelvis/spine motion")
 print("launch max_slip_mps=",max_slip," torso_step_deg=",max_turn," pelvis_step_m=",max_hip_step)
