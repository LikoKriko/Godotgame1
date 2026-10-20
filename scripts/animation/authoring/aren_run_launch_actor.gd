extends "res://scripts/animation/authoring/aren_transition_actor.gd"
## Versioned posture variant. Baseline transition/cycle resources stay untouched.
const PostureSampler=preload("res://scripts/animation/authoring/aren_posture_sampler.gd")
var launch_session:=false
var launch_charge:=0.0
var recovery_phase:=-1.0
var recovery_speed:=0.0
var recovery_steps_done:=0.0
var recovery_progress:=0.0
var launch_goal:=0.0
var launch_peak:=0.0
var steady_chest_pitch:=0.0
var launch_pitch:=0.0
var launch_pitch_velocity:=0.0
var source_pitch_previous:=0.0
var chest_chain:Array[int]=[]
var tick_dt:=0.0
func reset_motion(gait:String="idle",at_phase:float=0.0) -> void:
 launch_session=false;launch_charge=0;recovery_phase=-1;recovery_speed=0;recovery_steps_done=0;recovery_progress=0;launch_goal=0;launch_peak=0;tick_dt=0;launch_pitch=0;launch_pitch_velocity=0;source_pitch_previous=0
 super.reset_motion(gait,at_phase)
func request_transition(name:String) -> void:
 launch_session=name=="idle_to_run" and current_speed<speed_for("walk")*.05
 if launch_session:
  launch_charge=0;recovery_phase=-1;recovery_speed=0;recovery_steps_done=0;recovery_progress=0;launch_goal=0;launch_peak=0
  var chest:int=native.spine[2]
  launch_pitch=(native.posed[chest].basis*native.inverse_rest[chest].basis).orthonormalized().get_euler().x
  launch_pitch_velocity=lean_velocity;source_pitch_previous=launch_pitch-lean
 super.request_transition(name)
func tick(dt:float) -> void:
 tick_dt=dt
 super.tick(dt)
 tick_dt=0
func render_pose(prepare:float) -> void:
 if launch_session and tick_dt>0:
  launch_charge=maxf(launch_charge,prepare)
  if recovery_phase<0 and gait_blend()>.1:
   for side in 2:
    # The first real landing after the preparatory push begins recovery.
    if not contacts[side].planted and fposmod(phase+side*.5,1)<support_fraction():
     recovery_phase=phase;recovery_speed=current_speed;break
  if recovery_phase>=0:
   recovery_steps_done=maxf(0,(phase-recovery_phase)*2)
   var steps:float=clampf(recovery_steps_done/profile.posture[style].recovery_steps,0,1)
   var velocity:float=clampf((current_speed-recovery_speed)/maxf(speed_for("run")-recovery_speed,.001),0,1)
   # Neither elapsed transition time nor a standalone fade drives recovery.
   # Both support progression and the actual gained velocity can settle it.
   recovery_progress=maxf(recovery_progress,maxf(steps,velocity))
  var source_pitch:=blended_chest_pitch()
  var envelope:float=launch_charge*(1-smooth5(recovery_progress))
  # Filter the absolute chest target: an idle/run crossfade must not dilute
  # the push below the new steady running posture or create feed-forward overshoot.
  var target:float=source_pitch+(steady_chest_pitch+deg_to_rad(profile.posture[style].launch_deg)-source_pitch)*envelope
  var filtered:=spring(launch_pitch,launch_pitch_velocity,target,tick_dt,12+12*recovery_progress)
  launch_pitch=filtered.x;launch_pitch_velocity=filtered.y
  lean=launch_pitch-source_pitch
  lean_velocity=launch_pitch_velocity-(source_pitch-source_pitch_previous)/tick_dt
  source_pitch_previous=source_pitch;launch_goal=target-source_pitch
  launch_peak=maxf(launch_peak,launch_pitch-steady_chest_pitch)
  if recipe.is_empty() and recovery_progress>=.999 and absf(lean)<deg_to_rad(.05):launch_session=false
 super.render_pose(prepare)
func set_style(value:String) -> void:
 super.set_style(value)
 sampler=PostureSampler.new();sampler.native=native
 sampler.steady_angle=deg_to_rad(float(profile.posture[style].steady_deg))
 sampler.configure(library,native.skeleton)
 chest_chain.clear();var bone:int=native.spine[2]
 while bone>=0:chest_chain.push_front(bone);bone=native.parents[bone]
 steady_chest_pitch=0
 for frame in 24:
  var sample:Dictionary=sampler.sample("run",frame/24.0*sampler.clips.run.length)
  steady_chest_pitch+=chest_pitch(sample.poses)
 steady_chest_pitch/=24
 reset_motion()
func seek_cycle(clip:String,seconds:float) -> void:
 tree.active=false;player.stop()
 var sampled:Dictionary=sampler.sample(clip,seconds)
 for i in native.parents.size():
  var parent:int=native.parents[i]
  native.local_globals[i]=native.local_globals[parent]*sampled.poses[i] if parent>=0 else sampled.poses[i]
  native.posed[i]=native.frame*native.local_globals[i]
 for shape in sampled.shapes:native.mesh.set_blend_shape_value(native.mesh.find_blend_shape_by_name(shape),sampled.shapes[shape])
 native.writer.apply(native.skeleton,native.local_globals)

func chest_pitch(locals:Array) -> float:
 var global_pose:Transform3D=native.frame
 for bone in chest_chain:global_pose=global_pose*locals[bone]
 return (global_pose.basis*native.inverse_rest[native.spine[2]].basis).orthonormalized().get_euler().x
func blended_chest_pitch() -> float:
 var mix:=gait_blend()
 var a:String="idle" if mix<1 else "walk";var b:String="walk" if mix<1 else "run"
 var weight:float=mix if mix<1 else mix-1
 var first:Dictionary=sampler.sample(a,clock if a=="idle" else phase*sampler.clips[a].length)
 var second:Dictionary=sampler.sample(b,phase*sampler.clips[b].length)
 var global_pose:Transform3D=native.frame
 for bone in chest_chain:global_pose=global_pose*first.poses[bone].interpolate_with(second.poses[bone],weight)
 return (global_pose.basis*native.inverse_rest[native.spine[2]].basis).orthonormalized().get_euler().x
