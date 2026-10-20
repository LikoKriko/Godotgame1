extends "res://scripts/animation/authoring/aren_run_launch_actor.gd"
const CoordinatedSampler=preload("res://scripts/animation/authoring/aren_coordination_sampler.gd")
func set_style(value:String) -> void:
 super.set_style(value)
 sampler=CoordinatedSampler.new();sampler.native=native
 sampler.steady_angle=deg_to_rad(float(profile.posture[style].steady_deg))
 sampler.arm_phase=profile.walk_arm_phase
 sampler.configure(library,native.skeleton);reset_motion()

const Posture=preload("res://scripts/animation/authoring/aren_run_posture.gd")
const KneePlane=preload("res://scripts/animation/authoring/aren_knee_plane.gd")
var impulse_extra:=0.0
var impulse_extra_velocity:=0.0
var correction_tick:=0.0
var knee_corrections:=0
var knee_planes:Array[Dictionary]=[]
func reset_motion(gait:String="idle",at_phase:float=0.0) -> void:
 impulse_extra=0;impulse_extra_velocity=0;correction_tick=0;knee_corrections=0
 knee_planes=[{"direction":Vector3.ZERO,"active":false},{"direction":Vector3.ZERO,"active":false}]
 super.reset_motion(gait,at_phase)
func tick(dt:float) -> void:
 correction_tick=dt;super.tick(dt);correction_tick=0
func render_pose(prepare:float) -> void:
 super.render_pose(prepare)
 if correction_tick>0:
  var previous:=impulse_extra
  if launch_session:
   # Reach an exact plateau before recovery; do not lose 1.5° in a low-pass filter.
   var charge:float=clampf(launch_charge/.9,0,1)
   impulse_extra=deg_to_rad(profile.launch_increment_deg)*smooth5(charge)*(1-smooth5(recovery_progress))
   impulse_extra_velocity=(impulse_extra-previous)/correction_tick
  else:
   var release:=spring(impulse_extra,impulse_extra_velocity,0,correction_tick,18)
   impulse_extra=release.x;impulse_extra_velocity=release.y
 if absf(impulse_extra)>.00000001:
  var locals:Array[Transform3D]=[]
  for bone in native.parents.size():locals.append(native.skeleton.get_bone_pose(bone))
  Posture.apply(native,{"poses":locals},impulse_extra)
  for bone in native.parents.size():native.local_globals[bone]=native.inverse_frame*native.posed[bone]
  native.writer.apply(native.skeleton,native.local_globals)
func impulse_increment() -> float:return impulse_extra
func solve_contacts() -> void:
 if not sampler is CoordinatedSampler:super.solve_contacts();return
 var mix:=gait_blend()
 var a:String="idle" if mix<1 else "walk";var b:String="walk" if mix<1 else "run"
 var weight:float=mix if mix<1 else mix-1
 var poles:Array[Vector3]=[]
 for side in 2:poles.append(sampler.knee_poles[a][side].lerp(sampler.knee_poles[b][side],weight).normalized())
 super.solve_contacts()
 for side in 2:
  if KneePlane.stabilize(native,side,poles[side],knee_planes[side],correction_tick):knee_corrections+=1
